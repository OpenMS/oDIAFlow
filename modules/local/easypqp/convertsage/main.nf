process EASYPQP_CONVERTSAGE {
  tag "easypqp_convertsage"
  label 'process_low'
  label 'easypqp'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }" // Temp use dev image which contains OpenMS develop branch for latests changes to the OpenSwathWorkflow

  input:
  path sage_results          // .tsv or .parquet
  path sage_matched_fragments // .tsv or .parquet

  output:
  path "*.psmpkl", emit: psmpkl
  path "*.peakpkl", emit: peakpkl

  script:
  """
  easypqp convertsage \\
    --sage_psm ${sage_results} \\
    --sage_fragments ${sage_matched_fragments} 2>&1 | tee easypqp_convertsage.log
  """
}
