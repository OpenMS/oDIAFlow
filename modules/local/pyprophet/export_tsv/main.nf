process PYPROPHET_EXPORT_TSV {
  tag "pyprophet_export_tsv"
  label 'pyprophet'
  label 'process_low'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }" // Temp use dev image which contains OpenMS develop branch for latests changes to the OpenswathWorkflow

  publishDir "${params.outdir}/results", mode: params.publish_dir_mode, enabled: true, pattern: "merged.tsv"
  publishDir "${params.outdir}/logs/pyprophet", mode: params.publish_dir_mode, enabled: params.save_logs, pattern: "*.log"

  input:
  path scored_osw

  output:
  path "merged.tsv", emit: tsv
  path "*.log", emit: log

  script:
  def args = task.ext.args ?: ''
  // Copy OSW file locally to avoid SQLite locking issues on network filesystems
  """
  # Copy OSW to local working directory to avoid SQLite database locking issues
  cp ${scored_osw} local_scored.osw
  
  pyprophet export tsv --in local_scored.osw --out merged.tsv \
    --max_rs_peakgroup_qvalue ${params.pyprophet_export_tsv.max_rs_peakgroup_qvalue} \
    --max_global_peptide_qvalue ${params.pyprophet_export_tsv.max_global_peptide_qvalue} \
    --max_global_protein_qvalue ${params.pyprophet_export_tsv.max_global_protein_qvalue} \
    ${args} \
    2>&1 | tee pyprophet_export_tsv.log
  
  # Clean up local copy
  rm -f local_scored.osw
  """
}
