/*
  Subworkflow that merges per-run OSW files and runs the full PyProphet stack:
  export parquet -> merge -> score -> peptide -> protein.

  Expectation:
    - per_run_osw_ch: channel of tuples (sample_id, path(osw))
    - pqp_ch:         channel/path to the spectral library (PQP)

  Emits:
    - final merged/scored/inferred OSW (path)
*/

include { PYPROPHET_EXPORT_PARQUET }         from '../../../modules/local/pyprophet/export_parquet/main.nf'
include { PYPROPHET_MERGE_OSWPQ }            from '../../../modules/local/pyprophet/merge_oswpq/main.nf'
include { PYPROPHET_SCORE }                  from '../../../modules/local/pyprophet/peakgroup_scoring/main.nf'
include { PYPROPHET_INFER_PEPTIDE }          from '../../../modules/local/pyprophet/peptide_inference/main.nf'
include { PYPROPHET_INFER_PROTEIN }          from '../../../modules/local/pyprophet/protein_inference/main.nf'
include { PYPROPHET_EXPORT_RESULTS_REPORT }  from '../../../modules/local/pyprophet/export_results_report/main.nf'
include { PYPROPHET_EXPORT_TSV }             from '../../../modules/local/pyprophet/export_tsv/main.nf'

workflow PYPROPHET_FULL {

  take:
    per_run_osw_ch
    pqp_ch

  main:
  /*
    Convert each OSW to parquet directory (.oswpq).
    per_run_osw_ch is a channel of tuples (sample_id, path(osw))
  */
  PYPROPHET_EXPORT_PARQUET(per_run_osw_ch)
  
  /*
    Collect all .oswpq directories into a single list and merge them
    into a unified .oswpqd directory structure.
  */
  all_oswpq_dirs = PYPROPHET_EXPORT_PARQUET.out.oswpq.map{ it[1] }.collect()
  merged_oswpqd = PYPROPHET_MERGE_OSWPQ(all_oswpq_dirs)

  // Score at requested level/classifier (controlled via params.pyprophet.*)
  scored = PYPROPHET_SCORE(merged_oswpqd)

  // Peptide- and protein-level inference (context via params.pyprophet.context)
  pep_inferred  = PYPROPHET_INFER_PEPTIDE(scored)
  prot_inferred = PYPROPHET_INFER_PROTEIN(pep_inferred)

  // Export results report and TSV (optional, controlled via params.pyprophet.export.*)
  PYPROPHET_EXPORT_RESULTS_REPORT(prot_inferred)
  final_tsv = PYPROPHET_EXPORT_TSV(prot_inferred)

  emit:
    final_tsv
}
