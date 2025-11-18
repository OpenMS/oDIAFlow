process EASYPQP_LIBRARY {
  tag "easypqp_library"
  label 'process_low'
  label 'easypqp'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }" // Temp use dev image which contains OpenMS develop branch for latests changes to the OpenSwathWorkflow

  input:
  path psmpkls  // Multiple .psmpkl files
  path peakpkls // Multiple .peakpkl files

  output:
  path "easypqp_library.tsv", emit: library_tsv

  script:
  def args = task.ext.args ?: ''
  """
  easypqp library \\
    --out easypqp_library.tsv \\
    ${args} \\
    ${psmpkls} \\
    ${peakpkls} \\
  2>&1 | tee easypqp_library.log
  """
}
