/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES: Local to the pipeline
//
include { DIAPYSEF_TDF_TO_MZML }           from '../modules/local/diapysef_tdf_to_mzml/main.nf'
include { OPENSWATHASSAYGENERATOR }        from '../modules/local/openms/openswathassaygenerator/main.nf'
include { OPENSWATHDECOYGENERATOR }        from '../modules/local/openms/openswathdecoygenerator/main.nf'
include { OPENSWATHWORKFLOW }              from '../modules/local/openms/openswathworkflow/main.nf'
include { PYPROPHET_CALIBRATION_REPORT }   from '../modules/local/pyprophet/calibration_report/main.nf'
include { PYPROPHET_EXPORT_PARQUET }       from '../modules/local/pyprophet/export_parquet/main.nf'
include { PYPROPHET_MERGE_OSWPQ }          from '../modules/local/pyprophet/merge_oswpq/main.nf'
include { PYPROPHET_MERGE }                from '../modules/local/pyprophet/merge/main.nf'
include { ARYCAL }                         from '../modules/local/arycal/main.nf'
include { PYPROPHET_ALIGNMENT_SCORING }    from '../modules/local/pyprophet/alignment_scoring/main.nf'
include { PYPROPHET_OSW_FULL }             from '../subworkflows/local/pyprophet_osw/main.nf'
include { PYPROPHET_PARQUET_FULL }         from '../subworkflows/local/pyprophet_parquet/main.nf'

//
// SUBWORKFLOWS: Consisting of a mix of local and nf-core/modules
//

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow OPEN_SWATH_INSILICO_LIBRARY {

    // 1) Gather inputs
    Channel
        .fromList(file(params.dia_glob))
        .set { DIA_MZML }

    // We assume the user provides an in-silico generated transition TSV, generated from alphapepdeep, DIA-NN etc.
    transition_tsv_ch = Channel.value( file(params.transition_tsv) )
    
    // Optional IRT files - use empty list [] if not provided (Nextflow will stage as empty input.N files)
    irt_traml_ch = params.irt_traml ? Channel.value(file(params.irt_traml)) : Channel.value([])
    irt_nonlinear_traml_ch = params.irt_nonlinear_traml ? Channel.value(file(params.irt_nonlinear_traml)) : Channel.value([])
    
    swath_windows_ch = params.swath_windows ? Channel.value(file(params.swath_windows)) : Channel.value([])

    // 2) Generate assay library from transition TSV
    pqp_library = OPENSWATHASSAYGENERATOR(transition_tsv_ch)

    // 3) Generate decoys for the assay library
    pqp_library_decoyed = OPENSWATHDECOYGENERATOR(pqp_library)

    // 4) OpenSwathWorkflow extraction per DIA mzML → per-run .osw + .sqMass (XICs)
    per_run_osw = OPENSWATHWORKFLOW(DIA_MZML, pqp_library_decoyed, irt_traml_ch, irt_nonlinear_traml_ch, swath_windows_ch)
    
    // Collect XIC files (.sqMass) for alignment
    xic_files = per_run_osw.chrom_mzml.collect()

    // Collect debug calibration files for calibration report
    all_debug_files = per_run_osw.irt_trafo
      .mix(per_run_osw.irt_chrom, per_run_osw.debug_mz, per_run_osw.debug_im)
      .collect()
    
    // Generate calibration report from debug files
    calibration_report = PYPROPHET_CALIBRATION_REPORT(all_debug_files)

    // 5) Merge OSW files BEFORE alignment
    // Optional: use parquet format for PyProphet processing
    if (params.use_parquet) {
      /*
        Convert each OSW to parquet directory (.oswpq).
        per_run_osw.osw is a channel of paths
      */
      PYPROPHET_EXPORT_PARQUET(per_run_osw.osw.map { osw -> tuple(osw.baseName, osw) })
      
      /*
        Collect all .oswpq directories into a single list and merge them
        into a unified .oswpqd directory structure.
      */
      all_oswpq_dirs = PYPROPHET_EXPORT_PARQUET.out.oswpq.map{ it[1] }.collect()
      merged_features = PYPROPHET_MERGE_OSWPQ(all_oswpq_dirs)
    } else {
      // For SQLite format, merge OSW files
      all_osw_files = per_run_osw.osw.collect()
      merged_features = PYPROPHET_MERGE(all_osw_files, pqp_library_decoyed)
    }

    // 6) XIC alignment for across-run feature linking
    // ARYCAL expects: xic_files (.sqMass) and merged features (osw or oswpqd)
    arycal_output = ARYCAL(xic_files, merged_features)

    // Score aligned features (use the aligned OSW file, not the config JSON)
    aligned_features_scored = PYPROPHET_ALIGNMENT_SCORING(arycal_output.aligned_features)

    // 7) PyProphet scoring on aligned features (score → infer peptide/protein)
    if (params.use_parquet) {
      PYPROPHET_PARQUET_FULL(aligned_features_scored, pqp_library_decoyed)
      final_tsv = PYPROPHET_PARQUET_FULL.out.results_tsv
    } else {
      PYPROPHET_OSW_FULL(aligned_features_scored, pqp_library_decoyed)
      final_tsv = PYPROPHET_OSW_FULL.out.results_tsv
    }

    // emit final TSV
    final_tsv.view { "Finished: ${it}" }
}
