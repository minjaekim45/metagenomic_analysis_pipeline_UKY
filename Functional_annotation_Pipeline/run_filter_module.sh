#!/bin/bash
set -euo pipefail

###############################################
# Conda activation
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
# Ensure pandas is available (auto-install if missing)
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
  # you can change channel options here if needed
  if ! conda install -y pandas; then
    echo "[ERROR] Failed to install pandas with conda." >&2
    echo "[ERROR] Please install pandas manually in env '${CONDA_ENV}' and re-run." >&2
    exit 1
  fi

  # re-check
  if ! check_pandas; then
    echo "[ERROR] pandas is still not importable after installation." >&2
    exit 1
  fi
fi

echo "[INFO ] pandas import OK."

###############################################
# Config
###############################################

# Root directory that contains per-MAG eggNOG outputs
BASE="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/34.eggnog"

# Python script path
SCRIPT_DIR="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/Functional_annotation_Pipeline"
FILTER_SCRIPT="${SCRIPT_DIR}/filter_by_module.py"

if [[ ! -x "${FILTER_SCRIPT}" ]]; then
  echo "[ERROR] filter_by_module.py not found or not executable at ${FILTER_SCRIPT}" >&2
  exit 1
fi

# Module → output subdirectory name
declare -A MODULE_DIR=(
  [M00567]="Hydrogenotrophic"   # CO2 → CH4
  [M00357]="Acetoclastic"       # Acetate → CH4
  [M00356]="Methanol"           # Methanol → CH4
  [M00563]="Methylamine"        # Methylamines → CH4
  [M00422]="AcetylCoA"          # Acetyl-CoA pathway
)

# MAG directory name patterns to process
PATTERNS=(
  "IR37_0d.*"
  "IR37_06-5d.*"
  "IR37_11-5d.*"
  "IR37_13-5d.*"
  "IR37_18-5d.*"
  "IR37_20d.*"
  "IR37_58d.*"
  "IR37_120d.*"
)

###############################################
# Prepare output directories
###############################################

for mod in "${!MODULE_DIR[@]}"; do
  out_dir="${BASE}/${MODULE_DIR[$mod]}"
  mkdir -p "${out_dir}"
  echo "[INFO ] Output directory for ${mod}: ${out_dir}"
done

###############################################
# Main loop over MAGs and modules
###############################################

for pat in "${PATTERNS[@]}"; do
  for MAG_DIR in "${BASE}"/${pat}; do
    # Skip if glob did not match anything
    [[ -e "${MAG_DIR}" ]] || continue
    [[ -d "${MAG_DIR}" ]] || continue

    MAG=$(basename "${MAG_DIR}")
    ANN="${MAG_DIR}/${MAG}.eggnog.emapper.annotations"

    if [[ ! -f "${ANN}" ]]; then
      echo "[WARN ] Annotation file not found for ${MAG}: ${ANN}" >&2
      continue
    fi

    echo "== MAG ${MAG} =="

    for mod in "${!MODULE_DIR[@]}"; do
      out_dir="${BASE}/${MODULE_DIR[$mod]}"
      out_tsv="${out_dir}/${MAG}_${mod}.tsv"

    # Remove any old file from previous runs
     rm -f "${out_tsv}"

    echo "[RUN  ] ${MAG} module ${mod} → ${out_tsv}"
    python "${FILTER_SCRIPT}" "${ANN}" "${mod}" "${out_tsv}"

    # If filter script wrote nothing (no hits), the file will not exist
    if [[ ! -f "${out_tsv}" ]]; then
      echo "[SKIP] No genes for module ${mod} in MAG ${MAG} (no output file)."
    fi
    done
    echo
  done
done

echo "[DONE ] All modules processed."
