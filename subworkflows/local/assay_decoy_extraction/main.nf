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
    pqp_library_ch = OPENSWATHASSAYGENERATOR.out.library

    // Create decoy library
    OPENSWATHDECOYGENERATOR(pqp_library_ch)
    pqp_library_decoyed_ch = OPENSWATHDECOYGENERATOR.out.library

    // Normalize DIA_MZML to always be tuple(run_id, path)
    // The input may already be a tuple (run_id, path) from the calling workflow
    // baseName strips the last extension (.mzML, .d, etc.)
    dia_normalized = DIA_MZML.map { item ->
        if (item instanceof List || item instanceof ArrayList) {
            // Already a tuple: (run_id, path) - pass through
            def run_id = item[0].toString()
            def file_path = item[1]
            return tuple(run_id, file_path)
        } else {
            // Plain path, extract run_id from baseName
            return tuple(item.baseName.toString(), item)
        }
    }
    
    // DEBUG: Show normalized DIA files
    dia_normalized.view { "[DEBUG] DIA normalized: run_id='${it[0]}', file=${it[1]}" }

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
        
        // DEBUG: Show named run_peaks
        named_run_peaks.view { "[DEBUG] run_peaks: run_id='${it[0]}', file=${it[1]}" }

        // Convert run_peaks TSV to per-run PQP
        OPENSWATHASSAYGENERATOR_NAMED(named_run_peaks)
        per_run_pqps = OPENSWATHASSAYGENERATOR_NAMED.out.run_library

        // Create linear iRT PQPs using easypqp reduce
        EASYPQP_REDUCE(per_run_pqps)
        per_run_linear = EASYPQP_REDUCE.out.reduced_pqp

        // Join full PQP and reduced PQP by run_id
        // Result: tuple(run_id, full_pqp, linear_pqp)
        joined_pqps = per_run_pqps.join(per_run_linear)
        
        // DEBUG: Show joined PQPs
        joined_pqps.view { "[DEBUG] joined_pqps: run_id='${it[0]}', full_pqp=${it[1]}, linear_pqp=${it[2]}" }

        // Join DIA files with their matching per-run PQPs
        // Using inner join - only matched files will proceed with per-run iRTs
        // Result: tuple(run_id, dia_file, full_pqp, linear_pqp)
        matched_ch = dia_normalized.join(joined_pqps)
        
        // DEBUG: Show matched results
        matched_ch.view { "[DEBUG] MATCHED: run_id='${it[0]}', dia=${it[1]}, full_pqp=${it[2]}, linear_pqp=${it[3]}" }

        // Extract the matched DIA files and their per-run iRTs
        matched_dia = matched_ch.map { run_id, dia, full_pqp, linear_pqp -> 
            tuple(dia, linear_pqp, full_pqp, false)  // (dia_file, linear_irt, full_irt, use_auto_irt)
        }

        // Find unmatched DIA files using join with remainder
        // These will use auto_irt as fallback
        no_irt_file = file('NO_IRT_FILE')
        unmatched_ch = dia_normalized
            .join(joined_pqps, remainder: true)
            .filter { it.size() == 2 || it[2] == null }  // Only items without PQP match
            .map { items -> 
                def run_id = items[0]
                def dia = items[1]
                tuple(dia, no_irt_file, no_irt_file, params.use_auto_irts ?: true)
            }
        
        // DEBUG: Show unmatched results
        unmatched_ch.view { "[DEBUG] UNMATCHED: dia=${it[0]}, using auto_irt=${it[3]}" }

        // Combine matched and unmatched into input channels for OPENSWATHWORKFLOW
        all_inputs = matched_dia.mix(unmatched_ch)
        
        dia_files_ch = all_inputs.map { dia, lin, full, auto -> dia }
        linear_irt_ch = all_inputs.map { dia, lin, full, auto -> lin }
        full_irt_ch = all_inputs.map { dia, lin, full, auto -> full }
        auto_irt_ch = all_inputs.map { dia, lin, full, auto -> auto }

        per_run = OPENSWATHWORKFLOW(dia_files_ch, pqp_library_decoyed_ch, linear_irt_ch, full_irt_ch, swath_windows_ch, auto_irt_ch)
    } else {
        // Not using run-specific iRTs - use global strategy
        dia_files_ch = dia_normalized.map { run_id, dia -> dia }
        
        if (params.irt_traml) {
            // Use provided iRT TraML for all runs
            per_run = OPENSWATHWORKFLOW(dia_files_ch, pqp_library_decoyed_ch, irt_traml_ch, irt_nonlinear_traml_ch, swath_windows_ch, Channel.value(false))
        } else if (params.use_auto_irts) {
            // Let OpenSwathWorkflow sample the PQP for iRT
            no_irt_ch = Channel.value(file('NO_IRT_FILE'))
            per_run = OPENSWATHWORKFLOW(dia_files_ch, pqp_library_decoyed_ch, no_irt_ch, no_irt_ch, swath_windows_ch, Channel.value(true))
        } else {
            // No iRT calibration
            no_irt_ch = Channel.value(file('NO_IRT_FILE'))
            per_run = OPENSWATHWORKFLOW(dia_files_ch, pqp_library_decoyed_ch, no_irt_ch, no_irt_ch, swath_windows_ch, Channel.value(false))
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
        matched_ch = dia_normalized.join(joined_pqps)

        matched_dia = matched_ch.map { run_id, dia, full_pqp, linear_pqp -> 
            tuple(dia, linear_pqp, full_pqp, false)
        }

        no_irt_file = file('NO_IRT_FILE')
        unmatched_ch = dia_normalized
            .join(joined_pqps, remainder: true)
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

        per_run = OPENSWATHWORKFLOW(dia_files_ch, pqp_library_decoyed_ch, linear_irt_ch, full_irt_ch, swath_windows_ch, auto_irt_ch)
    } else {
        dia_files_ch = dia_normalized.map { run_id, dia -> dia }
        
        if (params.irt_traml) {
            per_run = OPENSWATHWORKFLOW(dia_files_ch, pqp_library_decoyed_ch, irt_traml_ch, irt_nonlinear_traml_ch, swath_windows_ch, Channel.value(false))
        } else if (params.use_auto_irts) {
            no_irt_ch = Channel.value(file('NO_IRT_FILE'))
            per_run = OPENSWATHWORKFLOW(dia_files_ch, pqp_library_decoyed_ch, no_irt_ch, no_irt_ch, swath_windows_ch, Channel.value(true))
        } else {
            no_irt_ch = Channel.value(file('NO_IRT_FILE'))
            per_run = OPENSWATHWORKFLOW(dia_files_ch, pqp_library_decoyed_ch, no_irt_ch, no_irt_ch, swath_windows_ch, Channel.value(false))
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
