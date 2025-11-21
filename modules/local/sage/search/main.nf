process SAGE_SEARCH {
  tag "${search_type}_sage_search"
  label 'process_high'
  label 'sage'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }" // Temp use dev image which contains OpenMS develop branch for latests changes to the OpenSwathWorkflow

  publishDir "${params.outdir}/sage/${search_type}", mode: params.publish_dir_mode, enabled: params.save_reports, pattern: "*.html", saveAs: { filename -> "${search_type}_${filename}" }
  publishDir "${params.outdir}/logs/sage", mode: params.publish_dir_mode, enabled: params.save_logs, pattern: "*.log"
  publishDir "${params.outdir}/sage/${search_type}", mode: params.publish_dir_mode, enabled: params.save_intermediates, pattern: "*.sage.tsv"

  input:
  tuple val(sample_id), path(mzml_files), val(search_type)  // search_type: 'dda' or 'dia'
  path fasta

  output:
  tuple val(sample_id), path("results.sage.tsv"), val(search_type), emit: results
  tuple val(sample_id), path("results.sage.parquet"), val(search_type), emit: results_parquet, optional: true
  tuple val(sample_id), path("matched_fragments.sage.tsv"), val(search_type), emit: matched_fragments, optional: true
  path "*.pin", emit: pin, optional: true
  path "*.html", emit: report, optional: true
  path "*.log", emit: log

  script:
  // Determine chimera and wide_window based on search type
  def chimera_setting = search_type == 'dia' ? params.sage.dia_chimera : params.sage.chimera
  def wide_window_setting = search_type == 'dia' ? params.sage.dia_wide_window : params.sage.wide_window
  
  def annotate_matches = params.sage.annotate_matches ? '--annotate-matches' : ''
  def write_pin = params.sage.write_pin ? '--write-pin' : ''
  def parquet = params.sage.parquet ? '--parquet' : ''
  def batch_size = params.sage.batch_size == 0 ? '' : "--batch-size ${params.sage.batch_size}"
  def write_report = params.sage.write_report ? '--write-report' : ''
  """
  # Generate Sage JSON config
  cat > sage_config.json <<EOF
  {
    "version": "0.14.6",
    "database": {
      "bucket_size": ${params.sage.bucket_size ?: 16384},
      "enzyme": {
        "missed_cleavages": ${params.sage.missed_cleavages},
        "min_len": ${params.sage.min_len ?: 'null'},
        "max_len": ${params.sage.max_len ?: 'null'},
        "cleave_at": "${params.sage.cleave_at ?: 'KR'}",
        "restrict": ${params.sage.restrict ?: 'null'},
        "c_terminal": ${params.sage.c_terminal ?: 'null'},
        "semi_enzymatic": ${params.sage.semi_enzymatic ?: 'null'}
      },
      "fragment_min_mz": ${params.sage.fragment_min_mz ?: 150.0},
      "fragment_max_mz": ${params.sage.fragment_max_mz ?: 1500.0},
      "peptide_min_mass": ${params.sage.peptide_min_mass ?: 500.0},
      "peptide_max_mass": ${params.sage.peptide_max_mass ?: 5000.0},
      "ion_kinds": ${params.sage.ion_kinds ?: '["b", "y"]'},
      "min_ion_index": ${params.sage.min_ion_index ?: 2},
      "static_mods": ${params.sage.static_mods ?: '{"C": 57.0216}'},
      "variable_mods": ${params.sage.variable_mods ?: '{}'},
      "max_variable_mods": ${params.sage.max_variable_mods ?: 2},
      "decoy_tag": "${params.sage.decoy_tag ?: 'rev_'}",
      "generate_decoys": ${params.sage.generate_decoys ?: true}
    },
    "quant": {
      "tmt": ${params.sage.tmt ?: 'null'},
      "tmt_settings": {
        "level": ${params.sage.tmt_level ?: 3},
        "sn": ${params.sage.tmt_sn ?: false}
      },
      "lfq": ${params.sage.lfq ?: false},
      "lfq_settings": {
        "peak_scoring": "${params.sage.lfq_peak_scoring ?: 'Hybrid'}",
        "integration": "${params.sage.lfq_integration ?: 'Sum'}",
        "spectral_angle": ${params.sage.lfq_spectral_angle ?: 0.7},
        "ppm_tolerance": ${params.sage.lfq_ppm_tolerance ?: 5.0},
        "combine_charge_states": ${params.sage.lfq_combine_charge_states ?: true}
      }
    },
    "precursor_tol": {
      "ppm": [${params.sage.precursor_tol_ppm_low ?: -50.0}, ${params.sage.precursor_tol_ppm_high ?: 50.0}]
    },
    "fragment_tol": {
      "ppm": [${params.sage.fragment_tol_ppm_low ?: -10.0}, ${params.sage.fragment_tol_ppm_high ?: 10.0}]
    },
    "precursor_charge": [${params.sage.precursor_charge_min ?: 2}, ${params.sage.precursor_charge_max ?: 4}],
    "isotope_errors": [${params.sage.isotope_errors_min ?: -1}, ${params.sage.isotope_errors_max ?: 3}],
    "deisotope": ${params.sage.deisotope ?: true},
    "chimera": ${chimera_setting},
    "wide_window": ${wide_window_setting},
    "min_peaks": ${params.sage.min_peaks ?: 15},
    "max_peaks": ${params.sage.max_peaks ?: 150},
    "max_fragment_charge": ${params.sage.max_fragment_charge ?: 1},
    "min_matched_peaks": ${params.sage.min_matched_peaks ?: 4},
    "report_psms": ${params.sage.report_psms ?: 1},
    "predict_rt": ${params.sage.predict_rt ?: true},
    "write_report": ${params.sage.write_report}
  }
EOF

  # Run Sage
  export RAYON_NUM_THREADS=${task.cpus}
  export SAGE_LOG_LEVEL=${params.sage.log_level}
  sage \\
    sage_config.json \\
    --fasta ${fasta} \\
    ${batch_size} \\
    ${annotate_matches} \\
    ${write_pin} \\
    ${parquet} \\
    ${write_report} \\
    ${mzml_files} \\
  2>&1 | tee sage_search_${search_type}.log
  """
}
