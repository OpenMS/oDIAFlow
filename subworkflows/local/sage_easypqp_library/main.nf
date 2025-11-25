/*
  Subworkflow to run SAGE searches (DDA +/- DIA), combine results, convert to EasyPQP pickles and build an EasyPQP library (transition TSV / PQP).

  Inputs:
    - DDA_FOR_SEARCH : channel of DDA input tuples (as produced in workflows)
    - DIA_FOR_SEARCH : channel of DIA input tuples or Channel.empty()
    - fasta_ch : channel with fasta file

  Emits:
    - library_tsv : transition TSV produced by EasyPQP library step
    - psmpkl : list of psmpkl files (from EASYPQP_CONVERTSAGE)
    - peakpkl : list of peakpkl files
    - sage_results : combined SAGE results TSV (joined results + matched fragments)
*/

include { SAGE_SEARCH } from '../../../modules/local/sage/search/main.nf'
include { SAGE_COMBINE_RESULTS } from '../../../modules/local/sage/combine_searches/main.nf'
include { EASYPQP_CONVERTSAGE } from '../../../modules/local/easypqp/convertsage/main.nf'
include { EASYPQP_LIBRARY } from '../../../modules/local/easypqp/library/main.nf'

workflow SAGE_EASYPQP_LIBRARY {

  take:
    DDA_FOR_SEARCH
    DIA_FOR_SEARCH
    fasta_ch

  main:
    // Run SAGE on DDA files
    dda_sage_results = SAGE_SEARCH(DDA_FOR_SEARCH, fasta_ch)

    // Optionally run SAGE on DIA (for library building) and combine
    if (params.sage.search_dia_for_lib && params.dia_for_lib_glob) {
      dia_sage_results = SAGE_SEARCH(DIA_FOR_SEARCH, fasta_ch)

      combined_input = dda_sage_results.results
        .map { sample_id, results_tsv, search_type -> tuple("combined", results_tsv) }
        .join(
          dia_sage_results.results.map { sample_id, results_tsv, search_type -> tuple("combined", results_tsv) }
        )
        .join(
          dda_sage_results.matched_fragments.map { sample_id, fragments_tsv, search_type -> tuple("combined", fragments_tsv) }
        )
        .join(
          dia_sage_results.matched_fragments.map { sample_id, fragments_tsv, search_type -> tuple("combined", fragments_tsv) }
        )

      sage_combined_output = SAGE_COMBINE_RESULTS(combined_input)
      sage_combined = sage_combined_output.results.join(sage_combined_output.matched_fragments)
    } else {
      // Use only DDA results
      sage_combined = dda_sage_results.results
        .map { sample_id, results_tsv, search_type -> tuple(sample_id, results_tsv) }
        .join(
          dda_sage_results.matched_fragments.map { sample_id, fragments_tsv, search_type -> tuple(sample_id, fragments_tsv) }
        )
    }

    // Convert SAGE -> EasyPQP pickle format and build library
    EASYPQP_CONVERTSAGE(sage_combined)

    all_psmpkls = EASYPQP_CONVERTSAGE.out.psmpkl.map{ it[1] }.collect()
    all_peakpkls = EASYPQP_CONVERTSAGE.out.peakpkl.map{ it[1] }.collect()
    easypqp_out = EASYPQP_LIBRARY(all_psmpkls, all_peakpkls)

  emit:
    library_tsv = easypqp_out.library_tsv
    run_peaks = easypqp_out.run_peaks
    psmpkl = EASYPQP_CONVERTSAGE.out.psmpkl
    peakpkl = EASYPQP_CONVERTSAGE.out.peakpkl
    sage_results = sage_combined
}
