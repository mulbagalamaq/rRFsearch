# rRFsearch

A Nextflow pipeline for processing RNA-seq data from SRA to identify and analyze ribosomal RNA-derived fragments (rRFs).

## Overview

This pipeline automates:
1. Download sequencing data from NCBI SRA
2. Quality control of raw reads (FastQC)
3. Adapter trimming and quality filtering (Atria)
4. Quality control of trimmed reads (FastQC)
5. Aggregate quality reports (MultiQC)

## Prerequisites

- [Nextflow](https://www.nextflow.io/) (≥ 21.04)
- [Docker](https://www.docker.com/)

### Docker Images
```bash
docker pull anirudhbaliga/sra_toolkit:latest
docker pull anirudhbaliga/atria:latest
docker pull staphb/fastqc:0.12.1
docker pull multiqc/multiqc:latest
```

## Installation

```bash
git clone <repository-url>
cd rRFsearch
curl -s https://get.nextflow.io | bash
sudo mv nextflow /usr/local/bin/
```

## Configuration

Create `nextflow.config`:

```groovy
docker.enabled = true

process {
    withName: 'FETCH_DATA' {
        container = 'anirudhbaliga/sra_toolkit:latest'
    }
    withName: 'FASTQC_RAW' {
        container = 'staphb/fastqc:0.12.1'
    }
    withName: 'TRIM_READS' {
        container = 'anirudhbaliga/atria:latest'
    }
    withName: 'FASTQC_TRIMMED' {
        container = 'staphb/fastqc:0.12.1'
    }
    withName: 'MULTIQC' {
        container = 'multiqc/multiqc:latest'
    }
}
```

## Usage

```bash
# Basic run
nextflow run main.nf --metadata metadata.csv --outdir results

# Resume failed run
nextflow run main.nf -resume
```

## Input

Create `metadata.csv` with SRA accession numbers (one per line):
```
SRR000001
SRR000002
SRR000003
```

Both single-end and paired-end data are supported automatically.

## Output

```
results/
├── SRR000001/
│   ├── raw/
│   │   ├── *.fastq.gz
│   │   └── fastqc/
│   └── trimmed/
│       ├── *trimmed*.fastq.gz
│       ├── *.log
│       └── fastqc/
└── multiqc/
    └── multiqc_report.html
```

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--metadata` | (required) | Path to file with SRA metadata |
| `--outdir` | `results` | Output directory for results |

## Citation

- **Nextflow**: Di Tommaso, P., et al. (2017). Nature Biotechnology, 35(4), 316-319.
- **FastQC**: Andrews, S. (2010). FastQC: a quality control tool for high throughput sequence data.
- **MultiQC**: Ewels, P., et al. (2016). Bioinformatics, 32(19), 3047-3048.