process ARYCAL {
  tag "arycal_xic_alignment"
  label 'process_high'
  label 'arycal'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }"

  publishDir "${params.outdir}/pyprophet", mode: params.publish_dir_mode, enabled: params.save_intermediates, pattern: "*.osw"
  publishDir "${params.outdir}/pyprophet", mode: params.publish_dir_mode, enabled: params.save_intermediates, pattern: "*.oswpqd"
  publishDir "${params.outdir}/logs/arycal", mode: params.publish_dir_mode, enabled: params.save_logs, pattern: "*.log"

  input:
  path xic_files        // sqMass or parquet files containing XIC data
  path feature_files    // merged osw or pyprophet split parquet oswpqd directory

  output:
  // For osw-sqlite input, we modify the input inplace, so emit the input file which now contains alignment
  // For oswpqd input, we write out a parquet file (feature_alignment.parquet) that is in the input oswpqd directory
  path "${feature_files}", emit: aligned_features
  path "arycal_config.json", emit: config
  path "*.log", emit: log, optional: true

  script:
  // Auto-detect file types from extensions if not specified
  def xic_first = xic_files instanceof List ? xic_files[0] : xic_files
  def feature_first = feature_files instanceof List ? feature_files[0] : feature_files
  
  def xic_type = params.arycal.xic_file_type ?: (xic_first.toString().endsWith('.sqMass') ? 'sqmass' : 
                                                   xic_first.toString().endsWith('.parquet') ? 'parquet' : 'null')
  def features_type = params.arycal.features_file_type ?: (feature_first.toString().endsWith('.osw') ? 'osw' : 
                                                             feature_first.toString().contains('.oswpq') ? 'oswpq' : 'null')
  
  // Build file path arrays for JSON
  def xic_paths = xic_files instanceof List ? xic_files.collect { "\"${it}\"" }.join(', ') : "\"${xic_files}\""
  def feature_paths = feature_files instanceof List ? feature_files.collect { "\"${it}\"" }.join(', ') : "\"${feature_files}\""
  
  // Optional scores output file
  def scores_output = params.arycal.compute_scores && params.arycal.scores_output_file ? "\"${params.arycal.scores_output_file}\"" : 'null'
  
  """
  # Generate Arycal JSON config
  cat > arycal_config.json <<EOF
  {
    "xic": {
      "include-precursor": ${params.arycal.xic_include_precursor ?: false},
      "num-isotopes": ${params.arycal.xic_num_isotopes ?: 3},
      "file-type": "${xic_type}",
      "file-paths": [${xic_paths}]
    },
    "features": {
      "file-type": "${features_type}",
      "file-paths": [${feature_paths}]
    },
    "filters": {
      "include_decoys": ${params.arycal.include_decoys ?: false},
      "include_identifying_transitions": ${params.arycal.include_identifying_transitions ?: false},
      "max_score_ms2_qvalue": ${params.arycal.max_score_ms2_qvalue ?: 1.0},
      "precursor_ids": ${params.arycal.precursor_ids ?: 'null'}
    },
    "alignment": {
      "batch_size": ${params.arycal.batch_size ?: 1000},
      "method": "${params.arycal.alignment_method ?: 'fftdtw'}",
      "reference_type": "${params.arycal.reference_type ?: 'star'}",
      "reference_run": ${params.arycal.reference_run ?: 'null'},
      "use_tic": ${params.arycal.use_tic ?: true},
      "smoothing": {
        "sgolay_window": ${params.arycal.sgolay_window ?: 11},
        "sgolay_order": ${params.arycal.sgolay_order ?: 3}
      },
      "rt_mapping_tolerance": ${params.arycal.rt_mapping_tolerance ?: 10.0},
      "decoy_peak_mapping_method": "${params.arycal.decoy_peak_mapping_method ?: 'shuffle'}",
      "decoy_window_size": ${params.arycal.decoy_window_size ?: 30},
      "compute_scores": ${params.arycal.compute_scores ?: true},
      "scores_output_file": ${scores_output},
      "retain_alignment_path": ${params.arycal.retain_alignment_path ?: false}
    }
  }
EOF

  # Run Arycal
  export RAYON_NUM_THREADS=${task.cpus}
  export ARYCAL_LOG=${params.arycal.log_level ?: 'info'}
  
  arycal \\
    arycal_config.json \\
  2>&1 | tee arycal_alignment.log
  """
}
