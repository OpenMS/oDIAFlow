#!/usr/bin/env nextflow
// Test wrapper for FDRBENCH_ENTRAPMENT module

nextflow.enable.dsl = 2

include { FDRBENCH_ENTRAPMENT } from '../local/fdrbench/entrapment/main.nf'

workflow {
    // FASTA file for entrapment database generation
    def fasta_ch = Channel.of(
        file('modules/tests/data/uniprotkb_organism_id_1314_AND_reviewed_2025_11_18.fasta')
    )
    
    // Empty channel for foreign species (using shuffled sequences instead)
    def foreign_species_ch = Channel.value([])

    // Run FDRBench entrapment
    FDRBENCH_ENTRAPMENT(fasta_ch, foreign_species_ch)

    // Emit results for inspection
    FDRBENCH_ENTRAPMENT.out.entrapment_fasta.view { fasta -> 
        "Entrapment FASTA: ${fasta}" 
    }
    FDRBENCH_ENTRAPMENT.out.peptide_map.view { map -> 
        "Peptide map: ${map}" 
    }
    FDRBENCH_ENTRAPMENT.out.log.view { log -> 
        "Log file: ${log}" 
    }
}
