#!/usr/bin/env nextflow

params.metadata = file(params.metadata ?: 'Inputs/metadata.csv')
params.outdir  = params.outdir ?: 'results'

include { FETCH_DATA } from './modules.nf'
include { FASTQC as FASTQC_RAW } from './modules.nf'
include { FASTQC as FASTQC_TRIMMED } from './modules.nf'
include { TRIM_READS } from './modules.nf'
include { MULTIQC } from './modules.nf'


workflow {
    // Read metadata
    Channel
        .fromPath(params.metadata)
        .splitCsv(header:true)
        .map { row -> tuple(row.sample_id, row.accession) }
        .set { samples_ch }
    
    // Fetch data
    FETCH_DATA(samples_ch)
    
    // QC on raw reads
    raw_reads_ch = FETCH_DATA.out
                    .map { sample_id, reads -> tuple(sample_id, 'raw', reads) }
    FASTQC_RAW(raw_reads_ch)
    
    // Trim reads
    TRIM_READS(FETCH_DATA.out)
    
    // QC on trimmed reads
    trimmed_reads_ch = TRIM_READS.out.reads
                                .map { sample_id, reads -> tuple(sample_id, 'trimmed', reads)}
    FASTQC_TRIMMED(trimmed_reads_ch)
    
    // Collect all files for MultiQC
    all_qc_files = FASTQC_RAW.out.zip
                    .mix(FASTQC_TRIMMED.out.zip)
                    .mix(TRIM_READS.out.logs)
                    .map { it[2] }  // Extract file path
                    .collect()
    
    // Run MultiQC
    MULTIQC(all_qc_files)
}