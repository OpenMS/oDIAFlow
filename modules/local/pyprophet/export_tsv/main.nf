process PYPROPHET_EXPORT_TSV {
  tag "pyprophet_export_tsv"
  label 'pyprophet'
  label 'process_low'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }" // Temp use dev image which contains OpenMS develop branch for latests changes to the OpenSwathWorkflow

  input:
  path scored_osw

  output:
  path "merged.tsv"

  script:
  def args = task.ext.args ?: ''
  """
  pyprophet export tsv --in ${scored_osw} --out merged.tsv \
    --max_rs_peakgroup_qvalue ${params.pyprophet_export_tsv.max_rs_peakgroup_qvalue} \
    --max_global_peptide_qvalue ${params.pyprophet_export_tsv.max_global_peptide_qvalue} \
    --max_global_protein_qvalue ${params.pyprophet_export_tsv.max_global_protein_qvalue} \
    ${args} \
    2>&1 | tee pyprophet_export_tsv.log
  """
}
