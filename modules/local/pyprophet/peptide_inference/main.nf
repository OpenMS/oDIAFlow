process PYPROPHET_INFER_PEPTIDE {
  tag "pyprophet_infer_peptide"
  label 'pyprophet'
  label 'process_medium'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }" // Temp use dev image which contains OpenMS develop branch for latests changes to the OpenSwathWorkflow

  publishDir "${params.outdir}/reports", mode: params.publish_dir_mode, enabled: params.save_reports, pattern: "*.pdf"
  publishDir "${params.outdir}/logs/pyprophet", mode: params.publish_dir_mode, enabled: params.save_logs, pattern: "*.log"

  input:
  path scored_osw

  output:
  path "${scored_osw}", emit: peptide_inferred
  path "*_global_peptide_report.pdf", emit: global_report, optional: true
  path "*_experiment-wide_peptide_report.pdf", emit: experiment_wide_report, optional: true
  path "*_run-specific_peptide_report.pdf", emit: run_specific_report, optional: true
  path "*.log", emit: log

  script:
  def args = task.ext.args ?: ''
  """
  pyprophet infer peptide --in ${scored_osw} --context global ${args} 2>&1 | tee pyprophet_infer_peptide.log

  pyprophet infer peptide --in ${scored_osw} --context experiment-wide ${args} 2>&1 | tee -a pyprophet_infer_peptide.log

  pyprophet infer peptide --in ${scored_osw} --context run-specific ${args} 2>&1 | tee -a pyprophet_infer_peptide.log
  """
}
