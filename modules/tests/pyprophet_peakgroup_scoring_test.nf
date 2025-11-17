#!/usr/bin/env nextflow
// Test wrapper for PYPROPHET_PEAKGROUP_SCORING module

nextflow.enable.dsl = 2

include { PYPROPHET_PEAKGROUP_SCORING } from '../local/pyprophet/peakgroup_scoring/main.nf'

workflow {
    // Input channel with test OSW file
    def osw_ch = Channel.of( file('modules/tests/data/test_data.osw') )

    // Run the scoring process
    PYPROPHET_PEAKGROUP_SCORING(osw_ch)

    // Emit results for inspection
    PYPROPHET_PEAKGROUP_SCORING.out.scored.view { "Scored output: $it" }
}
