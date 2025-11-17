#!/usr/bin/env nextflow
// Test wrapper for PYPROPHET_INFER_PROTEIN module

nextflow.enable.dsl = 2

include { PYPROPHET_PEAKGROUP_SCORING } from '../local/pyprophet/peakgroup_scoring/main.nf'
include { PYPROPHET_INFER_PEPTIDE } from '../local/pyprophet/peptide_inference/main.nf'
include { PYPROPHET_INFER_PROTEIN } from '../local/pyprophet/protein_inference/main.nf'

workflow {
    // Input channel with test OSW file
    def osw_ch = Channel.of( file('modules/tests/data/test_data.osw') )

    // Run Peakgroup scoring first
    scored_osw = PYPROPHET_PEAKGROUP_SCORING(osw_ch)

    // Run peptide inference
    PYPROPHET_INFER_PEPTIDE(scored_osw.scored)

    // Run the protein inference process
    PYPROPHET_INFER_PROTEIN(PYPROPHET_INFER_PEPTIDE.out.peptide_inferred)

    // Emit results for inspection
    PYPROPHET_INFER_PROTEIN.out.protein_inferred.view { "Protein inference output: $it" }
}
