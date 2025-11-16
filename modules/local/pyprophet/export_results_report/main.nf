process PYPROPHET_EXPORT_RESULTS_REPORT {
  tag "pyprophet_export_results_report"
    label 'pyprophet'
  label 'process_low'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }" // Temp use dev image which contains OpenMS develop branch for latests changes to the OpenSwathWorkflow

  input:
  path scored_osw 

  output:
  path "merged_score_plots.pdf"

  when:
  true

  script:
  """
  pyprophet export score-report --in ${scored_osw} 2>&1 | tee pyprophet_export_results_report.log
  """
}
