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
  tuple val(sample_id), path("*.psmpkl", includeInputs: false, hidden: false), emit: psmpkl
  tuple val(sample_id), path("*.peakpkl", includeInputs: false, hidden: false), emit: peakpkl
  path "*.psmpkl", emit: psmpkl_pub
  path "*.peakpkl", emit: peakpkl_pub
  tuple val(sample_id), path("*.log"), emit: log, optional: true

  script:
  def args = task.ext.args ?: ''
  """
  # Copy input files locally to avoid symlink issues
  cp ${sage_results} sage_results_local.tsv
  cp ${sage_matched_fragments} sage_fragments_local.tsv
  
  easypqp convertsage \\
    --sage_psm sage_results_local.tsv \\
    --sage_fragments sage_fragments_local.tsv \\
    ${args} \\
  2>&1 | tee easypqp_convertsage_${sample_id}.log
  """
}
