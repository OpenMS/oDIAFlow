process PYPROPHET_MERGE_PARQUET {
  tag "pyprophet_merge_parquet"
  label 'pyprophet'
  label 'process_low'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }" // Temp use dev image which contains OpenMS develop branch for latests changes to the OpenSwathWorkflow

  publishDir "${params.outdir}/pyprophet", mode: params.publish_dir_mode, enabled: params.save_merged_osw, pattern: "merged.parquet"
  publishDir "${params.outdir}/logs/pyprophet", mode: params.publish_dir_mode, enabled: params.save_logs, pattern: "*.log"

  input:
  path oswpq // Single .oswpq directory containing multiple run subdirectories

  output:
  path "merged.parquet", emit: merged // Single merged parquet file
  path "*.log", emit: log

  when:
  true

  script:
  def args = task.ext.args ?: ''
  // The oswpq directory contains subdirectories for each run (e.g., run1.oswpq, run2.oswpq)
  // pyprophet merge will find and merge all the parquet files from these subdirectories
  """
  pyprophet merge parquet \\
    --out=merged.parquet \\
    ${args} \\
    ${oswpq} \\
    2>&1 | tee pyprophet_merge_parquet.log
  """
}
