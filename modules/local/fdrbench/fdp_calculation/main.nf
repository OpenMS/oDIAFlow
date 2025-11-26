process FDRBENCH_FDP_CALCULATION {
  tag "fdrbench_fdp_${level}"
  label 'process_medium'

  // Use the OpenSWATH container which includes fdrbench
  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }"

  publishDir "${params.outdir}/fdrbench/fdp", mode: params.publish_dir_mode, enabled: true, pattern: "*.csv"
  publishDir "${params.outdir}/logs/fdrbench", mode: params.publish_dir_mode, enabled: params.save_logs, pattern: "*.log"

  input:
  path psm_file           // PSM/peptide/precursor/protein file (targets only, no decoys)
  path peptide_map        // Peptide pair file from FDRBENCH_ENTRAPMENT (for peptide/precursor level)
  val level               // 'PSM', 'peptide', 'precursor', or 'protein'

  output:
  path "*_fdp_${level}.csv", emit: fdp_results
  path "*.log", emit: log

  script:
  def score_col = params.fdrbench.fdp_score_column ?: 'score'
  def score_order = params.fdrbench.fdp_score_order ?: 0  // 0 = lower is better, 1 = higher is better
  def fold = params.fdrbench.fold ?: 1
  def pick = params.fdrbench.pick ? "-pick ${params.fdrbench.pick}" : ''
  def decoy_label = params.fdrbench.decoy_label ?: 'rev_'
  def decoy_pos = params.fdrbench.decoy_pos ?: 0
  def entrapment_label = params.fdrbench.entrapment_label ?: '_p_target'
  def entrapment_pos = params.fdrbench.entrapment_pos ?: 1

  def pep_option = level in ['peptide', 'precursor', 'PSM'] ? "-pep ${peptide_map}" : ''

  """
  # Run FDRBench FDP calculation
  # fdrbench is available in the OpenSWATH container or on system PATH
  fdrbench \\
    -i ${psm_file} \\
    -level ${level} \\
    -o ${psm_file.baseName}_fdp_${level}.csv \\
    -score '${score_col}:${score_order}' \\
    -fold ${fold} \\
    -decoy_label ${decoy_label} \\
    -decoy_pos ${decoy_pos} \\
    -entrapment_label ${entrapment_label} \\
    -entrapment_pos ${entrapment_pos} \\
    ${pep_option} \\
    ${pick} \\
    2>&1 | tee fdrbench_fdp_${level}.log
  """
}
