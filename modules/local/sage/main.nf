process SAGE_SEARCH {
  tag "sage_search"
  label 'process_high'
  label 'sage'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }" // Temp use dev image which contains OpenMS develop branch for latests changes to the OpenSwathWorkflow

  input:
  tuple val(sample_id), path(dda_mzml)
  path fasta
  path output_directory

  output:
  tuple val(sample_id), path("results.sage.tsv"), emit: results
  tuple val(sample_id), path("results.sage.parquet"), emit: results_parquet, optional: true
  tuple val(sample_id), path("matched_fragments.sage.tsv"), emit: matched_fragments, optional: true
  path "*.pin", emit: pin, optional: true

  script:
  def annotate_matches = params.sage.annotate_matches ? '--annotate-matches' : ''
  def write_pin = params.sage.write_pin ? '--write-pin' : ''
  def parquet = params.sage.parquet ? '--parquet' : ''
  def batch_size = params.sage.batch_size == 0 ? '' : "--batch-size ${params.sage.batch_size}"
  
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
        "restrict": "${params.sage.restrict ?: 'P'}",
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
      "generate_decoys": ${params.sage.generate_decoys ?: true},
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
    "chimera": ${params.sage.chimera ?: false},
    "wide_window": ${params.sage.wide_window ?: false},
    "min_peaks": ${params.sage.min_peaks ?: 15},
    "max_peaks": ${params.sage.max_peaks ?: 150},
    "max_fragment_charge": ${params.sage.max_fragment_charge ?: 1},
    "min_matched_peaks": ${params.sage.min_matched_peaks ?: 4},
    "report_psms": ${params.sage.report_psms ?: 1},
    "predict_rt": ${params.sage.predict_rt ?: true},
  }
EOF

  # Run Sage
  export RAYON_NUM_THREADS=${task.cpus}
  export SAGE_LOG_LEVEL=${params.sage.log_level}
  sage \\
    sage_config.json \\
    --output_directory ${output_directory} \\
    --fasta ${fasta} \\
    ${batch_size} \\
    ${annotate_matches} \\
    ${write_pin} \\
    ${parquet} \\
    ${dda_mzml} \\
  2>&1 | tee sage_search.log
  """
}
