process OPENSWATHASSAYGENERATOR {
  tag "openswathassaygenerator"
  label 'process_medium'
  label 'openms'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }" // Temp use dev image which contains OpenMS develop branch for latests changes to the OpenSwathWorkflow

  input:
  path transition_list

  output:
  path "library_targets.${params.osag.out_type}", emit: library

  script:
  def out_file = "library_targets.${params.osag.out_type}"
  """
  OpenSwathAssayGenerator \\
    -in ${transition_list} \\
    -out ${out_file} \\
    -min_transitions ${params.osag.min_transitions} \\
    -max_transitions ${params.osag.max_transitions} \\
    -allowed_fragment_types ${params.osag.allowed_fragment_types} \\
    -allowed_fragment_charges ${params.osag.allowed_fragment_charges} \\
    -debug ${params.osag.debug} \\
    $args \\
  2>&1 | tee openswathassaygenerator.log
  """
}
