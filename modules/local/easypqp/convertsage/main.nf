process EASYPQP_CONVERTSAGE {
  tag "easypqp_convertsage_${sample_id}"
  label 'process_low'
  label 'easypqp'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }"

  input:
  tuple val(sample_id), path(sage_results), path(sage_matched_fragments)  // .tsv or .parquet

  output:
  tuple val(sample_id), path("*.psmpkl"), emit: psmpkl
  tuple val(sample_id), path("*.peakpkl"), emit: peakpkl

  script:
  """
  easypqp convertsage \\
    --sage_psm ${sage_results} \\
    --sage_fragments ${sage_matched_fragments} \\
  2>&1 | tee easypqp_convertsage_${sample_id}.log
  """
}
