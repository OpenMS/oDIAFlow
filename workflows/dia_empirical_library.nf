/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES: Local to the pipeline
//
include { DIAPYSEF_TDF_TO_MZML }           from '../modules/local/diapysef_tdf_to_mzml/main.nf'
include { SAGE_SEARCH }                    from '../modules/local/sage/search/main.nf'
include { SAGE_SEARCH as SAGE_SEARCH_DIA } from '../modules/local/sage/search/main.nf'
include { SAGE_COMBINE_RESULTS }           from '../modules/local/sage/combine_searches/main.nf'
include { EASYPQP_CONVERTSAGE }            from '../modules/local/easypqp/convertsage/main.nf'
include { EASYPQP_LIBRARY }                from '../modules/local/easypqp/library/main.nf'
include { OPENSWATHASSAYGENERATOR }        from '../modules/local/openms/openswathassaygenerator/core/main.nf'
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
include { ASSAY_DECOY_FROM_TRANSITION } from '../subworkflows/local/assay_decoy_extraction/main.nf'
include { ASSAY_DECOY_FROM_PQP } from '../subworkflows/local/assay_decoy_extraction/main.nf'
include { MERGE_ALIGN_SCORE } from '../subworkflows/local/merge_align_score/main.nf'
include { SAGE_EASYPQP_LIBRARY } from '../subworkflows/local/sage_easypqp_library/main.nf'

//
// SUBWORKFLOWS: Consisting of a mix of local and nf-core/modules
//

/*
========================================================================================
    PUBLISH OUTPUTS
========================================================================================
*/

// Helper function to create publishDir settings
def getPublishSettings(subdirectory, enabled = true, saveFor = 'all') {
    def settings = [
        path: { "${params.outdir}/${subdirectory}" },
        mode: params.publish_dir_mode,
        enabled: enabled
    ]
    
    if (saveFor == 'logs') {
        settings.enabled = params.save_logs
        settings.pattern = "*.log"
    } else if (saveFor == 'reports') {
        settings.enabled = params.save_reports
        settings.pattern = "*.pdf"
    } else if (saveFor == 'intermediates') {
        settings.enabled = params.save_intermediates
    }
    
    return settings
}

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow OPEN_SWATH_E2E {

    // 1) Gather inputs
    // Collect all DDA files for a single Sage search (if provided)
    // Handle .d directories (Bruker TDF) or regular files (mzML, mzML.gz)
    if (params.dda_glob) {
        if (params.dda_glob.endsWith('.d')) {
            Channel
              .fromPath(params.dda_glob, type: 'dir', checkIfExists: true)
              .collect()
              .map { files -> tuple("all_dda", files, "dda") }
              .set { DDA_FOR_SEARCH }
        } else {
            Channel
              .fromPath(params.dda_glob, checkIfExists: true)
              .collect()
              .map { files -> tuple("all_dda", files, "dda") }
              .set { DDA_FOR_SEARCH }
        }
    } else {
        // No DDA files provided - create empty channel
        Channel.empty().set { DDA_FOR_SEARCH }
    }

    // Optional: Collect DIA files for library building with Sage
    if (params.sage.search_dia_for_lib && params.dia_for_lib_glob) {
        if (params.dia_for_lib_glob.endsWith('.d')) {
            Channel
              .fromPath(params.dia_for_lib_glob, type: 'dir', checkIfExists: true)
              .collect()
              .map { files -> tuple("all_dia_lib", files, "dia") }
              .set { DIA_FOR_SEARCH }
        } else {
            Channel
              .fromPath(params.dia_for_lib_glob, checkIfExists: true)
              .collect()
              .map { files -> tuple("all_dia_lib", files, "dia") }
              .set { DIA_FOR_SEARCH }
        }
    } else {
        // Create empty channel if not searching DIA
        Channel.empty().set { DIA_FOR_SEARCH }
    }

    // DIA files for extraction (separate from DIA for library)
    // Handles double extensions like .mzML.gz by stripping both
    if (params.dia_glob.endsWith('.d')) {
        Channel
          .fromPath(params.dia_glob, type: 'dir', checkIfExists: true)
          .map { path -> 
              def base = path.baseName.toString()
              // Strip common MS file extensions that might remain after baseName
              base = base.replaceAll(/(?i)\.(mzML|mzXML|raw|wiff|d)$/, '')
              tuple(base, path)
          }
          .set { DIA_MZML }
    } else {
        Channel
            .fromList(file(params.dia_glob))
            .map { path -> 
                def base = path.baseName.toString()
                // Strip common MS file extensions that might remain after baseName
                base = base.replaceAll(/(?i)\.(mzML|mzXML|raw|wiff|d)$/, '')
                tuple(base, path)
            }
            .set { DIA_MZML }
    }

    fasta_ch         = Channel.value(file(params.fasta))
    irt_traml_ch     = params.irt_traml ? Channel.value(file(params.irt_traml)) : Channel.value([])
    irt_nonlinear_traml_ch = params.irt_nonlinear_traml ? Channel.value(file(params.irt_nonlinear_traml)) : Channel.value([])
    swath_windows_ch = params.swath_windows ? Channel.value(file(params.swath_windows)) : Channel.value([])

    // 2-4) Run SAGE (DDA +/- DIA), convert to EasyPQP pickles and build transition TSV/PQP
    sage_lib = SAGE_EASYPQP_LIBRARY(DDA_FOR_SEARCH, DIA_FOR_SEARCH, fasta_ch)

    // sage_lib.library_tsv is the transition TSV produced by EasyPQP_LIBRARY

    // Use subworkflow to create decoyed PQP and run extraction (pass per-run run_peaks for run-specific iRTs)
    assay_out = ASSAY_DECOY_FROM_TRANSITION(DIA_MZML, sage_lib.library_tsv, irt_traml_ch, irt_nonlinear_traml_ch, sage_lib.run_peaks, swath_windows_ch)

    per_run_osw = assay_out.per_run_osw
    decoy_library = assay_out.decoyed_library

    // Collect XIC files (.sqMass) for alignment
    xic_files = assay_out.chrom_mzml.collect()

    // Collect debug calibration files for calibration report
    all_debug_files = assay_out.irt_trafo
      .mix(assay_out.irt_chrom, assay_out.debug_mz, assay_out.debug_im)
      .collect()

    // Generate calibration report from debug files
    calibration_report = PYPROPHET_CALIBRATION_REPORT(all_debug_files)

    // 5) Merge, align and score using shared subworkflow
    merge_out = MERGE_ALIGN_SCORE(per_run_osw, assay_out.chrom_mzml, decoy_library)
    merged_features = merge_out.merged_features
    final_tsv = merge_out.results_tsv

    // emit final TSV
    final_tsv.view { "Finished: ${it}" }
}
