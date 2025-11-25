/*
  Subworkflow to merge per-run OSW, perform ARYCAL alignment and PyProphet scoring.

  Inputs:
    - osw_files : channel of per-run OSW files
    - chrom_mzml_files : channel of per-run sqMass/chrom files
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
    osw_files
    chrom_mzml_files
    decoyed_library

  main:
    // Collect XIC files (.sqMass)
    xic_files = chrom_mzml_files.collect()

    // Merge OSW files BEFORE alignment
    if (params.use_parquet) {
      PYPROPHET_EXPORT_PARQUET(osw_files.map { osw -> tuple(osw.baseName, osw) })

      all_oswpq_dirs = PYPROPHET_EXPORT_PARQUET.out.oswpq.map{ it[1] }.collect()
      PYPROPHET_MERGE_OSWPQ(all_oswpq_dirs)
      merged_features = PYPROPHET_MERGE_OSWPQ.out.merged_oswpqd
    } else {
      all_osw_files = osw_files.collect()
      PYPROPHET_MERGE(all_osw_files, decoyed_library)
      merged_features = PYPROPHET_MERGE.out.merged_osw
    }

    // XIC alignment for across-run feature linking
    ARYCAL(xic_files, merged_features)

    // Score aligned features
    PYPROPHET_ALIGNMENT_SCORING(ARYCAL.out.aligned_features)

    // Final PyProphet scoring (parquet or osw flow)
    if (params.use_parquet) {
      pyprophet_final = PYPROPHET_PARQUET_FULL(PYPROPHET_ALIGNMENT_SCORING.out.scored, decoyed_library)
      final_tsv = pyprophet_final.results_tsv
    } else {
      pyprophet_final = PYPROPHET_OSW_FULL(PYPROPHET_ALIGNMENT_SCORING.out.scored, decoyed_library)
      final_tsv = pyprophet_final.results_tsv
    }

  emit:
    merged_features = merged_features
    results_tsv = final_tsv
}
