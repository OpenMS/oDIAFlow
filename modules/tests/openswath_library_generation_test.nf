#!/usr/bin/env nextflow
// Test wrapper for OPENSWATHASSAYGENERATOR and OPENSWATHDECOYGENERATOR modules

nextflow.enable.dsl = 2

include { OPENSWATHASSAYGENERATOR } from '../local/openms/openswathassaygenerator/main.nf'
include { OPENSWATHDECOYGENERATOR } from '../local/openms/openswathdecoygenerator/main.nf'

workflow {
    // Input channel with test TraML file
    def traml_ch = Channel.of( file('modules/tests/data/strep_iRT_small.TraML') )

    // Run OpenSwathAssayGenerator to create target library
    OPENSWATHASSAYGENERATOR(traml_ch)

    // Run OpenSwathDecoyGenerator to add decoys
    OPENSWATHDECOYGENERATOR(OPENSWATHASSAYGENERATOR.out.library_targets)

    // Emit results for inspection
    OPENSWATHASSAYGENERATOR.out.library_targets.view { "Target library: $it" }
    OPENSWATHDECOYGENERATOR.out.library.view { "Target + Decoy library: $it" }
}
