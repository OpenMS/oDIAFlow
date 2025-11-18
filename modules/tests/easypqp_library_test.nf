#!/usr/bin/env nextflow
// Test wrapper for EASYPQP modules (CONVERTSAGE and LIBRARY)
// Tests the full workflow: Sage search → EasyPQP convert → EasyPQP library

nextflow.enable.dsl = 2

include { SAGE_SEARCH } from '../local/sage/main.nf'
include { EASYPQP_CONVERTSAGE } from '../local/easypqp/convertsage/main.nf'
include { EASYPQP_LIBRARY } from '../local/easypqp/library/main.nf'

workflow {
    // Input channels for DDA mzML files with sample IDs
    def mzml_ch = Channel.of(
        tuple('test_raw_1', file('modules/tests/data/test_raw_1.mzML')),
        tuple('test_raw_2', file('modules/tests/data/test_raw_2.mzML'))
    )
    
    // FASTA file
    def fasta_ch = Channel.of( file('modules/tests/data/uniprotkb_organism_id_1314_AND_reviewed_2025_11_18.fasta') )

    // Step 1: Run Sage search
    SAGE_SEARCH(mzml_ch, fasta_ch)

    // Step 2: Join Sage results with matched fragments by sample_id
    def sage_combined = SAGE_SEARCH.out.results
        .join(SAGE_SEARCH.out.matched_fragments, by: 0)

    // Step 3: Convert Sage results to EasyPQP pickle format
    EASYPQP_CONVERTSAGE(sage_combined)

    // Step 4: Collect all pickle files and run library generation
    def psmpkls = EASYPQP_CONVERTSAGE.out.psmpkl.map { sample_id, pkl -> pkl }.collect()
    def peakpkls = EASYPQP_CONVERTSAGE.out.peakpkl.map { sample_id, pkl -> pkl }.collect()
    
    EASYPQP_LIBRARY(psmpkls, peakpkls)

    // Emit results for inspection
    SAGE_SEARCH.out.results.view { sample_id, tsv -> "Sage results for ${sample_id}: ${tsv}" }
    EASYPQP_CONVERTSAGE.out.psmpkl.view { sample_id, pkl -> "PSM pickle for ${sample_id}: ${pkl}" }
    EASYPQP_CONVERTSAGE.out.peakpkl.view { sample_id, pkl -> "Peak pickle for ${sample_id}: ${pkl}" }
    EASYPQP_LIBRARY.out.library_tsv.view { "EasyPQP library: $it" }
}
