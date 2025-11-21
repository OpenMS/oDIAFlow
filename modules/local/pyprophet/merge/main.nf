process PYPROPHET_MERGE {
  tag "pyprophet_merge"
  label 'pyprophet'
  label 'process_medium'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }"

  publishDir "${params.outdir}/pyprophet", mode: params.publish_dir_mode, enabled: params.save_intermediates, pattern: "merged.osw"
  publishDir "${params.outdir}/logs/pyprophet", mode: params.publish_dir_mode, enabled: params.save_logs, pattern: "*.log"

  input:
  path osw_files  // Multiple .osw files from OPENSWATH_EXTRACT
  path pqp        // Spectral library

  output:
  path "merged.osw", emit: merged_osw
  path "*.log", emit: log

  script:
  """
  # Merge all OSW files into a single merged.osw
  pyprophet merge osw \\
    --out merged.osw \\
    --template ${pqp} \\
    ${osw_files} \\
    2>&1 | tee pyprophet_merge.log
  """
}
