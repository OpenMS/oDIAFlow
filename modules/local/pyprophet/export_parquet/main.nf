process PYPROPHET_EXPORT_PARQUET {
  tag "pyprophet_export_parquet_${sample_id}"
  label 'pyprophet'
  label 'process_low'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }"

  input:
  tuple val(sample_id), path(sqlite_osw)

  output:
  tuple val(sample_id), path("${sqlite_osw.baseName}.oswpq"), emit: oswpq

  script:
  """
  pyprophet export parquet \\
    --in ${sqlite_osw} \\
    --out ${sqlite_osw.baseName}.oswpq \\
    --split_transition_data \\
    2>&1 | tee ${sqlite_osw.baseName}_pyprophet_export_parquet.log
  """
}
