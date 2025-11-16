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
  def pasefFlags = params.osw.pasef ? "-pasef -ion_mobility_window ${params.osw.im_window} -Scoring:Scores:use_ion_mobility_scores true" : ""
  def irtFlag    = irt_traml ? "-tr_irt ${irt_traml}" : ""
  def swathFlag  = swath_windows ? "-swath_windows_file ${swath_windows}" : ""

  """
  mkdir -p tmp_${dia_mzml.baseName}

  OpenSwathWorkflow \\
    -in ${dia_mzml} \\
    -tr ${pqp} \\
    -auto_irt true \\
    -min_rsq 0.0 \\
    -pasef \\
    -min_upper_edge_dist 1 \\
    -estimate_extraction_windows all \\
    -ion_mobility_window 0.06 \\
    -im_extraction_window_ms1 0.06 \\
    -irt_im_extraction_window 0.1 \\
    ${irtFlag} \\
    ${swathFlag} \\
    ${pasefFlags} \\
    ${cacheFlags} \\
    -out_features ${dia_mzml.baseName}.osw \\
    -out_chrom ${dia_mzml.baseName}.sqMass \\
    -Debugging:irt_mzml ${dia_mzml.baseName}_debug_calibration_irt_chrom.mzML \\
    -Debugging:irt_trafo ${dia_mzml.baseName}_debug_calibration_irt.trafoXML \\
    -Calibration:MassIMCorrection:debug_mz_file ${dia_mzml.baseName}_debug_calibration_mz.txt \\
    -Calibration:MassIMCorrection:debug_im_file ${dia_mzml.baseName}_debug_calibration_im.txt \\
    -Calibration:RTNormalization:alignmentMethod lowess \\
    -Calibration:RTNormalization:lowess:auto_span true \\
    -Calibration:MassIMCorrection:mz_correction_function quadratic_regression_delta_ppm \\
    -force \\
    -threads ${task.cpus} \\
    $args \\
  2>&1 | tee ${dia_mzml.baseName}_openswath.log

  rm -rf tmp_${dia_mzml.baseName}
  """
}
