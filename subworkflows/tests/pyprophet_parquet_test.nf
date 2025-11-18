#!/usr/bin/env nextflow
// Test wrapper for PYPROPHET_PARQUET_FULL subworkflow

nextflow.enable.dsl = 2

include { PYPROPHET_EXPORT_PARQUET }  from '../../modules/local/pyprophet/export_parquet/main.nf'
include { PYPROPHET_PARQUET_FULL }    from '../local/pyprophet_parquet/main.nf'

workflow {
    // Step 1: Generate parquet data from OSW file
    // Use --split_runs to create separate parquet files per run
    def osw_ch = Channel.of( 
        tuple('test_data', file("${baseDir}/data/test_data.osw"))
    )
    
    // Export to parquet format with split_runs
    parquet_data = PYPROPHET_EXPORT_PARQUET(osw_ch)
    
    // Step 2: Run the full PyProphet parquet subworkflow
    // Extract just the parquet directory from the tuple
    def aligned_oswpq_ch = parquet_data.oswpq.map { sample_id, oswpq -> oswpq }
    
    // PQP file for PyProphet
    def pqp_ch = Channel.of( file("${baseDir}/data/test.pqp") )
    
    // Run the full PyProphet Parquet subworkflow
    // This includes: scoring → peptide inference → protein inference → export
    PYPROPHET_PARQUET_FULL(aligned_oswpq_ch, pqp_ch)
    
    // Emit results for inspection
    PYPROPHET_PARQUET_FULL.out.scored_oswpqd.view { "Scored OSWPQ: $it" }
    PYPROPHET_PARQUET_FULL.out.peptide_inferred.view { "Peptide inferred: $it" }
    PYPROPHET_PARQUET_FULL.out.protein_inferred.view { "Protein inferred: $it" }
    PYPROPHET_PARQUET_FULL.out.results_tsv.view { "Results TSV: $it" }
}
