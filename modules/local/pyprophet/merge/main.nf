process PYPROPHET_MERGE {
  tag "pyprophet_merge"
  label 'pyprophet'
  label 'process_medium'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }"

  input:
  path osw_files  // Multiple .osw files from OPENSWATH_EXTRACT
  path pqp        // Spectral library

  output:
  path "merged.osw", emit: merged_osw

  script:
  """
  # Merge all OSW files into a single merged.osw
  pyprophet merge \\
    --out merged.osw \\
    --template ${pqp} \\
    ${osw_files} \\
    2>&1 | tee pyprophet_merge.log
  """
}
