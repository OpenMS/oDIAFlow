process PYPROPHET_MERGE_OSW {
  tag "pyprophet_merge_osw"
  label 'pyprophet'
  label 'process_low'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }" // Temp use dev image which contains OpenMS develop branch for latests changes to the OpenSwathWorkflow

  input:
  path(osw) from per_run_osw
  path pqp

  output:
  path "merged.osw"

  when:
  true

  script:
  def osw_list = Channel.value([]) // placeholder (Nextflow inlines inputs)
  """
  pyprophet merge osw --template=${pqp} --out=merged.osw *.osw 2>&1 | tee pyprophet_merge_osw.log
  """
}
