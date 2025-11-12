process DIAPYSEF_TDF_TO_MZML {
    tag "$meta.mzml_id"
    label 'process_low'
    label 'process_single'
    label 'error_retry'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/openswath/openswath-sif:v0.3.1' :
        'ghcr.io/openswath/openswath:v0.3.1' }"

    stageInMode {
        if (task.attempt == 1) {
            if (executor == "awsbatch") {
                'symlink'
            } else {
                'link'
            }
        } else if (task.attempt == 2) {
            if (executor == "awsbatch") {
                'copy'
            } else {
                'symlink'
            }
        } else {
            'copy'
        }
    }

    input:
    // meta should at least have: meta.mzml_id
    tuple val(meta), path(rawfile)

    output:
    tuple val(meta), path("*.mzML"), emit: mzmls_converted
    path "versions.yml",                emit: versions
    path "*.log",                       emit: log

    script:
    def args   = task.ext.args   ?: ''                       // extra diapysef args
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"        // output/log prefix

    """
    # diapysef requires Bruker SDK libs inside the container (libtimsdata)
    # Convert TDF (.d folder) -> mzML in current working directory
    diapysef converttdftomzml \\
        --in=${rawfile} \\
        --out=. \\
        ${args} \\
        2>&1 | tee ${prefix}_conversion.log

    # Version manifest
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        diapysef: \$(diapysef --version || true)
    END_VERSIONS
    """
}