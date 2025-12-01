/*
  Subworkflow group to create assay/decoy and run OpenSwath extraction.

  Provides two workflows:
    - ASSAY_DECOY_FROM_TRANSITION: takes a transition TSV and runs OpenSwathAssayGenerator -> decoy -> OpenSwathWorkflow
    - ASSAY_DECOY_FROM_PQP: takes an existing PQP/library file, runs decoy -> OpenSwathWorkflow

  Emits:
    - per_run_osw: OSW files from OPENSWATHWORKFLOW
    - chrom_mzml: sqMass chromatogram files
    - irt_trafo: iRT transformation files
    - irt_chrom: iRT chromatogram files
    - debug_mz: Debug m/z files
    - debug_im: Debug ion mobility files
    - decoyed_library: the decoyed PQP/library file
    - library: the pqp produced from transition (when applicable)
*/

include { OPENSWATHASSAYGENERATOR } from '../../../modules/local/openms/openswathassaygenerator/core/main.nf'
include { OPENSWATHASSAYGENERATOR_NAMED } from '../../../modules/local/openms/openswathassaygenerator/named/main.nf'
include { OPENSWATHDECOYGENERATOR } from '../../../modules/local/openms/openswathdecoygenerator/main.nf'
include { OPENSWATHWORKFLOW } from '../../../modules/local/openms/openswathworkflow/main.nf'
include { EASYPQP_REDUCE } from '../../../modules/local/easypqp/reduce/main.nf'

/**
 * Helper function to normalize a run name by stripping pseudo-spectra suffixes.
 * This allows matching run-specific iRTs from pseudo-spectra (e.g., from DIA-Umpire or diaTracer)
 * to the original DIA files.
 * 
 * @param name The filename or run ID to normalize
 * @return The normalized name with pseudo-spectra suffixes stripped
 */
def normalizeRunName(name) {
    def normalized = name.toString()
    
    // If user specified a custom suffix pattern, use it
    if (params.irt_pseudospectra_suffix) {
        normalized = normalized.replaceAll(/${params.irt_pseudospectra_suffix}$/, '')
    }
    
    // Always strip common pseudo-spectra suffixes as a fallback
    // DIA-Umpire: _Q1, _Q2, _Q3 (quality tiers)
    normalized = normalized.replaceAll(/_Q[123]$/, '')
    
    // diaTracer: _diatracer (case insensitive)
    normalized = normalized.replaceAll(/(?i)_diatracer$/, '')
    
    // Additional common patterns can be added here
    // normalized = normalized.replaceAll(/_pseudospectra$/, '')
    
    return normalized
}

workflow ASSAY_DECOY_FROM_TRANSITION {

  take:
    DIA_MZML           // Channel of DIA files: either path or tuple(run_id, path)
    transition_tsv     // Transition TSV from EasyPQP
    irt_traml_ch       // Optional iRT TraML (Channel.value or empty)
    irt_nonlinear_traml_ch  // Optional nonlinear iRT TraML
    run_peaks_ch       // Channel of *_run_peaks.tsv files from EasyPQP convert
    swath_windows_ch   // Optional SWATH windows file

  main:
    // Generate PQP/library from transition TSV
    OPENSWATHASSAYGENERATOR(transition_tsv)
    pqp_library_ch = OPENSWATHASSAYGENERATOR.out.library_targets

    // Create decoy library
    OPENSWATHDECOYGENERATOR(pqp_library_ch)
    pqp_library_decoyed_ch = OPENSWATHDECOYGENERATOR.out.library

    // Normalize DIA_MZML to always be tuple(run_id, path)
    // The input may already be a tuple (run_id, path) from the calling workflow
    // baseName strips the last extension (.mzML, .d, etc.)
    // For .mzML.gz files, we need to strip both extensions
    dia_normalized = DIA_MZML.map { item ->
        if (item instanceof List || item instanceof ArrayList) {
            // Already a tuple: (run_id, path) - pass through
            def run_id = item[0].toString()
            def file_path = item[1]
            return tuple(run_id, file_path)
        } else {
            // Plain path, extract run_id from baseName
            // Handle double extensions like .mzML.gz by stripping multiple times if needed
            def base = item.baseName.toString()
            // Strip common MS file extensions that might remain after baseName
            base = base.replaceAll(/(?i)\.(mzML|mzXML|raw|wiff|d)$/, '')
            return tuple(base, item)
        }
    }

    // Decide iRT strategy based on params
    if (params.use_runspecific_irts) {
        // Try to use per-run iRTs from run_peaks files
        // run_peaks files are named like <run>_run_peaks.tsv
        // Extract run_id by removing the _run_peaks suffix
        // NOTE: run_peaks_ch may contain a list of files (from glob output), so flatten first
        named_run_peaks = run_peaks_ch.flatten().map { peaks -> 
            def run_id = peaks.baseName.replaceAll(/_run_peaks$/, '')
            return tuple(run_id.toString(), peaks)
        }

        // Convert run_peaks TSV to per-run PQP
        OPENSWATHASSAYGENERATOR_NAMED(named_run_peaks)
        per_run_pqps = OPENSWATHASSAYGENERATOR_NAMED.out.run_library

        // Create linear iRT PQPs using easypqp reduce
        EASYPQP_REDUCE(per_run_pqps)
        per_run_linear = EASYPQP_REDUCE.out.reduced_pqp

        // Join full PQP and reduced PQP by run_id
        // Result: tuple(run_id, full_pqp, linear_pqp)
        joined_pqps = per_run_pqps.join(per_run_linear)
        
        // Normalize the joined_pqps run_ids to handle pseudo-spectra suffixes
        // This allows matching run-specific iRTs from pseudo-spectra (DIA-Umpire, diaTracer)
        // to the original DIA files
        // Result: tuple(normalized_run_id, original_run_id, full_pqp, linear_pqp)
        joined_pqps_normalized = joined_pqps.map { run_id, full_pqp, linear_pqp ->
            def normalized_id = normalizeRunName(run_id)
            return tuple(normalized_id, run_id, full_pqp, linear_pqp)
        }
        
        // Group by normalized_id to handle multiple pseudo-spectra per DIA file
        // e.g., DIA-Umpire produces Q1, Q2, Q3 which all normalize to the same base name
        // Result: tuple(normalized_run_id, [original_ids], [full_pqps], [linear_pqps])
        joined_pqps_grouped = joined_pqps_normalized.groupTuple(by: 0)
        
        // Select the best pseudo-spectra for each DIA file
        // Priority: Q1 > Q2 > Q3 > diatracer > first available
        // Result: tuple(normalized_run_id, best_original_id, best_full_pqp, best_linear_pqp)
        joined_pqps_best = joined_pqps_grouped.map { normalized_id, original_ids, full_pqps, linear_pqps ->
            def best_idx = 0
            
            // Find the best quality pseudo-spectra (Q1 preferred)
            for (int i = 0; i < original_ids.size(); i++) {
                def id = original_ids[i].toString()
                if (id.endsWith('_Q1')) {
                    best_idx = i
                    break  // Q1 is the best, stop searching
                } else if (id.endsWith('_Q2') && !original_ids[best_idx].toString().endsWith('_Q1')) {
                    best_idx = i
                } else if (id.endsWith('_Q3') && !original_ids[best_idx].toString().endsWith('_Q1') && !original_ids[best_idx].toString().endsWith('_Q2')) {
                    best_idx = i
                }
            }
            
            log.debug "Run-specific iRT: For DIA '${normalized_id}', selected pseudo-spectra '${original_ids[best_idx]}' from candidates: ${original_ids}"
            
            return tuple(normalized_id, original_ids[best_idx], full_pqps[best_idx], linear_pqps[best_idx])
        }

        // Join DIA files with their matching per-run PQPs using normalized names
        // Using inner join - only matched files will proceed with per-run iRTs
        // Result: tuple(normalized_run_id, dia_file, original_run_id, full_pqp, linear_pqp)
        matched_ch = dia_normalized.join(joined_pqps_best)

        // Extract the matched DIA files and their per-run iRTs
        // Note: tuple structure after join is (normalized_id, dia, original_id, full_pqp, linear_pqp)
        matched_dia = matched_ch.map { normalized_id, dia, original_id, full_pqp, linear_pqp -> 
            tuple(dia, linear_pqp, full_pqp, false)  // (dia_file, linear_irt, full_irt, use_auto_irt)
        }

        // Find unmatched DIA files using join with remainder
        // These will use auto_irt as fallback
        // Use empty list [] instead of placeholder file to avoid name collisions
        unmatched_ch = dia_normalized
            .join(joined_pqps_best, remainder: true)
            .filter { it.size() == 2 || it[2] == null }  // Only items without PQP match
            .map { items -> 
                def run_id = items[0]
                def dia = items[1]
                tuple(dia, [], [], params.use_auto_irts ?: true)
            }

        // Combine matched and unmatched into input channels for OPENSWATHWORKFLOW
        all_inputs = matched_dia.mix(unmatched_ch)
        
        dia_files_ch = all_inputs.map { dia, lin, full, auto -> dia }
        linear_irt_ch = all_inputs.map { dia, lin, full, auto -> lin }
        full_irt_ch = all_inputs.map { dia, lin, full, auto -> full }
        auto_irt_ch = all_inputs.map { dia, lin, full, auto -> auto }

        // OPENSWATHWORKFLOW signature: (dia_mzml, pqp, irt_traml, irt_nonlinear_traml, use_auto_irt_override, swath_windows)
        per_run = OPENSWATHWORKFLOW(dia_files_ch, pqp_library_decoyed_ch, linear_irt_ch, full_irt_ch, auto_irt_ch, swath_windows_ch)
    } else {
        // Not using run-specific iRTs - use global strategy
        dia_files_ch = dia_normalized.map { run_id, dia -> dia }
        
        if (params.irt_traml) {
            // Use provided iRT TraML for all runs
            // OPENSWATHWORKFLOW signature: (dia_mzml, pqp, irt_traml, irt_nonlinear_traml, use_auto_irt_override, swath_windows)
            per_run = OPENSWATHWORKFLOW(dia_files_ch, pqp_library_decoyed_ch, irt_traml_ch, irt_nonlinear_traml_ch, Channel.value(false), swath_windows_ch)
        } else if (params.use_auto_irts) {
            // Let OpenSwathWorkflow sample the PQP for iRT
            no_irt_ch = Channel.value([])
            per_run = OPENSWATHWORKFLOW(dia_files_ch, pqp_library_decoyed_ch, no_irt_ch, no_irt_ch, Channel.value(true), swath_windows_ch)
        } else {
            // No iRT calibration
            no_irt_ch = Channel.value([])
            per_run = OPENSWATHWORKFLOW(dia_files_ch, pqp_library_decoyed_ch, no_irt_ch, no_irt_ch, Channel.value(false), swath_windows_ch)
        }
    }

  emit:
    per_run_osw = per_run.osw
    chrom_mzml = per_run.chrom_mzml
    irt_trafo = per_run.irt_trafo
    irt_chrom = per_run.irt_chrom
    debug_mz = per_run.debug_mz
    debug_im = per_run.debug_im
    decoyed_library = pqp_library_decoyed_ch
    library = pqp_library_ch
}

workflow ASSAY_DECOY_FROM_PQP {

  take:
    DIA_MZML
    pqp_library
    irt_traml_ch
    irt_nonlinear_traml_ch
    run_peaks_ch
    swath_windows_ch

  main:
    // Create decoy library from provided PQP
    OPENSWATHDECOYGENERATOR(pqp_library)
    pqp_library_decoyed_ch = OPENSWATHDECOYGENERATOR.out.library

    // Normalize DIA_MZML
    dia_normalized = DIA_MZML.map { item ->
        if (item instanceof List || item instanceof ArrayList) {
            return tuple(item[0].toString(), item[1])
        } else {
            return tuple(item.baseName.toString(), item)
        }
    }

    if (params.use_runspecific_irts) {
        // NOTE: run_peaks_ch may contain a list of files (from glob output), so flatten first
        named_run_peaks = run_peaks_ch.flatten().map { peaks -> 
            def run_id = peaks.baseName.replaceAll(/_run_peaks$/, '')
            return tuple(run_id.toString(), peaks)
        }

        OPENSWATHASSAYGENERATOR_NAMED(named_run_peaks)
        per_run_pqps = OPENSWATHASSAYGENERATOR_NAMED.out.run_library

        EASYPQP_REDUCE(per_run_pqps)
        per_run_linear = EASYPQP_REDUCE.out.reduced_pqp

        joined_pqps = per_run_pqps.join(per_run_linear)
        
        // Normalize the joined_pqps run_ids to handle pseudo-spectra suffixes
        // This allows matching run-specific iRTs from pseudo-spectra (DIA-Umpire, diaTracer)
        // to the original DIA files
        // Result: tuple(normalized_run_id, original_run_id, full_pqp, linear_pqp)
        joined_pqps_normalized = joined_pqps.map { run_id, full_pqp, linear_pqp ->
            def normalized_id = normalizeRunName(run_id)
            return tuple(normalized_id, run_id, full_pqp, linear_pqp)
        }
        
        // Group by normalized_id to handle multiple pseudo-spectra per DIA file
        // e.g., DIA-Umpire produces Q1, Q2, Q3 which all normalize to the same base name
        // Result: tuple(normalized_run_id, [original_ids], [full_pqps], [linear_pqps])
        joined_pqps_grouped = joined_pqps_normalized.groupTuple(by: 0)
        
        // Select the best pseudo-spectra for each DIA file
        // Priority: Q1 > Q2 > Q3 > diatracer > first available
        // Result: tuple(normalized_run_id, best_original_id, best_full_pqp, best_linear_pqp)
        joined_pqps_best = joined_pqps_grouped.map { normalized_id, original_ids, full_pqps, linear_pqps ->
            def best_idx = 0
            
            // Find the best quality pseudo-spectra (Q1 preferred)
            for (int i = 0; i < original_ids.size(); i++) {
                def id = original_ids[i].toString()
                if (id.endsWith('_Q1')) {
                    best_idx = i
                    break  // Q1 is the best, stop searching
                } else if (id.endsWith('_Q2') && !original_ids[best_idx].toString().endsWith('_Q1')) {
                    best_idx = i
                } else if (id.endsWith('_Q3') && !original_ids[best_idx].toString().endsWith('_Q1') && !original_ids[best_idx].toString().endsWith('_Q2')) {
                    best_idx = i
                }
            }
            
            log.debug "Run-specific iRT: For DIA '${normalized_id}', selected pseudo-spectra '${original_ids[best_idx]}' from candidates: ${original_ids}"
            
            return tuple(normalized_id, original_ids[best_idx], full_pqps[best_idx], linear_pqps[best_idx])
        }
        
        matched_ch = dia_normalized.join(joined_pqps_best)

        // Note: tuple structure after join is (normalized_id, dia, original_id, full_pqp, linear_pqp)
        matched_dia = matched_ch.map { normalized_id, dia, original_id, full_pqp, linear_pqp -> 
            tuple(dia, linear_pqp, full_pqp, false)
        }

        no_irt_file = file('NO_IRT_FILE')
        unmatched_ch = dia_normalized
            .join(joined_pqps_best, remainder: true)
            .filter { it.size() == 2 || it[2] == null }
            .map { items -> 
                def run_id = items[0]
                def dia = items[1]
                tuple(dia, no_irt_file, no_irt_file, params.use_auto_irts ?: true)
            }

        all_inputs = matched_dia.mix(unmatched_ch)
        
        dia_files_ch = all_inputs.map { dia, lin, full, auto -> dia }
        linear_irt_ch = all_inputs.map { dia, lin, full, auto -> lin }
        full_irt_ch = all_inputs.map { dia, lin, full, auto -> full }
        auto_irt_ch = all_inputs.map { dia, lin, full, auto -> auto }

        // OPENSWATHWORKFLOW signature: (dia_mzml, pqp, irt_traml, irt_nonlinear_traml, use_auto_irt_override, swath_windows)
        per_run = OPENSWATHWORKFLOW(dia_files_ch, pqp_library_decoyed_ch, linear_irt_ch, full_irt_ch, auto_irt_ch, swath_windows_ch)
    } else {
        dia_files_ch = dia_normalized.map { run_id, dia -> dia }
        
        if (params.irt_traml) {
            // OPENSWATHWORKFLOW signature: (dia_mzml, pqp, irt_traml, irt_nonlinear_traml, use_auto_irt_override, swath_windows)
            per_run = OPENSWATHWORKFLOW(dia_files_ch, pqp_library_decoyed_ch, irt_traml_ch, irt_nonlinear_traml_ch, Channel.value(false), swath_windows_ch)
        } else if (params.use_auto_irts) {
            no_irt_ch = Channel.value(file('NO_IRT_FILE'))
            per_run = OPENSWATHWORKFLOW(dia_files_ch, pqp_library_decoyed_ch, no_irt_ch, no_irt_ch, Channel.value(true), swath_windows_ch)
        } else {
            no_irt_ch = Channel.value(file('NO_IRT_FILE'))
            per_run = OPENSWATHWORKFLOW(dia_files_ch, pqp_library_decoyed_ch, no_irt_ch, no_irt_ch, Channel.value(false), swath_windows_ch)
        }
    }

  emit:
    per_run_osw = per_run.osw
    chrom_mzml = per_run.chrom_mzml
    irt_trafo = per_run.irt_trafo
    irt_chrom = per_run.irt_chrom
    debug_mz = per_run.debug_mz
    debug_im = per_run.debug_im
    decoyed_library = pqp_library_decoyed_ch
}
