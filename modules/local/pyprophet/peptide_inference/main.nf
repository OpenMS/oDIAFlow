process PYPROPHET_INFER_PEPTIDE {
  tag "pyprophet_infer_peptide"
  label 'pyprophet'
  label 'process_medium'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }" // Temp use dev image which contains OpenMS develop branch for latests changes to the OpenSwathWorkflow

  input:
  path scored_osw

  output:
  path "merged.osw"

  script:
  """
  pyprophet infer peptide --in ${scored_osw} --context global 2>&1 | tee pyprophet_infer_peptide.log

  pyprophet infer peptide --in ${scored_osw} --context experiment-wide 2>&1 | tee -a pyprophet_infer_peptide.log

  pyprophet infer peptide --in ${scored_osw} --context run-specific 2>&1 | tee -a pyprophet_infer_peptide.log
  """
}
