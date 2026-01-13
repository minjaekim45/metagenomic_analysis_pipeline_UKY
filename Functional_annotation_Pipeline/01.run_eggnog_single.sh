#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 MAG_NAME (e.g. IR37_18-5d.120)" >&2
  exit 1
fi

MAG="$1"

# File path
BAKTA_ROOT="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/11.bakta/results"
OUT_ROOT="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/34.eggnog"
EGGNOG_DB_DIR="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/databases/eggnog_db"

CPUS="${CPUS:-8}"

FAA="${BAKTA_ROOT}/${MAG}/${MAG}.faa"
MAG_OUT_DIR="${OUT_ROOT}/${MAG}"
OUT_PREFIX="${MAG}.eggnog"
OUT_ANNOT="${MAG_OUT_DIR}/${OUT_PREFIX}.emapper.annotations"

mkdir -p "${MAG_OUT_DIR}"

if [[ ! -f "${FAA}" ]]; then
  echo "[WARN] ${MAG}: ${FAA} does not exist." >&2
  exit 0
fi

if [[ -f "${OUT_ANNOT}" ]]; then
  echo "[SKIP] ${MAG}: ${OUT_ANNOT} already exists."
  exit 0
fi

echo "[RUN ] ${MAG} (cpus=${CPUS})"
echo "       input : ${FAA}"
echo "       out   : ${MAG_OUT_DIR}/${OUT_PREFIX}.*"

emapper.py \
  -i "${FAA}" \
  --itype proteins \
  -o "${OUT_PREFIX}" \
  --output_dir "${MAG_OUT_DIR}" \
  --cpu "${CPUS}" \
  --data_dir "${EGGNOG_DB_DIR}" \
  -m diamond

echo "[DONE] ${MAG}"
