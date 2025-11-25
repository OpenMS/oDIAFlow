/*
  Subworkflow group to create assay/decoy and run OpenSwath extraction.

  Provides two workflows:
    - ASSAY_DECOY_FROM_TRANSITION: takes a transition TSV and runs OpenSwathAssayGenerator -> decoy -> OpenSwathWorkflow
    - ASSAY_DECOY_FROM_PQP: takes an existing PQP/library file, runs decoy -> OpenSwathWorkflow

  Emits:
    - per_run_osw: composite channel returned by OPENSWATHWORKFLOW
    - decoyed_library: the decoyed PQP/library file
    - library: the pqp produced from transition (when applicable)
*/

include { OPENSWATHASSAYGENERATOR } from '../../../modules/local/openms/openswathassaygenerator/main.nf'
include { OPENSWATHDECOYGENERATOR } from '../../../modules/local/openms/openswathdecoygenerator/main.nf'
include { OPENSWATHWORKFLOW } from '../../../modules/local/openms/openswathworkflow/main.nf'

workflow ASSAY_DECOY_FROM_TRANSITION {

  take:
    DIA_MZML
    transition_tsv
    irt_traml_ch
    irt_nonlinear_traml_ch
    run_peaks_ch
    swath_windows_ch

  main:
    // Generate PQP/library from transition TSV
    pqp_library = OPENSWATHASSAYGENERATOR(transition_tsv)

    // Create decoy library
    pqp_library_decoyed = OPENSWATHDECOYGENERATOR(pqp_library)

    // If run-specific peaks (run_peaks_ch) are provided, convert them to per-run PQPs and pair with DIA_MZML
    if (run_peaks_ch && !run_peaks_ch.empty) {
        // run_peaks_ch elements are paths like <run>_run_peaks.tsv; map to (run_id, path)
        named_run_peaks = run_peaks_ch.map { peaks -> tuple(peaks.baseName.replaceAll(/_run_peaks$/, ''), peaks) }

        // Convert each run peaks TSV into a per-run PQP by calling the named OPENSWATHASSAYGENERATOR
        per_run_pqps = OPENSWATHASSAYGENERATOR_NAMED(named_run_peaks)

        // Create linear iRT PQPs from per-run full PQPs using easypqp reduce
        include { EASYPQP_REDUCE } from '../../../modules/local/easypqp/reduce/main.nf'
        per_run_linear = EASYPQP_REDUCE(per_run_pqps)

        // Join full PQP and reduced PQP by run id to get tuples (run_id, full_pqp, linear_pqp)
        // per_run_pqps and per_run_linear are both channels of tuple(run_id, path)
        full_map = per_run_pqps.map { run_id, pqp -> tuple(run_id, pqp) }
        linear_map = per_run_linear.map { run_id, pqp -> tuple(run_id, pqp) }

        joined_pqps = full_map.join(linear_map).map { id, full, linear -> tuple(id, full[1], linear[1]) }

        // Ensure DIA_MZML is a channel of tuples (run_id, mzml_path)
        named_dia = DIA_MZML.map { d -> d instanceof Tuple ? d : tuple(d.baseName, d) }

        // Join DIA mzMLs with per-run PQPs by run id
        paired = named_dia.join(joined_pqps)

        // Create channels aligned for OPENSWATHWORKFLOW: dia_files, linear iRT pqps, nonlinear (full) iRT pqps
        dia_files = paired.map { run_id, mzml, pqp_trip -> mzml }
        per_run_linear_pqps = paired.map { run_id, mzml, pqp_trip -> pqp_trip[2] }
        per_run_full_pqps = paired.map { run_id, mzml, pqp_trip -> pqp_trip[1] }

        // Run OpenSwathWorkflow per run, providing per-run linear and nonlinear iRT PQPs
        per_run = OPENSWATHWORKFLOW(dia_files, pqp_library_decoyed.out.library, per_run_linear_pqps, per_run_full_pqps, swath_windows_ch)
    } else {
        // Run extraction with decoyed library using global IRT channels
        per_run = OPENSWATHWORKFLOW(DIA_MZML, pqp_library_decoyed, irt_traml_ch, irt_nonlinear_traml_ch, swath_windows_ch)
    }

  emit:
    per_run_osw = per_run
    decoyed_library = pqp_library_decoyed.out.library
    library = pqp_library.out.library
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
    pqp_library_decoyed = OPENSWATHDECOYGENERATOR(pqp_library)

    // If run-specific peaks provided, convert and pair like the transition workflow
    if (run_peaks_ch && !run_peaks_ch.empty) {
      named_run_peaks = run_peaks_ch.map { peaks -> tuple(peaks.baseName.replaceAll(/_run_peaks$/, ''), peaks) }

      // Convert each run peaks TSV into a per-run PQP by calling the named OPENSWATHASSAYGENERATOR
      per_run_pqps = OPENSWATHASSAYGENERATOR_NAMED(named_run_peaks)

      named_dia = DIA_MZML.map { d -> d instanceof Tuple ? d : tuple(d.baseName, d) }
      paired = named_dia.join(per_run_pqps)
      dia_files = paired.map { run_id, mzml, run_pqp -> mzml }
      per_run_irt_pqps = paired.map { run_id, mzml, run_pqp -> run_pqp }

      per_run = OPENSWATHWORKFLOW(dia_files, pqp_library_decoyed, per_run_irt_pqps, irt_nonlinear_traml_ch, swath_windows_ch)
    } else {
      // Run extraction with decoyed library
      per_run = OPENSWATHWORKFLOW(DIA_MZML, pqp_library_decoyed, irt_traml_ch, irt_nonlinear_traml_ch, swath_windows_ch)
    }

  emit:
    per_run_osw = per_run
    decoyed_library = pqp_library_decoyed.out.library
}
