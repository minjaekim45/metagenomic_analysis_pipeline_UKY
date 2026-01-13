#!/bin/bash
#SBATCH --job-name=attachTPM
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --partition=normal
#SBATCH --account=coa_mki314_uksr
#SBATCH -o /scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/zz.out/attachTPM-%j.out
#SBATCH -e /scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/zz.out/attachTPM-%j.err

set -euo pipefail

# -----------------------------
# Paths
# -----------------------------
ROOT="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files"
EGGNOG_ROOT="${ROOT}/34.eggnog"
NORM_DIR="${ROOT}/35.featureCounts/normalized"
MODULE_TSV="${ROOT}/module.tsv"

# python script path (the .py you already have)
PY_SCRIPT="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/Functional_annotation_Pipeline/04.attach_tpm_rpkm_to_module_hits.py"

# -----------------------------
# Conda
# -----------------------------
CONDA_SH="/project/mki314_uksr/miniconda3/etc/profile.d/conda.sh"
CONDA_ENV="eggnog"  # must contain python + pandas

# -----------------------------
# Args
# -----------------------------
MODULE=""        # either out_dir name (Acetoclastic) or module_id (M00357)
USE_ARRAY="0"    # if 1, take module from module.tsv using SLURM_ARRAY_TASK_ID
COMPRESS="1"     # write .tsv.gz
DRY_RUN="0"

usage() {
  cat <<EOF
Usage:
  # Single module directory:
  sbatch $0 --module Acetoclastic

  # Array mode (1 job per line in module.tsv):
  sbatch --array=1-N $0 --use_array

Options:
  --module <Hydrogenotrophic|Acetoclastic|...|Mxxxxx>
  --use_array
  --no-compress
  --dry-run
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --module) MODULE="${2:-}"; shift 2 ;;
    --use_array) USE_ARRAY="1"; shift 1 ;;
    --no-compress) COMPRESS="0"; shift 1 ;;
    --dry-run) DRY_RUN="1"; shift 1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[ERROR] Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

mkdir -p "${ROOT}/logs/attachTPM"

# -----------------------------
# Resolve module in array mode
# module.tsv format:
#   #module_id  out_dir
#   M00567      Hydrogenotrophic
#   ...
# We take the SLURM_ARRAY_TASK_ID-th non-comment line and read column2(out_dir).
# -----------------------------
if [[ "${USE_ARRAY}" == "1" ]]; then
  : "${SLURM_ARRAY_TASK_ID:?Need SLURM_ARRAY_TASK_ID when --use_array is set}"
  [[ -f "${MODULE_TSV}" ]] || { echo "[ERROR] module.tsv not found: ${MODULE_TSV}" >&2; exit 1; }

  line="$(awk -F'\t' '$0 !~ /^#/ && NF>0 {print}' "${MODULE_TSV}" | sed -n "${SLURM_ARRAY_TASK_ID}p")"
  [[ -n "${line}" ]] || { echo "[ERROR] No line ${SLURM_ARRAY_TASK_ID} in ${MODULE_TSV}" >&2; exit 1; }

  MODULE="$(echo "${line}" | awk -F'\t' '{print $2}')"
  [[ -n "${MODULE}" ]] || { echo "[ERROR] Failed to parse out_dir from: ${line}" >&2; exit 1; }
fi

if [[ -z "${MODULE}" ]]; then
  echo "[ERROR] --module is required unless --use_array is used." >&2
  usage
  exit 1
fi

# -----------------------------
# Activate conda env
# -----------------------------
[[ -f "${CONDA_SH}" ]] || { echo "[ERROR] conda.sh not found: ${CONDA_SH}" >&2; exit 1; }
# shellcheck source=/dev/null
source "${CONDA_SH}"
conda activate "${CONDA_ENV}"

python - <<'PY' || { echo "[ERROR] pandas not available in env. Install pandas or use a different env." >&2; exit 1; }
import pandas as pd
print("pandas OK:", pd.__version__)
PY

# -----------------------------
# Run attach
# -----------------------------
[[ -f "${PY_SCRIPT}" ]] || { echo "[ERROR] Python script not found: ${PY_SCRIPT}" >&2; exit 1; }

echo "[INFO] module(out_dir or id) = ${MODULE}"
echo "[INFO] eggnog_root = ${EGGNOG_ROOT}"
echo "[INFO] normalized_dir = ${NORM_DIR}"
echo "[INFO] module_tsv = ${MODULE_TSV}"

ARGS=(--eggnog_root "${EGGNOG_ROOT}"
      --normalized_dir "${NORM_DIR}"
      --module "${MODULE}"
      --module_tsv "${MODULE_TSV}")

if [[ "${COMPRESS}" == "1" ]]; then
  ARGS+=(--compress)
fi
if [[ "${DRY_RUN}" == "1" ]]; then
  ARGS+=(--dry_run)
fi

python "${PY_SCRIPT}" "${ARGS[@]}"

echo "[DONE] Finished module=${MODULE}"
