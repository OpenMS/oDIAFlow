process PYPROPHET_EXPORT_PARQUET {
  tag "pyprophet_export_parquet_${sqlite_osw.baseName}"
  label 'pyprophet'
  label 'process_low'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }" // Temp use dev image which contains OpenMS develop branch for latests changes to the OpenSwathWorkflow

  input:
  path sqlite_osw 

  output:
  path "${sqlite_osw.baseName}.oswpq"

  when:
  true

  script:
  """
  pyprophet export parquet --in ${sqlite_osw} -- out ${sqlite_osw.baseName}.oswpq --split_transition_data 2>&1 | tee ${sqlite_osw.baseName}_pyprophet_export_parquet.log
  """
}
