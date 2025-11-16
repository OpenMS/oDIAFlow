/*
  Subworkflow that merges per-run OSW files and runs the full PyProphet stack:
  merge -> score -> peptide -> protein.

  Expectation:
    - per_run_osw_ch: channel of tuples (sample_id, path(osw))
    - pqp_ch:         channel/path to the spectral library (PQP)

  Emits:
    - final merged/scored/inferred OSW (path)
*/

include { PYPROPHET_MERGE }         from '../../../modules/local/pyprophet/merge_osws/main.nf'
include { PYPROPHET_SCORE }         from '../../../modules/local/pyprophet/peakgroup_scoring/main.nf'
include { PYPROPHET_INFER_PEPTIDE } from '../../../modules/local/pyprophet/peptide_inference/main.nf'
include { PYPROPHET_INFER_PROTEIN } from '../../../modules/local/pyprophet/protein_inference/main.nf'
include { PYPROPHET_EXPORT_RESULTS_REPORT } from '../../../modules/local/pyprophet/export_results_report/main.nf'
include { PYPROPHET_EXPORT_TSV }  from '../../../modules/local/pyprophet/export_tsv/main.nf'

workflow PYPROPHET_FULL {

  take:
    per_run_osw_ch
    pqp_ch

  /*
    Collect the per-run OSWs to a single list for a one-shot merge.
    We only keep the file paths (`it[1]`) from tuples (sample_id, path).
  */
  osw_list = per_run_osw_ch.map{ it[1] }.collect()

  // Merge per-run OSWs using PQP as the template
  merged = PYPROPHET_MERGE(osw_list, pqp_ch)

  // Score at requested level/classifier (controlled via params.pyprophet.*)
  scored = PYPROPHET_SCORE(merged)

  // Peptide- and protein-level inference (context via params.pyprophet.context)
  pep_inferred  = PYPROPHET_INFER_PEPTIDE(scored)
  prot_inferred = PYPROPHET_INFER_PROTEIN(pep_inferred)

  // Export results report and TSV (optional, controlled via params.pyprophet.export.*)
  PYPROPHET_EXPORT_RESULTS_REPORT(prot_inferred)
  final_tsv = PYPROPHET_EXPORT_TSV(prot_inferred)

  emit:
    final_tsv
}
