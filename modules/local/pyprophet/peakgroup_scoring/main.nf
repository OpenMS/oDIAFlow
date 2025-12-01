process PYPROPHET_PEAKGROUP_SCORING {
  tag "pyprophet_peakgroup_scoring"
  label 'pyprophet'
  label 'process_high'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }"

  input:
  path input_data  // Can be merged.osw (SQLite) or all_runs.oswpqd (parquet directory)

  output:
  path "${input_data}", emit: scored
  path "*.pdf", emit: report, optional: true
  path "*.log", emit: log

  // Note: PyProphet writes scores back into the same file/directory
  script:
  def args = task.ext.args ?: ''
  """
  pyprophet score \\
    --in ${input_data} \\
    --level ${params.pyprophet.peakgroup_scoring.level} \\
    --classifier ${params.pyprophet.peakgroup_scoring.classifier} \\
    --ss_num_iter ${params.pyprophet.peakgroup_scoring.ss_num_iter} \\
    --ss_initial_fdr ${params.pyprophet.peakgroup_scoring.ss_initial_fdr} \\
    --ss_iteration_fdr ${params.pyprophet.peakgroup_scoring.ss_iteration_fdr} \\
    --ss_main_score ${params.pyprophet.peakgroup_scoring.ss_main_score} \\
    --xeval_num_iter ${params.pyprophet.peakgroup_scoring.xeval_num_iter} \\
    --threads ${task.cpus} \\
    ${args} \\
    2>&1 | tee pyprophet_peakgroup_scoring.log
  """
}
