process PYPROPHET_TRANSITION_SCORING {
  tag "pyprophet_transition_scoring"
  label 'pyprophet'
  label 'process_high'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }" // Temp use dev image which contains OpenMS develop branch for latests changes to the OpenSwathWorkflow

  input:
  path input_data  // Can be merged.osw (SQLite) or all_runs.oswpqd (parquet directory)

  output:
  path "${input_data}", emit: scored

  // Note: PyProphet writes scores back into the same OSW by default.
  script:
  """
  pyprophet score \
    --in ${input_data} \
    --level ${params.pyprophet.transition_scoring.level} \
    --classifier ${params.pyprophet.transition_scoring.classifier} \
    --ss_num_iter ${params.pyprophet.transition_scoring.ss_num_iter} \
    --ss_initial_fdr ${params.pyprophet.transition_scoring.ss_initial_fdr} \
    --ss_iteration_fdr ${params.pyprophet.transition_scoring.ss_iteration_fdr} \
    --ss_main_score ${params.pyprophet.transition_scoring.ss_main_score} \
    --xeval_num_iter ${params.pyprophet.transition_scoring.xeval_num_iter} \
    --ipf_max_peakgroup_rank ${params.pyprophet.transition_scoring.ipf_max_peakgroup_rank} \
    --ipf_max_peakgroup_pep ${params.pyprophet.transition_scoring.ipf_max_peakgroup_pep} \
    --ipf_max_transition_isotope_overlap ${params.pyprophet.transition_scoring.ipf_max_transition_isotope_overlap} \
    --ipf_min_transition_sn ${params.pyprophet.transition_scoring.ipf_min_transition_sn} \
    --threads ${task.cpus} 2>&1 | tee pyprophet_transition_scoring.log
  """
}
