process OPENSWATHWORKFLOW {
  tag "${dia_mzml.baseName}"
  label 'process_high'
  label 'openms'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:v0.3.1' }"

  input:
  path dia_mzml
  path pqp
  each irt_traml optional true
  each swath_windows optional true

  output:
  path "${dia_mzml.baseName}.osw"
  path "${dia_mzml.baseName}.sqMass"
  path "${dia_mzml.baseName}_debug_calibration_irt.trafoXML"
  path "${dia_mzml.baseName}_debug_calibration_irt_chrom.mzML"
  path "${dia_mzml.baseName}_debug_calibration_mz.txt"
  path "${dia_mzml.baseName}_debug_calibration_im.txt"

  script:
  def args = task.ext.args ?: ''
  def cacheFlags = params.osw.cache_in_mem ? "-readOptions cacheWorkingInMemory -tempDirectory \$PWD/tmp_${dia_mzml.baseName}" : ""
  def pasefFlags = params.osw.pasef ? "-pasef -ion_mobility_window ${params.osw.im_window} -Scoring:Scores:use_ion_mobility_scores true" : ""
  def irtFlag    = irt_traml ? "-tr_irt ${irt_traml}" : ""

  """
  mkdir -p tmp_${dia_mzml.baseName}

  OpenSwathWorkflow \\
    -in ${dia_mzml} \\
    -tr ${pqp} \\
    -estimate_extraction_windows \\
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
    -thread ${task.cpus} \\
    $args \\
    2>&1 | tee ${ms_file.baseName}_openswath.log

  rm -rf tmp_${dia_mzml.baseName}
  """
}
