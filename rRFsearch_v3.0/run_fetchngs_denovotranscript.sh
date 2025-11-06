#!/usr/bin/env bash
set -euo pipefail

print_help() {
  cat <<'EOF'
Usage: bash run_fetchngs_denovotranscript.sh \
  --accessions samples/accessions.csv \
  --outdir results \
  [--profile docker|conda] \
  [--fetchngs_rev REV] \
  [--rnaseq_rev REV] \
  [--remove_ribo_rna true|false] \
  [--extra_fastp_args "..."] \
  [--genome KEY | --fasta FILE --gtf FILE] \
  [--skip_alignment true|false] \
  [--transcript_fasta FILE]

Runs nf-core/fetchngs to download reads and generate a samplesheet, then runs
nf-core/rnaseq using that samplesheet for QC, trimming, optional rRNA removal, and MultiQC.
EOF
}

ACCESSIONS=""
OUTDIR="results"
PROFILE="docker"
FETCHNGS_REV=""
RNASEQ_REV=""
REMOVE_RIBO_RNA="true"
EXTRA_FASTP_ARGS=""
GENOME=""
FASTA=""
GTF=""
GFF=""
SKIP_ALIGNMENT="false"
TRANSCRIPT_FASTA=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --accessions)
      ACCESSIONS="$2"; shift 2 ;;
    --outdir)
      OUTDIR="$2"; shift 2 ;;
    --profile)
      PROFILE="$2"; shift 2 ;;
    --fetchngs_rev)
      FETCHNGS_REV="$2"; shift 2 ;;
    --rnaseq_rev)
      RNASEQ_REV="$2"; shift 2 ;;
    --remove_ribo_rna)
      REMOVE_RIBO_RNA="$2"; shift 2 ;;
    --extra_fastp_args)
      EXTRA_FASTP_ARGS="$2"; shift 2 ;;
    --genome)
      GENOME="$2"; shift 2 ;;
    --fasta)
      FASTA="$2"; shift 2 ;;
    --gtf)
      GTF="$2"; shift 2 ;;
    --gff)
      GFF="$2"; shift 2 ;;
    --skip_alignment)
      SKIP_ALIGNMENT="$2"; shift 2 ;;
    --transcript_fasta)
      TRANSCRIPT_FASTA="$2"; shift 2 ;;
    -h|--help)
      print_help; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      print_help; exit 1 ;;
  esac
done

if [[ -z "$ACCESSIONS" ]]; then
  echo "Error: --accessions is required" >&2
  print_help
  exit 1
fi

if [[ ! -f "$ACCESSIONS" ]]; then
  echo "Error: accessions file not found: $ACCESSIONS" >&2
  exit 1
fi

mkdir -p "$OUTDIR"

SANITIZED_ACCESSIONS="$OUTDIR/accessions.sanitized.csv"
echo "Sanitising accessions into $SANITIZED_ACCESSIONS"
if python3 - "$ACCESSIONS" "$SANITIZED_ACCESSIONS" <<'PY'
import pathlib
import re
import sys

pattern = re.compile(r"^(((SR|ER|DR)[APRSX])|(SAM(N|EA|D))|(PRJ(NA|EB|DB))|(GS[EM]))(\d+)$")
input_path = pathlib.Path(sys.argv[1])
output_path = pathlib.Path(sys.argv[2])

raw_lines = input_path.read_text().splitlines()
valid_ids = []
invalid_ids = []
duplicates = []
seen = set()

def normalise(line):
    stripped = line.strip()
    if not stripped or stripped.startswith('#'):
        return None

    # Split on comma or tab to capture first field only
    for sep in (',', '\t'):
        if sep in stripped:
            stripped = stripped.split(sep, 1)[0]
            break

    # If whitespace separated, take the first token
    stripped = stripped.split()[0]
    return stripped

for raw in raw_lines:
    candidate = normalise(raw)
    if candidate is None:
        continue
    if candidate.lower() == 'id':
        continue
    if pattern.fullmatch(candidate):
        if candidate not in seen:
            valid_ids.append(candidate)
            seen.add(candidate)
        else:
            duplicates.append(candidate)
    else:
        invalid_ids.append(candidate)

if not valid_ids:
    sys.stderr.write("No valid SRA/ENA/DDBJ/GEO accessions found in '{}'.\n".format(input_path))
    if invalid_ids:
        sys.stderr.write("Rejected entries: {}\n".format(', '.join(invalid_ids)))
    if duplicates:
        sys.stderr.write("Duplicate entries: {}\n".format(', '.join(duplicates)))
    sys.exit(1)

with output_path.open('w', encoding='utf-8') as handle:
    for accession in valid_ids:
        handle.write(f"{accession}\n")

sys.stdout.write(
    "  Accepted {} accession(s); {} invalid and {} duplicate entries ignored.\n".format(
        len(valid_ids), len(invalid_ids), len(duplicates)
    )
)
PY
then
  echo "Sanitised accessions saved to $SANITIZED_ACCESSIONS"
else
  echo "Failed to sanitise accessions." >&2
  exit 1
fi

ACCESSIONS_FOR_FETCH="$SANITIZED_ACCESSIONS"

echo "[1/2] Running nf-core/fetchngs..."
FETCH_OUTDIR="$OUTDIR/fetchngs"
mkdir -p "$FETCH_OUTDIR"

FETCH_CMD=(
  nextflow run nf-core/fetchngs
  -profile "$PROFILE"
  --input "$ACCESSIONS_FOR_FETCH"
  --outdir "$FETCH_OUTDIR"
  --nf_core_pipeline rnaseq
)

if [[ -n "$FETCHNGS_REV" ]]; then
  FETCH_CMD+=( -r "$FETCHNGS_REV" )
fi

echo "Running: ${FETCH_CMD[*]}"
"${FETCH_CMD[@]}"

echo "Locate samplesheet from fetchngs..."
# Prefer rnaseq-style samplesheet if present
SAMPLESHEET="$(find "$FETCH_OUTDIR" -type f -name "*samplesheet*.csv" | head -n 1 || true)"
if [[ -z "$SAMPLESHEET" ]]; then
  echo "Error: Could not find a samplesheet produced by fetchngs in $FETCH_OUTDIR" >&2
  exit 1
fi
echo "Using samplesheet: $SAMPLESHEET"

echo "[2/2] Running nf-core/rnaseq..."
RNASEQ_OUTDIR="$OUTDIR/rnaseq"
mkdir -p "$RNASEQ_OUTDIR"

DENOVO_CMD=(
  nextflow run nf-core/rnaseq
  -profile "$PROFILE"
  --input "$SAMPLESHEET"
  --outdir "$RNASEQ_OUTDIR"
)

if [[ "$REMOVE_RIBO_RNA" == "true" ]]; then
  DENOVO_CMD+=( --remove_ribo_rna )
fi

if [[ -n "$EXTRA_FASTP_ARGS" ]]; then
  DENOVO_CMD+=( --extra_fastp_args "$EXTRA_FASTP_ARGS" )
fi

if [[ -n "$RNASEQ_REV" ]]; then
  DENOVO_CMD+=( -r "$RNASEQ_REV" )
fi

# Reference selection for rnaseq
if [[ -n "$GENOME" ]]; then
  DENOVO_CMD+=( --genome "$GENOME" )
fi
if [[ -n "$FASTA" ]]; then
  DENOVO_CMD+=( --fasta "$FASTA" )
fi
if [[ -n "$GTF" ]]; then
  DENOVO_CMD+=( --gtf "$GTF" )
fi
if [[ -n "$GFF" ]]; then
  DENOVO_CMD+=( --gff "$GFF" )
fi
if [[ "$SKIP_ALIGNMENT" == "true" ]]; then
  DENOVO_CMD+=( --skip_alignment )
fi
if [[ -n "$TRANSCRIPT_FASTA" ]]; then
  DENOVO_CMD+=( --transcript_fasta "$TRANSCRIPT_FASTA" )
fi

echo "Running: ${DENOVO_CMD[*]}"
"${DENOVO_CMD[@]}"

echo "All done. Outputs:"
echo " - $FETCH_OUTDIR"
echo " - $RNASEQ_OUTDIR"


