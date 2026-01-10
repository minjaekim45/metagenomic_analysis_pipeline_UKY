#!/bin/bash
# Build MAG × Module × Sample summary tables
# - activates 'eggnog' conda env
# - ensures pandas is installed
# - runs Python summarizer
#
# Usage:
#   bash build_module_abundance_summary.sh
#
# Outputs (under BASE_DIR):
#   IR37_modules_MAG_summary.tsv   (MAG, Module, n_genes + abundance)
#   IR37_modules_sample_potential.tsv (Module, Sample, Potential)

set -euo pipefail

CONDA_SH="/project/mki314_uksr/miniconda3/etc/profile.d/conda.sh"
CONDA_ENV="eggnog"

# --- activate conda env ---
if [[ ! -f "${CONDA_SH}" ]]; then
  echo "[ERROR] conda.sh not found at ${CONDA_SH}" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "${CONDA_SH}"
conda activate "${CONDA_ENV}"
echo "[INFO ] Activated conda env: ${CONDA_ENV}"
echo "[INFO ] Using python: $(command -v python)"

# --- ensure pandas ---
check_pandas() {
  python - << 'PY'
import sys
try:
    import pandas  # noqa
except Exception:
    sys.exit(1)
sys.exit(0)
PY
}

if ! check_pandas; then
  echo "[WARN ] pandas not found; installing with conda..."
  if ! conda install -y pandas; then
    echo "[ERROR] Failed to install pandas. Please install manually." >&2
    exit 1
  fi
  if ! check_pandas; then
    echo "[ERROR] pandas still not importable after install." >&2
    exit 1
  fi
fi
echo "[INFO ] pandas OK."

# --- paths ---
BASE_DIR="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/34.eggnog"
ABUN_TSV="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/29.TAD80/TAD80/abundance/04.abundance.tsv"
SCRIPT_DIR="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/Functional_annotation_Pipeline"
PY_SCRIPT="${SCRIPT_DIR}/summarize_modules_with_abundance.py"

echo "[INFO ] BASE_DIR   = ${BASE_DIR}"
echo "[INFO ] ABUNDANCE  = ${ABUN_TSV}"

if [[ ! -d "${BASE_DIR}" ]]; then
  echo "[ERROR] BASE_DIR not found: ${BASE_DIR}" >&2
  exit 1
fi
if [[ ! -f "${ABUN_TSV}" ]]; then
  echo "[ERROR] Abundance file not found: ${ABUN_TSV}" >&2
  exit 1
fi
if [[ ! -f "${PY_SCRIPT}" ]]; then
  echo "[ERROR] Python script not found: ${PY_SCRIPT}" >&2
  exit 1
fi

python "${PY_SCRIPT}" "${BASE_DIR}" "${ABUN_TSV}"

echo "[DONE ] Summary tables created."
