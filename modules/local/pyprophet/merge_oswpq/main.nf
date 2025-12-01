process PYPROPHET_MERGE_OSWPQ {
  tag "pyprophet_merge_oswpq"
  label 'pyprophet'
  label 'process_low'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }"

  input:
  path oswpq_dirs  // Multiple .oswpq directories from PYPROPHET_EXPORT_PARQUET

  output:
  path "all_runs.oswpqd", emit: merged_oswpqd
  path "*.log", emit: log

  script:
  """
  # Create the merged .oswpqd directory structure
  mkdir -p all_runs.oswpqd
  
  # Copy all .oswpq directories into the merged structure
  for dir in ${oswpq_dirs}; do
    if [ -d "\$dir" ]; then
      cp -r "\$dir" all_runs.oswpqd/
    fi
  done
  
  echo "Merged \$(ls all_runs.oswpqd | wc -l) .oswpq directories into all_runs.oswpqd" | tee pyprophet_merge_oswpq.log
  """
}
