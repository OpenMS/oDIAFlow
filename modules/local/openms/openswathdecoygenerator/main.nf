process OPENSWATHDECOYGENERATOR {
  tag "openswathdecoygenerator"
  label 'process_medium'
  label 'openms'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }" // Temp use dev image which contains OpenMS develop branch for latests changes to the OpenSwathWorkflow

  publishDir "${params.outdir}/library", mode: params.publish_dir_mode, enabled: true, pattern: "library.${params.osdg.out_type}"
  publishDir "${params.outdir}/logs/openms", mode: params.publish_dir_mode, enabled: params.save_logs, pattern: "*.log"

  input:
  path target_pqp

  output:
  path "library.${params.osdg.out_type}", emit: library 
  path "*.log", emit: log 

  script:
  def out_file = "library.${params.osdg.out_type}"
  def switchKR = params.osdg.switch_kr ? "-switchKR true" : ""
  def args = task.ext.args ?: ''
  """
  OpenSwathDecoyGenerator \\
    -in ${target_pqp} \\
    -out ${out_file} \\
    -method ${params.osdg.method} \\
    -decoy_tag ${params.osdg.decoy_tag} \\
    -allowed_fragment_types ${params.osdg.allowed_fragment_types} \\
    -allowed_fragment_charges ${params.osdg.allowed_fragment_charges} \\
    ${switchKR} \\
    -debug ${params.osdg.debug} \\
    ${args} \\
  2>&1 | tee openswathdecoygenerator.log
  """
}
