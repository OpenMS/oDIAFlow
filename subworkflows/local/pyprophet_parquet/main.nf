/*
  Subworkflow that runs PyProphet scoring and inference on aligned parquet data:
  score -> peptide -> protein -> export.

  Expectation:
    - aligned_oswpqd: path to aligned .oswpqd directory (from ARYCAL)
    - pqp_ch:         channel/path to the spectral library (PQP)

  Emits:
    - final TSV export (path)
*/

include { PYPROPHET_PEAKGROUP_SCORING }      from '../../../modules/local/pyprophet/peakgroup_scoring/main.nf'
include { PYPROPHET_INFER_PEPTIDE }          from '../../../modules/local/pyprophet/peptide_inference/main.nf'
include { PYPROPHET_INFER_PROTEIN }          from '../../../modules/local/pyprophet/protein_inference/main.nf'
include { PYPROPHET_MERGE_PARQUET }         from '../../../modules/local/pyprophet/merge_parquet/main.nf'
include { PYPROPHET_EXPORT_RESULTS_REPORT }  from '../../../modules/local/pyprophet/export_results_report/main.nf'
include { PYPROPHET_EXPORT_TSV }             from '../../../modules/local/pyprophet/export_tsv/main.nf'

workflow PYPROPHET_PARQUET_FULL {

  take:
    aligned_oswpqd  // Aligned .oswpqd directory from ARYCAL
    pqp_ch          // Spectral library

  main:
  // Score at requested level/classifier (controlled via params.pyprophet.*)
  scored = PYPROPHET_PEAKGROUP_SCORING(aligned_oswpqd)

  // Peptide- and protein-level inference (context via params.pyprophet.context)
  pep_inferred  = PYPROPHET_INFER_PEPTIDE(scored.scored)
  prot_inferred = PYPROPHET_INFER_PROTEIN(pep_inferred.peptide_inferred)

  // Export results report and TSV (optional, controlled via params.pyprophet.export.*)
  merged_parquet = PYPROPHET_MERGE_PARQUET(prot_inferred.protein_inferred)
  PYPROPHET_EXPORT_RESULTS_REPORT(merged_parquet)
  final_tsv = PYPROPHET_EXPORT_TSV(prot_inferred.protein_inferred)

  emit:
    scored_oswpqd = scored.scored
    peptide_inferred = pep_inferred.peptide_inferred
    protein_inferred = prot_inferred.protein_inferred
    results_tsv = final_tsv
}
