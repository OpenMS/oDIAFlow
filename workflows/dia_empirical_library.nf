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
include { OPENSWATH_EXTRACT }              from '../modules/local/openms/openswathworkflow/main.nf'
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

// Info required for completion email and summary
def multiqc_report = []

workflow OPEN_SWATH_E2E {

    // 1) Gather inputs
    Channel
      .fromPath(params.dda_glob, checkIfExists: true)
      .map { it -> tuple(it.baseName, it) }
      .set { DDA_MZML }

    Channel
      .fromPath(params.dia_glob, checkIfExists: true)
      .map { it -> tuple(it.baseName, it) }
      .set { DIA_MZML }

    fasta_ch         = Channel.value(file(params.fasta))
    irt_traml_ch     = params.irt_traml ? Channel.value(file(params.irt_traml)) : Channel.empty()
    swath_windows_ch = params.swath_windows ? Channel.value(file(params.swath_windows)) : Channel.empty()

    // 2) DDA search with SAGE → results TSV + matched fragments TSV
    sage_results = SAGE_SEARCH(DDA_MZML, fasta_ch)

    // 3) Convert SAGE → EasyPQP pickle format (per run)
    // Join results and matched_fragments by sample_id, then pass as tuple
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
    per_run_osw = OPENSWATH_EXTRACT(DIA_MZML, pqp_library, irt_traml_ch, swath_windows_ch)
    
    // Collect XIC files (.sqMass) for alignment
    xic_files = per_run_osw.chrom_mzml.collect()

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
    aligned_features = ARYCAL(xic_files, merged_features)

    // Score aligned features
    aligned_features_scored = PYPROPHET_ALIGNMENT_SCORING(aligned_features)

    // 8) PyProphet scoring on aligned features (score → infer peptide/protein)
    if (params.use_parquet) {
      final_tsv = PYPROPHET_PARQUET_FULL(aligned_features_scored, pqp_library)
    } else {
      final_tsv = PYPROPHET_OSW_FULL(aligned_features_scored, pqp_library)
    }

    // emit final TSV
    final_tsv.view { "Finished: ${it}" }
}
