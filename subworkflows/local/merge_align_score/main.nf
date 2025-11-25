/*
  Subworkflow to merge per-run OSW, perform ARYCAL alignment and PyProphet scoring.

  Inputs:
    - per_run_osw : channel returned by OPENSWATHWORKFLOW (composite with .osw, .chrom_mzml, .irt_trafo, .irt_chrom, .debug_mz, .debug_im)
    - decoyed_library : PQP/library file produced by decoy generator

  Emits:
    - merged_features : merged OSW (or merged oswpqd)
    - results_tsv : final pyprophet results TSV
*/

include { PYPROPHET_EXPORT_PARQUET }    from '../../../modules/local/pyprophet/export_parquet/main.nf'
include { PYPROPHET_MERGE_OSWPQ }       from '../../../modules/local/pyprophet/merge_oswpq/main.nf'
include { PYPROPHET_MERGE }             from '../../../modules/local/pyprophet/merge/main.nf'
include { ARYCAL }                      from '../../../modules/local/arycal/main.nf'
include { PYPROPHET_ALIGNMENT_SCORING } from '../../../modules/local/pyprophet/alignment_scoring/main.nf'
include { PYPROPHET_OSW_FULL }          from '../../../subworkflows/local/pyprophet_osw/main.nf'
include { PYPROPHET_PARQUET_FULL }      from '../../../subworkflows/local/pyprophet_parquet/main.nf'

workflow MERGE_ALIGN_SCORE {

  take:
    per_run_osw
    decoyed_library

  main:
    // Collect XIC files (.sqMass)
    xic_files = per_run_osw.chrom_mzml.collect()

    // Collect debug calibration files for calibration report (if needed elsewhere)
    all_debug_files = per_run_osw.irt_trafo
      .mix(per_run_osw.irt_chrom, per_run_osw.debug_mz, per_run_osw.debug_im)
      .collect()

    // Merge OSW files BEFORE alignment
    if (params.use_parquet) {
      PYPROPHET_EXPORT_PARQUET(per_run_osw.osw.map { osw -> tuple(osw.baseName, osw) })

      all_oswpq_dirs = PYPROPHET_EXPORT_PARQUET.out.oswpq.map{ it[1] }.collect()
      merged = PYPROPHET_MERGE_OSWPQ(all_oswpq_dirs)
      merged_features = merged.out.merged_oswpqd
    } else {
      all_osw_files = per_run_osw.osw.collect()
      merged = PYPROPHET_MERGE(all_osw_files, decoyed_library)
      merged_features = merged.out.merged_osw
    }

    // XIC alignment for across-run feature linking
    arycal_output = ARYCAL(xic_files, merged_features)

    // Score aligned features
    scored_alignment = PYPROPHET_ALIGNMENT_SCORING(arycal_output.aligned_features)

    // Final PyProphet scoring (parquet or osw flow)
    if (params.use_parquet) {
      pyprophet_final = PYPROPHET_PARQUET_FULL(scored_alignment.scored, decoyed_library)
      final_tsv = pyprophet_final.results_tsv
    } else {
      pyprophet_final = PYPROPHET_OSW_FULL(scored_alignment.scored, decoyed_library)
      final_tsv = pyprophet_final.results_tsv
    }

  emit:
    merged_features = merged_features
    results_tsv = final_tsv
}
