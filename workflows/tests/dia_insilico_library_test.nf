#!/usr/bin/env nextflow
// Test wrapper for DIA_INSILICO_LIBRARY workflow
// Tests the full in-silico library workflow: Assay generation → Feature extraction → Alignment → PyProphet

nextflow.enable.dsl = 2

include { OPEN_SWATH_INSILICO_LIBRARY } from '../dia_insilico_library.nf'

workflow {
    // This is a simple test wrapper that sets up minimal params
    // and calls the main workflow
    
    log.info """
    ================================================================================
    DIA In-Silico Library Workflow Test
    ================================================================================
    
    Testing workflow with:
    - DIA files: test_raw_1.mzML.gz, test_raw_2.mzML.gz
    - Transition TSV: test.tsv (in-silico library)
    - SWATH windows: strep_win.txt
    - SQLite format (use_parquet = false)
    
    ================================================================================
    """.stripIndent()
    
    OPEN_SWATH_INSILICO_LIBRARY()
}
