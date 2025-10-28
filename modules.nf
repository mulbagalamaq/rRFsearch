
process FETCH_DATA {
    containerOptions '--entrypoint /bin/bash'
    container 'docker.io/anirudhbaliga/sra_toolkit:latest'
    tag "$sample_id"
    publishDir "${params.outdir}/${sample_id}/raw", mode: 'copy'

    input:
    tuple val(sample_id), val(accession)

    output:
    tuple val(sample_id), path("*.fastq.gz")

    script:
    """

    bash ${projectDir}/bin/fetch_fastq.sh ${accession} .
    """
}

process FASTQC {
    container 'staphb/fastqc:0.12.1'
    tag "$sample_id"
    publishDir "${params.outdir}/${sample_id}/fastqc_${stage}", mode: 'copy'

    input:
    tuple val(sample_id), val(stage), path(reads)

    output:
    tuple val(sample_id), val(stage), path("*.html"), emit: html
    tuple val(sample_id), val(stage), path("*.zip"), emit: zip

    script:
    """
    fastqc -t ${task.cpus} -q ${reads}
    """
}

process TRIM_READS {
    container 'anirudhbaliga/atria:latest'
    tag "$sample_id"
    publishDir "${params.outdir}/${sample_id}/trimmed", mode: 'copy'

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path("*trimmed*.fastq.gz"), emit: reads
    tuple val(sample_id), path("*.log"), emit: logs

    script:
    def is_paired = reads instanceof List && reads.size() == 2
    
    if (is_paired) {
        """
        atria \
            -r ${reads[0]} \
            -R ${reads[1]} \
            -o . \
            --length-range 20:500 \
            --polyG \
            --check-identifier \
            -t ${task.cpus}
        """
    } else {
        """
        atria \
            -r ${reads} \
            -o . \
            --length-range 20:500 \
            --polyG \
            -t ${task.cpus}
        """
    }
}

process MULTIQC {
    container 'staphb/fastqc:0.12.1'
    publishDir "${params.outdir}/multiqc", mode: 'copy'

    input:
    path input_files

    output:
    path("multiqc_report.html")
    path("multiqc_data")

    script:
    """
    multiqc . \
        --title "QC and Trimming Report" \
        --filename multiqc_report.html
    """
}
