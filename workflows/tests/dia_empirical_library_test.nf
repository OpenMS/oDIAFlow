#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

/*
========================================================================================
    Test DIA Empirical Library Workflow
========================================================================================
    Tests the end-to-end workflow:
    1. DDA search with Sage
    2. Convert Sage results to spectral library with EasyPQP
    3. Generate assay library with OpenSwathAssayGenerator
    4. Add decoys with OpenSwathDecoyGenerator
    5. Extract features with OpenSwathWorkflow
    6. Merge and align features
    7. Score with PyProphet
    8. Export results
========================================================================================
*/

// Import the workflow
include { OPEN_SWATH_E2E } from '../dia_empirical_library.nf'

// Run the workflow
workflow {
    // Print test information
    log.info """
    ================================================================================
    DIA Empirical Library Workflow Test
    ================================================================================
    
    Testing workflow with:
    - DDA files: ${params.dda_glob}
    - DIA files: ${params.dia_glob}
    - FASTA: ${params.fasta}
    - SWATH windows: ${params.swath_windows}
    - SQLite format (use_parquet = ${params.use_parquet})
    
    ================================================================================
    """.stripIndent()
    
    OPEN_SWATH_E2E()
}
