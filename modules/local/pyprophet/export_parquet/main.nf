process PYPROPHET_EXPORT_PARQUET {
  tag "pyprophet_export_parquet_${sample_id}"
  label 'pyprophet'
  label 'process_low'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }"

  publishDir "${params.outdir}/pyprophet", mode: params.publish_dir_mode, enabled: params.save_intermediates, pattern: "*.oswpq"
  publishDir "${params.outdir}/logs/pyprophet", mode: params.publish_dir_mode, enabled: params.save_logs, pattern: "*.log"

  input:
  tuple val(sample_id), path(sqlite_osw)

  output:
  tuple val(sample_id), path("${sqlite_osw.baseName}.oswpq"), emit: oswpq
  path "*.log", emit: log

  script:
  def args = task.ext.args ?: ''
  """
  pyprophet export parquet \\
    --in ${sqlite_osw} \\
    --out ${sqlite_osw.baseName}.oswpq \\
    --split_transition_data \\
    ${args} \\
    2>&1 | tee ${sqlite_osw.baseName}_pyprophet_export_parquet.log
  """
}
