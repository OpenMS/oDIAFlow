#!/usr/bin/env nextflow
// Test wrapper for ARYCAL module

nextflow.enable.dsl = 2

include { ARYCAL } from '../local/arycal/main.nf'

workflow {
    // Input channels for XIC files (sqMass)
    def xic_ch = Channel.of(
        file('modules/tests/data/test_chrom_1.sqMass'),
        file('modules/tests/data/test_chrom_2.sqMass')
    ).collect()
    
    // Feature file (OSW)
    def feature_ch = Channel.of( file('modules/tests/data/test_data.osw') )

    // Run Arycal alignment
    ARYCAL(xic_ch, feature_ch)

    // Emit results for inspection
    ARYCAL.out.config.view { "Arycal config: $it" }
}
