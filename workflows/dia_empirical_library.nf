/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES: Local to the pipeline
//
include { DIAPYSEF_TDF_TO_MZML }           from '../modules/local/diapysef_tdf_to_mzml/main.nf'
include { SAGE_SEARCH }                    from '../modules/local/sage/main.nf'
include { EASYPQP_CONVERTSAGE }            from '../modules/local/easypqp/convertsage/main.nf'
include { EASYPQP_LIBRARY }                from '../modules/local/easypqp/library/main.nf'
include { OPENSWATHASSAYGENERATOR }        from '../modules/local/openms/openswathassaygenerator/main.nf'
include { OPENSWATHDECOYGENERATOR }        from '../modules/local/openms/openswathdecoygenerator/main.nf'
include { OPENSWATHWORKFLOW }              from '../modules/local/openms/openswathworkflow/main.nf'
include { PYPROPHET_EXPORT_PARQUET }       from '../modules/local/pyprophet/export_parquet/main.nf'
include { PYPROPHET_MERGE_OSWPQ }          from '../modules/local/pyprophet/merge_oswpq/main.nf'
include { PYPROPHET_MERGE }                from '../modules/local/pyprophet/merge/main.nf'
include { ARYCAL }                         from '../modules/local/arycal/main.nf'
include { PYPROPHET_CALIBRATION_REPORT }   from '../modules/local/pyprophet/calibration_report/main.nf'
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

workflow OPEN_SWATH_E2E {

    // 1) Gather inputs
    // Collect all DDA files for a single Sage search
    Channel
      .fromPath(params.dda_glob, checkIfExists: true)
      .collect()
      .map { files -> tuple("all_dda", files) }
      .set { DDA_MZML }

    Channel
      .fromPath(params.dia_glob, checkIfExists: true)
      .map { it -> tuple(it.baseName, it) }
      .set { DIA_MZML }

    fasta_ch         = Channel.value(file(params.fasta))
    irt_traml_ch     = params.irt_traml ? Channel.value(file(params.irt_traml)) : Channel.value([])
    irt_nonlinear_traml_ch = params.irt_nonlinear_traml ? Channel.value(file(params.irt_nonlinear_traml)) : Channel.value([])
    swath_windows_ch = params.swath_windows ? Channel.value(file(params.swath_windows)) : Channel.value([])

    // 2) DDA search with SAGE → results TSV + matched fragments TSV
    // Sage searches all DDA files together
    sage_results = SAGE_SEARCH(DDA_MZML, fasta_ch)

    // 3) Convert SAGE → EasyPQP pickle format (per run)
    // We need to process results per-run for EasyPQP, but Sage output is combined
    // For now, use the combined output (sample_id will be "all_dda")
    sage_combined = sage_results.results.join(sage_results.matched_fragments)
    
    EASYPQP_CONVERTSAGE(sage_combined)

    // 4) Build spectral library (PQP) with EasyPQP
    //    Collect all pickle files from all runs
    all_psmpkls = EASYPQP_CONVERTSAGE.out.psmpkl.map{ it[1] }.collect()
    all_peakpkls = EASYPQP_CONVERTSAGE.out.peakpkl.map{ it[1] }.collect()
    transition_tsv = EASYPQP_LIBRARY(all_psmpkls, all_peakpkls)

    // Generate assay library from transition TSV
    pqp_library_targets = OPENSWATHASSAYGENERATOR(transition_tsv)

    // Generate decoys for the assay library
    pqp_library = OPENSWATHDECOYGENERATOR(pqp_library_targets)

    // 5) OpenSwathWorkflow extraction per DIA mzML → per-run .osw + .sqMass (XICs)
    per_run_osw = OPENSWATHWORKFLOW(DIA_MZML, pqp_library, irt_traml_ch, irt_nonlinear_traml_ch, swath_windows_ch)
    
    // Collect XIC files (.sqMass) for alignment
    xic_files = per_run_osw.chrom_mzml.collect()
    
    // Collect debug calibration files for calibration report
    all_debug_files = per_run_osw.irt_trafo
      .mix(per_run_osw.irt_chrom, per_run_osw.debug_mz, per_run_osw.debug_im)
      .collect()
    
    // Generate calibration report from debug files
    calibration_report = PYPROPHET_CALIBRATION_REPORT(all_debug_files)

    // 6) Merge OSW files BEFORE alignment
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
      merged_features = PYPROPHET_MERGE(all_osw_files, pqp_library)
    }

    // 7) XIC alignment for across-run feature linking
    // ARYCAL expects: xic_files (.sqMass) and merged features (osw or oswpqd)
    arycal_output = ARYCAL(xic_files, merged_features)

    // Score aligned features
    aligned_features_scored = PYPROPHET_ALIGNMENT_SCORING(arycal_output.aligned_features)

    // 8) PyProphet scoring on aligned features (score → infer peptide/protein)
    if (params.use_parquet) {
      pyprophet_output = PYPROPHET_PARQUET_FULL(aligned_features_scored, pqp_library)
      final_tsv = pyprophet_output.results_tsv
    } else {
      pyprophet_output = PYPROPHET_OSW_FULL(aligned_features_scored, pqp_library)
      final_tsv = pyprophet_output.results_tsv
    }

    // emit final TSV
    final_tsv.view { "Finished: ${it}" }
}
