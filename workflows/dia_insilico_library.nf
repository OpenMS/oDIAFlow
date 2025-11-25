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
include { ASSAY_DECOY_FROM_TRANSITION, ASSAY_DECOY_FROM_PQP } from '../subworkflows/local/assay_decoy_extraction/main.nf'
include { MERGE_ALIGN_SCORE } from '../subworkflows/local/merge_align_score/main.nf'

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
        if (params.dia_glob.endsWith('.d')) {
            Channel
              .fromPath(params.dia_glob, type: 'dir', checkIfExists: true)
              .map { it -> tuple(it.baseName, it) }
              .set { DIA_MZML }
        } else {
            Channel
                .fromList(file(params.dia_glob))
                .map { it -> tuple(it.baseName, it) }
                .set { DIA_MZML }
        }

    // We assume the user provides an in-silico generated transition TSV, generated from alphapepdeep, DIA-NN etc.
    transition_tsv_ch = Channel.value( file(params.transition_tsv) )
    
    // Optional IRT files - use empty list [] if not provided (Nextflow will stage as empty input.N files)
    irt_traml_ch = params.irt_traml ? Channel.value(file(params.irt_traml)) : Channel.value([])
    irt_nonlinear_traml_ch = params.irt_nonlinear_traml ? Channel.value(file(params.irt_nonlinear_traml)) : Channel.value([])
    
    swath_windows_ch = params.swath_windows ? Channel.value(file(params.swath_windows)) : Channel.value([])

    // 2-4) Create assay/decoy and run extraction via subworkflow
    assay_out = ASSAY_DECOY_FROM_TRANSITION(DIA_MZML, transition_tsv_ch, irt_traml_ch, irt_nonlinear_traml_ch, swath_windows_ch)

    per_run_osw = assay_out.per_run_osw
    decoy_library = assay_out.decoyed_library

    // Collect XIC files (.sqMass) for alignment
    xic_files = per_run_osw.chrom_mzml.collect()

    // Collect debug calibration files for calibration report
    all_debug_files = per_run_osw.irt_trafo
      .mix(per_run_osw.irt_chrom, per_run_osw.debug_mz, per_run_osw.debug_im)
      .collect()
    
    // Generate calibration report from debug files
    calibration_report = PYPROPHET_CALIBRATION_REPORT(all_debug_files)

    // 5-7) Merge, align and score using shared subworkflow
    merge_out = MERGE_ALIGN_SCORE(per_run_osw, decoy_library)
    final_tsv = merge_out.results_tsv

    // emit final TSV
    final_tsv.view { "Finished: ${it}" }
}
