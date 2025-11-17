process PYPROPHET_INFER_PROTEIN {
  tag "pyprophet_infer_protein"
  label 'pyprophet'
  label 'process_medium'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }" // Temp use dev image which contains OpenMS develop branch for latests changes to the OpenSwathWorkflow

  input:
  path scored_osw

  output:
  path "${scored_osw}", emit: protein_inferred
  path "*_global_protein_report.pdf", emit: global_report, optional: true
  path "*_experiment-wide_protein_report.pdf", emit: experiment_wide_report, optional: true
  path "*_run-specific_protein_report.pdf", emit: run_specific_report, optional: true

  script:
  def args = task.ext.args ?: ''
  """
  pyprophet infer protein --in ${scored_osw} --context global ${args} 2>&1 | tee pyprophet_infer_protein.log

  pyprophet infer protein --in ${scored_osw} --context experiment-wide ${args} 2>&1 | tee -a pyprophet_infer_protein.log

  pyprophet infer protein --in ${scored_osw} --context run-specific ${args} 2>&1 | tee -a pyprophet_infer_protein.log
  """
}
