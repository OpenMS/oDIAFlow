process PYPROPHET_CALIBRATION_REPORT {
  tag "pyprophet_calibration_report"
  label 'pyprophet'
  label 'process_low'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }"

  publishDir "${params.outdir}/reports", mode: params.publish_dir_mode, enabled: params.save_calibration, pattern: "*.pdf"
  publishDir "${params.outdir}/logs/pyprophet", mode: params.publish_dir_mode, enabled: params.save_logs, pattern: "*.log"

  input:
  path debug_files  // All debug calibration files from OpenSwathWorkflow

  output:
  path "calibration_report.pdf", emit: report
  path "*.log", emit: log

  script:
  """
  # Create working directory structure that pyprophet expects
  mkdir -p calibration_data
  
  # Copy all debug files to the working directory
  for file in ${debug_files}; do
    cp "\$file" calibration_data/
  done
  
  # Generate calibration report (pyprophet auto-detects debug files in --wd)
  pyprophet export calibration-report \\
    --wd calibration_data \\
    --report-file calibration_report.pdf \\
    2>&1 | tee pyprophet_calibration_report.log
  """
}
