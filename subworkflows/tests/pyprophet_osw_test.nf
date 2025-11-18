#!/usr/bin/env nextflow
// Test wrapper for PYPROPHET_OSW_FULL subworkflow

nextflow.enable.dsl = 2

include { PYPROPHET_OSW_FULL } from '../local/pyprophet_osw/main.nf'

workflow {
    // Input channel with aligned OSW file
    // In real workflow, this comes from ARYCAL output
    def aligned_osw_ch = Channel.of( file("${baseDir}/data/test_data.osw") )

    // PQP file for PyProphet
    def pqp_ch = Channel.of( file("${baseDir}/data/test.pqp") )

    // Run the full PyProphet OSW subworkflow
    // This includes: scoring → peptide inference → protein inference → export
    PYPROPHET_OSW_FULL(aligned_osw_ch, pqp_ch)

    // Emit results for inspection
    PYPROPHET_OSW_FULL.out.scored_osw.view { "Scored OSW: $it" }
    PYPROPHET_OSW_FULL.out.peptide_inferred.view { "Peptide inferred: $it" }
    PYPROPHET_OSW_FULL.out.protein_inferred.view { "Protein inferred: $it" }
    PYPROPHET_OSW_FULL.out.results_tsv.view { "Results TSV: $it" }
}
