nextflow.enable.dsl=2

include { OPEN_SWATH_E2E } from './workflows/dia_empirical_library.nf'
include { OPEN_SWATH_INSILICO_LIBRARY } from './workflows/dia_insilico_library.nf'

workflow {
  // Choose workflow based on params
  if (params.workflow == 'insilico' || params.workflow == 'in-silico') {
    OPEN_SWATH_INSILICO_LIBRARY()
  } else {
    // Default to empirical (DDA+DIA) workflow
    OPEN_SWATH_E2E()
  }
}

// Workflow completion handler
workflow.onComplete {
    log.info """
    ====================================================
    Pipeline completed at: ${workflow.complete}
    Duration           : ${workflow.duration}
    Success            : ${workflow.success}
    Work directory     : ${workflow.workDir}
    Results directory  : ${params.outdir}
    ====================================================
    """.stripIndent()
    
    // Clean up work directory if requested and workflow succeeded
    if (params.cleanup_work_dir && workflow.success) {
        log.info "Cleaning up work directory: ${workflow.workDir}"
        try {
            def workDirPath = workflow.workDir.toFile()
            if (workDirPath.exists() && workDirPath.isDirectory()) {
                workDirPath.deleteDir()
                log.info "Successfully deleted work directory"
            }
        } catch (Exception e) {
            log.warn "Could not delete work directory: ${e.message}"
            log.warn "You can manually delete it with: rm -rf ${workflow.workDir}"
        }
    } else if (params.cleanup_work_dir && !workflow.success) {
        log.warn "Work directory cleanup skipped because workflow failed"
        log.warn "Keeping work directory for debugging: ${workflow.workDir}"
    }
}

workflow.onError {
    log.error """
    ====================================================
    Pipeline failed!
    Error message: ${workflow.errorMessage}
    Error report : ${workflow.errorReport}
    Work directory kept for debugging: ${workflow.workDir}
    ====================================================
    """.stripIndent()
}
