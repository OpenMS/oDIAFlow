#!/usr/bin/env nextflow
// Test wrapper for SAGE_SEARCH module

nextflow.enable.dsl = 2

include { SAGE_SEARCH } from '../local/sage/main.nf'

workflow {
    // Input channels for DDA mzML files with sample IDs
    def mzml_ch = Channel.of(
        tuple('test_raw_1', file('modules/tests/data/test_raw_1.mzML.gz')),
        tuple('test_raw_2', file('modules/tests/data/test_raw_2.mzML.gz'))
    )
    
    // FASTA file
    def fasta_ch = Channel.of( file('modules/tests/data/uniprotkb_organism_id_1314_AND_reviewed_2025_11_18.fasta') )

    // Run Sage search
    SAGE_SEARCH(mzml_ch, fasta_ch)

    // Emit results for inspection
    SAGE_SEARCH.out.results.view { sample_id, tsv -> "Results TSV for ${sample_id}: ${tsv}" }
    SAGE_SEARCH.out.matched_fragments.view { sample_id, frags -> "Matched fragments for ${sample_id}: ${frags}" }
}
