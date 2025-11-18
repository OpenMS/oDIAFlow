// Minimal wrapper to call OPENSWATHWORKFLOW from the module
include { OPENSWATHWORKFLOW } from '../local/openms/openswathworkflow/main.nf'

workflow {
    // Separate channels for each input
    def dia_mzml_ch = Channel.of( file('modules/tests/data/test_raw_1.mzML.gz') )
    def pqp_ch = Channel.of( file('modules/tests/data/test.pqp') )
    def irt_traml_ch = Channel.of( [] )
    def irt_nonlinear_traml_ch = Channel.of( [] )
    def swath_windows_ch = Channel.of( file('modules/tests/data/strep_win.txt') )

    OPENSWATHWORKFLOW(dia_mzml_ch, pqp_ch, irt_traml_ch, irt_nonlinear_traml_ch, swath_windows_ch)
}
