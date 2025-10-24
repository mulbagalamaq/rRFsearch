#!/usr/bin/env nextflow


params.metadata = file(params.metadata ?: 'metadata.csv')
params.outdir  = params.outdir ?: 'results'

process trim_reads {

    container 'biocontainers/trim-galore:v0.6.7_cv3'

    tag "$sample_id"
    publishDir "${params.outdir}/${sample_id}", mode: 'copy'

    input:
    tuple val(sample_id), path(fastq_files)

    output:
    tuple val(sample_id), path("*_trimmed.fq.gz")

    script:
    """
    trim_galore --gzip --paired ${fastq_files.join(' ')} -o ./
    """
}