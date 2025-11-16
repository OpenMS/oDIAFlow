process PYPROPHET_CALIBRATION_REPORT {
  tag "pyprophet_export_calibration_report"

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }" // Temp use dev image which contains OpenMS develop branch for latests changes to the OpenSwathWorkflow

  input:
  path working_dir 

  output:
  path "calibration_report.pdf"

  when:
  true

  script:
  """
  pyprophet export calibration-report --wd ${working_dir}   2>&1 | tee pyprophet_calibration_report.log
  """
}
