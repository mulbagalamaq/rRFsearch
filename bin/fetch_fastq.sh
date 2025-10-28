#!/bin/bash
set -euo pipefail

acc=$1
outdir=$2
cache_dir="${outdir}/sra_cache"
mkdir -p "$cache_dir"

echo "[INFO] Fetching $acc ..."

# Type of source file
if [[ "$acc" =~ ^SRR|^DRR|^ERR ]]; then
    source="SRA"
else
    echo "[WARN] Could not determine source for $acc — assuming SRA"
    source="SRA"
fi

# Function: aria2 via ENA
download_with_aria() {
    echo "[INFO] Using aria2c from ENA FTP mirror"
    ftp_link=$(curl -s "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${acc}&result=read_run&fields=fastq_ftp" | tail -n1 | tr ';' '\n' | head -n1)
    if [[ -n "$ftp_link" ]]; then
        aria2c -x 16 -d "$outdir" "ftp://${ftp_link}"
    else
        echo "[ERROR] ENA FTP link not found for $acc" >&2
        exit 1
    fi
}

# SRA or ENA
if command -v aria2c &>/dev/null && [[ "$acc" =~ ^ERR|^DRR ]]; then
    download_with_aria
else
    echo "[INFO] Using prefetch (HTTP)"
    prefetch "$acc" --output-directory "$cache_dir"
    
    # Find the downloaded .sra file
    sra_file=$(find "$cache_dir" -name "*.sra" -type f | head -n1)
    
    if [[ -n "$sra_file" && -f "$sra_file" ]]; then
        echo "[INFO] Converting ${sra_file} to FASTQ..."
        fasterq-dump "$sra_file" -O "$outdir" --split-files --threads 4
    else
        echo "[ERROR] No .sra file found in $cache_dir for $acc" >&2
        ls -R "$cache_dir" >&2  # Debug: show what was downloaded
        exit 1
    fi
fi

# Gzip the output files
gzip -f "$outdir"/${acc}*.fastq 2>/dev/null || true

echo "[DONE] $acc retrieval completed!"