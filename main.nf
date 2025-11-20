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
