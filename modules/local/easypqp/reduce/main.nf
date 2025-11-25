process EASYPQP_REDUCE {
  tag { "easypqp_reduce_${run_id}" }
  label 'process_low'
  label 'easypqp'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }"

  publishDir "${params.outdir}/library/run_specific", mode: params.publish_dir_mode, enabled: params.save_intermediates, pattern: "*.pqp"
  publishDir "${params.outdir}/logs/easypqp", mode: params.publish_dir_mode, enabled: params.save_logs, pattern: "*.log"

  input:
  tuple val(run_id), path(pqp)

  output:
  tuple val(run_id), path("${run_id}.irt.linear.pqp"), emit: reduced_pqp

  script:
  def out_file = "${run_id}.irt.linear.pqp"
  def bins = params.easypqp?.reduce?.bins ?: 10
  def peptides = params.easypqp?.reduce?.peptides ?: 20
  """
  easypqp reduce \\
    --in=${pqp} \\
    --out=${out_file} \\
    --bins=${bins} \\
    --peptides=${peptides} \\
  2>&1 | tee easypqp_reduce_${run_id}.log
  """
}
