process PYPROPHET_INFER_PEPTIDOFORM {
  tag "pyprophet_infer_peptidoform"
  label 'pyprophet'
  label 'process_high'

  container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:dev' }" // Temp use dev image which contains OpenMS develop branch for latests changes to the OpenSwathWorkflow

  input:
  path merged

  output:
  path "merged.osw"

  // Note: PyProphet writes scores back into the same OSW by default.
  script:

  def ipf_ms1_scoring = params.pyprophet.infer_peptidoforms.ipf_ms1_scoring ? '--ipf_ms1_scoring' : '--no-ipf_ms1_scoring'
  def ipf_ms2_scoring = params.pyprophet.infer_peptidoforms.ipf_ms2_scoring ? '--ipf_ms2_scoring' : '--no-ipf_ms2_scoring'
  def ipf_stride = params.pyprophet.infer_peptidoforms.propagate_signal_across_runs ? '--propagate_signal_across_runs --ipf_max_alignment_pep ${params.pyprophet.infer_peptidoforms.ipf_max_alignment_pep} --across_run_confidence_threshold ${params.pyprophet.infer_peptidoforms.across_run_confidence_threshold}' : ''

  """
  pyprophet infer peptidoform --in ${merged} ${ipf_ms1_scoring} ${ipf_ms2_scoring} \
    --ipf_max_precursor_pep ${params.pyprophet.infer_peptidoforms.ipf_max_precursor_pep} \
    --ipf_max_peakgroup_pep ${params.pyprophet.infer_peptidoforms.ipf_max_peakgroup_pep} \
    --ipf_max_precursor_peakgroup_pep ${params.pyprophet.infer_peptidoforms.ipf_max_precursor_peakgroup_pep} \
    --ipf_max_transition_pep ${params.pyprophet.infer_peptidoforms.ipf_max_transition_pep} ${ipf_stride} 2>&1 | tee pyprophet_infer_peptidoform.log
  """
}
