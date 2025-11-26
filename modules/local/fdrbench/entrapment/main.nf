process FDRBENCH_ENTRAPMENT {
  tag "fdrbench_entrapment"
  label 'process_medium'

  // Use the OpenSWATH container which includes fdrbench
  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }"

  publishDir "${params.outdir}/fdrbench", mode: params.publish_dir_mode, enabled: params.save_intermediates, pattern: "*.fasta"
  publishDir "${params.outdir}/fdrbench", mode: params.publish_dir_mode, enabled: params.save_intermediates, pattern: "*.txt"
  publishDir "${params.outdir}/logs/fdrbench", mode: params.publish_dir_mode, enabled: params.save_logs, pattern: "*.log"

  input:
  path fasta
  path foreign_species_fastas  // Optional: for multi-species entrapment (can be empty list)

  output:
  path "*_entrapment_*.fasta", emit: entrapment_fasta
  path "*_entrapment_*.txt", emit: peptide_map, optional: true
  path "*.log", emit: log

  script:
  def level = params.fdrbench.level ?: 'protein'
  def output_base = fasta.baseName + "_entrapment_${level}"

  // Build command line arguments
  def i2l_flag = params.fdrbench.i2l ? '-I2L' : ''
  def diann_flag = params.fdrbench.diann_compatible ? '-diann' : ''
  def uniprot_flag = params.fdrbench.uniprot_format ? '-uniprot' : ''
  def check_flag = params.fdrbench.check_duplicates ? '-check' : ''
  def decoy_flag = params.fdrbench.add_decoy ? '-decoy' : ''
  def clip_nm_flag = params.fdrbench.clip_n_m ? '-clip_n_m' : ''
  def ns_flag = params.fdrbench.no_shared_peptides ? '-ns' : ''
  def swap_flag = params.fdrbench.swap_order ? '-swap' : ''
  def fix_seed_flag = params.fdrbench.fix_seed ? '-fix_seed' : ''
  
  def enzyme = params.fdrbench.enzyme ?: 2
  def miss_c = params.fdrbench.missed_cleavages ?: 1
  def min_len = params.fdrbench.min_length ?: 7
  def max_len = params.fdrbench.max_length ?: 35
  def fold = params.fdrbench.fold ?: 1
  def method = params.fdrbench.method ?: 0
  def seed = params.fdrbench.seed ? "-seed ${params.fdrbench.seed}" : ''
  def fix_nc = params.fdrbench.fix_nc ? "-fix_nc ${params.fdrbench.fix_nc}" : ''
  def pick = params.fdrbench.pick ? "-pick ${params.fdrbench.pick}" : ''
  def entrapment_label = params.fdrbench.entrapment_label ?: '_p_target'
  def entrapment_pos = params.fdrbench.entrapment_pos ?: 1

  // Multi-species entrapment (foreign species)
  def ms_option = ''
  if (foreign_species_fastas && foreign_species_fastas.size() > 0) {
    def fasta_list = foreign_species_fastas.collect { it.name }.join(',')
    ms_option = "-ms ${fasta_list}"
  }

  """
  # Run FDRBench to generate entrapment database
  # fdrbench is available in the OpenSWATH container or on system PATH
  fdrbench \\
    -db ${fasta} \\
    -o ${output_base}.fasta \\
    -level ${level} \\
    -enzyme ${enzyme} \\
    -miss_c ${miss_c} \\
    -minLength ${min_len} \\
    -maxLength ${max_len} \\
    -fold ${fold} \\
    -method ${method} \\
    -entrapment_label ${entrapment_label} \\
    -entrapment_pos ${entrapment_pos} \\
    ${i2l_flag} \\
    ${diann_flag} \\
    ${uniprot_flag} \\
    ${check_flag} \\
    ${decoy_flag} \\
    ${clip_nm_flag} \\
    ${ns_flag} \\
    ${swap_flag} \\
    ${fix_seed_flag} \\
    ${seed} \\
    ${fix_nc} \\
    ${pick} \\
    ${ms_option} \\
    -export_db \\
    2>&1 | tee fdrbench_entrapment.log

  # The output fasta is automatically named by FDRBench based on input
  # Rename to our expected output name if needed
  if [ -f "${fasta.baseName}_entrapment.fasta" ]; then
    mv "${fasta.baseName}_entrapment.fasta" "${output_base}.fasta"
  elif [ -f "${fasta.baseName}_I2L_entrapment.fasta" ]; then
    mv "${fasta.baseName}_I2L_entrapment.fasta" "${output_base}.fasta"
  fi
  """
}
