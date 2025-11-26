process PYPROPHET_ALIGNMENT_SCORING {
  tag "pyprophet_alignment_scoring"
  label 'pyprophet'
  label 'process_high'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }" // Temp use dev image which contains OpenMS develop branch for latests changes to the OpenSwathWorkflow

  publishDir "${params.outdir}/logs/pyprophet", mode: params.publish_dir_mode, enabled: params.save_logs, pattern: "*.log"

  input:
  path input_data  // Can be merged.osw (SQLite) or all_runs.oswpqd (parquet directory)

  output:
  path "${input_data}", emit: scored
  path "*.pdf", emit: report, optional: true
  path "*.log", emit: log

  // Note: PyProphet writes scores back into the same OSW by default.
  script:
  def args = task.ext.args ?: ''
  """
  pyprophet score \
    --in ${input_data} \
    --level ${params.pyprophet.alignment_scoring.level} \
    --classifier ${params.pyprophet.alignment_scoring.classifier} \
    --ss_num_iter ${params.pyprophet.alignment_scoring.ss_num_iter} \
    --ss_initial_fdr ${params.pyprophet.alignment_scoring.ss_initial_fdr} \
    --ss_iteration_fdr ${params.pyprophet.alignment_scoring.ss_iteration_fdr} \
    --ss_main_score ${params.pyprophet.alignment_scoring.ss_main_score} \
    --xeval_num_iter ${params.pyprophet.alignment_scoring.xeval_num_iter} \
    --threads ${task.cpus} \
    ${args} \
    2>&1 | tee pyprophet_alignment_scoring.log
  """
}
