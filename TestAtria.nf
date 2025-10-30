#!/usr/bin/env nextflow

params.outdir  = params.outdir ?: 'test'

process ATRIA_TRIM {
    container 'docker.io/anirudhbaliga/atria:latest'
    tag "$sample_id"
    publishDir "${params.outdir}/${sample_id}/trimmed", mode: 'copy'

    input:
    tuple val(sample_id), path(read1), path(read2)

    output:
    tuple val(sample_id), path("*atria*.fastq.gz"), emit: reads
    tuple val(sample_id), path("*.log"), emit: logs

    script:
    """
    atria \
        -r ${read1} \
        -R ${read2} \
        -o . \
        --polyG \
        -t 4
    """
}


workflow {
    input_ch = Channel.fromFilePairs('test/*_{1,2}.fastq.gz', flat: true)

    ATRIA_TRIM(input_ch)

}