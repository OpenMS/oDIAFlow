process OPENSWATHASSAYGENERATOR_NAMED {
  tag { "openswathassaygenerator_${run_id}" }
  label 'process_medium'
  label 'openms'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }"

  input:
  tuple val(run_id), path(transition_list)

  output:
  tuple val(run_id), path("${run_id}.irt.nonlinear.${params.osag.out_type}"), emit: run_library
  path "*.irt.nonlinear.pqp", emit: run_library_pub
  path "*.log", emit: log

  script:
  def out_file = "${run_id}.irt.nonlinear.${params.osag.out_type}"
  def args = task.ext.args ?: ''
  """
  OpenSwathAssayGenerator \\
    -in ${transition_list} \\
    -out ${out_file} \\
    -min_transitions ${params.osag.min_transitions} \\
    -max_transitions ${params.osag.max_transitions} \\
    -allowed_fragment_types ${params.osag.allowed_fragment_types} \\
    -allowed_fragment_charges ${params.osag.allowed_fragment_charges} \\
    -debug ${params.osag.debug} \\
    ${args} \\
  2>&1 | tee openswathassaygenerator_${run_id}.log
  """
}
