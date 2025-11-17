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

workflow OPEN_SWATH_INSILICO_LIBRARY {

    // 1) Gather inputs
    Channel
      .fromPath(params.dia_glob, checkIfExists: true)
      .map { it -> tuple(it.baseName, it) }
      .set { DIA_MZML }

    // We assume the user provides an in-silico generated transition TSV, generated from alphapepdeep, DIA-NN etc.
    transition_tsv_ch = Channel.value( file(params.transition_tsv) )
    irt_traml_ch     = params.irt_traml ? Channel.value(file(params.irt_traml)) : Channel.empty()
    swath_windows_ch = params.swath_windows ? Channel.value(file(params.swath_windows)) : Channel.empty()

    // 2) Generate assay library from transition TSV
    pqp_library = OPENSWATHASSAYGENERATOR(transition_tsv_ch)

    // 3) Generate decoys for the assay library
    pqp_library_decoyed = OPENSWATHDECOYGENERATOR(pqp_library)

    // 4) OpenSwathWorkflow extraction per DIA mzML → per-run .osw + .sqMass (XICs)
    per_run_osw = OPENSWATH_EXTRACT(DIA_MZML, pqp_library_decoyed, irt_traml_ch, swath_windows_ch)
    
    // Collect XIC files (.sqMass) for alignment
    xic_files = per_run_osw.chrom_mzml.collect()

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
    aligned_features = ARYCAL(xic_files, merged_features)

    // Score aligned features
    aligned_features_scored = PYPROPHET_ALIGNMENT_SCORING(aligned_features)

    // 7) PyProphet scoring on aligned features (score → infer peptide/protein)
    if (params.use_parquet) {
      final_tsv = PYPROPHET_PARQUET_FULL(aligned_features_scored, pqp_library_decoyed)
    } else {
      final_tsv = PYPROPHET_OSW_FULL(aligned_features_scored, pqp_library_decoyed)
    }

    // emit final TSV
    final_tsv.view { "Finished: ${it}" }
}
