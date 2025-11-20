process OPENSWATHWORKFLOW {
  tag "${dia_mzml.baseName}"
  label 'process_high'
  label 'openms'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }" // Temp use dev image which contains OpenMS develop branch for latests changes to the OpenSwathWorkflow

  input:
  path dia_mzml
  path pqp
  path irt_traml
  path irt_nonlinear_traml
  path swath_windows

  output:
  path "${dia_mzml.baseName}.osw", emit: osw
  path "${dia_mzml.baseName}.sqMass", emit: chrom_mzml
  path "${dia_mzml.baseName}_debug_calibration_irt.trafoXML", emit: irt_trafo, optional: true
  path "${dia_mzml.baseName}_debug_calibration_irt_chrom.mzML", emit: irt_chrom, optional: true
  path "${dia_mzml.baseName}_debug_calibration_mz.txt", emit: debug_mz, optional: true
  path "${dia_mzml.baseName}_debug_calibration_im.txt", emit: debug_im, optional: true

  script:
  def args = task.ext.args ?: ''
  def cacheFlags = params.osw.cache_in_mem ? "-readOptions cacheWorkingInMemory -tempDirectory \$PWD/tmp_${dia_mzml.baseName}" : ""
  def pasefFlags = params.osw.pasef ? "-pasef -ion_mobility_window ${params.osw.im_window} -im_extraction_window_ms1 ${params.osw.im_extraction_window_ms1} -irt_im_extraction_window ${params.osw.irt_im_extraction_window} -Calibration:MassIMCorrection:debug_im_file ${dia_mzml.baseName}_debug_calibration_im.txt -Scoring:Scores:use_ion_mobility_scores -Scoring:add_up_spectra 3 -Scoring:spectrum_merge_method_type dynamic -Scoring:merge_spectra_by_peak_width_fraction 0.20 -Scoring:apply_im_peak_picking " : ""
  def irtFlag    = irt_traml.name != 'input.1' ? "-Calibration:tr_irt ${irt_traml}" : ""
  def irtFlagNonlinear = irt_nonlinear_traml.name != 'input.2' ? "-Calibration:tr_irt_nonlinear ${irt_nonlinear_traml}" : ""
  def swathFlag  = swath_windows.name != 'input.3' ? "-swath_windows_file ${swath_windows}" : ""

  """
  mkdir -p tmp_${dia_mzml.baseName}

  OpenSwathWorkflow \\
    -in ${dia_mzml} \\
    -tr ${pqp} \\
    -auto_irt ${params.osw.auto_irt} \\
    -Calibration:irt_bins ${params.osw.linear_irt_bins} \\
    -Calibration:irt_peptides_per_bin ${params.osw.linear_irt_peptides_per_bin} \\
    -Calibration:irt_bins_nonlinear ${params.osw.nonlinear_irt_bins} \\
    -Calibration:irt_peptides_per_bin_nonlinear ${params.osw.nonlinear_irt_peptides_per_bin} \\
    -min_rsq ${params.osw.min_rsq} \\
    -min_upper_edge_dist 1 \\
    -estimate_extraction_windows all \\
    ${irtFlag} \\
    ${irtFlagNonlinear} \\
    ${swathFlag} \\
    ${pasefFlags} \\
    ${cacheFlags} \\
    -out_features ${dia_mzml.baseName}.osw \\
    -out_chrom ${dia_mzml.baseName}.sqMass \\
    -Debugging:irt_mzml ${dia_mzml.baseName}_debug_calibration_irt_chrom.mzML \\
    -Debugging:irt_trafo ${dia_mzml.baseName}_debug_calibration_irt.trafoXML \\
    -Calibration:RTNormalization:alignmentMethod lowess \\
    -Calibration:RTNormalization:lowess:auto_span true \\
    -Calibration:RTNormalization:estimateBestPeptides \\
    -Calibration:RTNormalization:outlierMethod iter_residual \\
    -Calibration:MassIMCorrection:debug_mz_file ${dia_mzml.baseName}_debug_calibration_mz.txt \\
    -mz_correction_function quadratic_regression_delta_ppm \\
    -force \\
    -batchSize ${params.osw.batch_size} \\
    -threads ${task.cpus} \\
    -debug ${params.osw.debug} \\
    ${args} \\
  2>&1 | tee ${dia_mzml.baseName}_openswath.log

  rm -rf tmp_${dia_mzml.baseName}
  """
}
