#!/bin/bash
# Run summarize_modules_per_MAG.py with automatic:
#   - conda env activation
#   - pandas installation check
#
# Usage:
#   bash run_summarize_modules_per_MAG.sh
#   bash run_summarize_modules_per_MAG.sh <BASE_DIR> <OUT_PREFIX>
#
# Defaults:
#   BASE_DIR   = /scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/34.eggnog
#   OUT_PREFIX = ${BASE_DIR}/IR37_modules

set -euo pipefail

###############################################
# 1. Conda activation
###############################################

CONDA_SH="/project/mki314_uksr/miniconda3/etc/profile.d/conda.sh"
CONDA_ENV="eggnog"

if [[ ! -f "${CONDA_SH}" ]]; then
  echo "[ERROR] conda.sh not found at ${CONDA_SH}" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "${CONDA_SH}"
conda activate "${CONDA_ENV}"

echo "[INFO ] Activated conda env: ${CONDA_ENV}"
echo "[INFO ] Using python: $(command -v python)"

###############################################
# 2. Ensure pandas is available (auto-install)
###############################################

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
  echo "[WARN ] pandas is not available in this environment."
  echo "[INFO ] Trying to install pandas via 'conda install -y pandas'..."
  if ! conda install -y pandas; then
    echo "[ERROR] Failed to install pandas with conda." >&2
    echo "[ERROR] Please install pandas manually in env '${CONDA_ENV}' and re-run." >&2
    exit 1
  fi

  if ! check_pandas; then
    echo "[ERROR] pandas is still not importable after installation." >&2
    exit 1
  fi
fi

echo "[INFO ] pandas import OK."

###############################################
# 3. Resolve BASE_DIR and OUT_PREFIX
###############################################

BASE_DEFAULT="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/34.eggnog"
OUT_DEFAULT="${BASE_DEFAULT}/IR37_modules"

BASE_DIR="${1:-$BASE_DEFAULT}"
OUT_PREFIX="${2:-$OUT_DEFAULT}"

echo "[INFO ] BASE_DIR   = ${BASE_DIR}"
echo "[INFO ] OUT_PREFIX = ${OUT_PREFIX}"

if [[ ! -d "${BASE_DIR}" ]]; then
  echo "[ERROR] BASE_DIR does not exist: ${BASE_DIR}" >&2
  exit 1
fi

###############################################
# 4. Run Python script
###############################################

SCRIPT_DIR="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/Functional_annotation_Pipeline"
PY_SCRIPT="${SCRIPT_DIR}/summarize_modules_per_MAG.py"

if [[ ! -f "${PY_SCRIPT}" ]]; then
  echo "[ERROR] Python script not found: ${PY_SCRIPT}" >&2
  exit 1
fi

echo "[INFO ] Running summarize_modules_per_MAG.py ..."
python "${PY_SCRIPT}" "${BASE_DIR}" "${OUT_PREFIX}"

echo "[DONE ] Summary tables created."
