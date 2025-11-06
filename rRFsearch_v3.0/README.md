# rRFsearch v3.0

This directory provides a simple two-step workflow using nf-core pipelines:

1. nf-core/fetchngs – download SRA/ENA/GEO reads and generate a samplesheet
2. nf-core/rnaseq – perform FastQC → fastp (trimming) → FastQC → SortMeRNA (optional rRNA removal) → MultiQC

The wrapper script orchestrates both runs and passes the samplesheet from fetchngs to denovotranscript.

## Prerequisites
- Nextflow (>=22.10 recommended)
- Either Docker or Conda/Mamba
- Internet access for pipeline/environment pulls

## Quickstart
```bash
# From this directory
bash run_fetchngs_denovotranscript.sh \
  --accessions samples/accessions.csv \
  --outdir results \
  --profile docker \
  --remove_ribo_rna true \
  --extra_fastp_args "--cut_tail --trim_poly_g --trim_poly_x"
```

- Place your run accessions (SRR/ERR/DRR/GEO identifiers) in `samples/accessions.csv` (one ID per line, no header). The wrapper sanitises this file, ignoring comment lines and non-matching identifiers before running `fetchngs`.
- The script first runs nf-core/fetchngs and generates a samplesheet compatible with nf-core rnaseq-style inputs. It then invokes nf-core/denovotranscript with that samplesheet.

## Script options
```text
--accessions           Path to an accessions list (csv/tsv/txt/yml); comments/headers ok [required]
--outdir               Output directory root (default: results)
--profile              Nextflow profile to use for both pipelines (docker|conda) (default: docker)
--fetchngs_rev         Pipeline revision for nf-core/fetchngs (default: latest)
--rnaseq_rev           Pipeline revision for nf-core/rnaseq (default: latest)
--remove_ribo_rna      true/false to enable SortMeRNA in rnaseq (default: true)
--extra_fastp_args     Extra fastp args string for rnaseq (default: empty)
--genome               iGenomes key (e.g., GRCh38, GRCm39) to auto-fetch FASTA+GTF
--fasta                Path to reference genome FASTA (alternative to --genome)
--gtf                  Path to gene annotation GTF (paired with --fasta)
--gff                  Path to gene annotation GFF (alternative to --gtf)
--skip_alignment       true/false to run quantification without alignment (default: false)
--transcript_fasta     Transcriptome FASTA when using --skip_alignment
```

## Outputs
- `results/fetchngs/` – raw downloads, metadata and generated samplesheet
- `results/rnaseq/` – QC, trimming, optional rRNA removal and MultiQC report

## Notes
- The script attempts to use `--nf_core_pipeline rnaseq` in fetchngs to produce a standard nf-core samplesheet. This is directly compatible with nf-core/rnaseq. If you already have an rnaseq-compatible samplesheet, you can skip fetchngs and run the pipeline directly.
- nf-core/rnaseq requires reference data. Provide either:
  - `--genome <KEY>` (recommended for common organisms with iGenomes support), or
  - `--fasta <genome.fa> --gtf <genes.gtf>` (or `--gff <genes.gff>`), or
  - `--skip_alignment true --transcript_fasta <transcripts.fa>` for quant-only mode.
- Adjust `--profile` to match your environment. If using conda, ensure mamba/conda is configured and available on PATH.


