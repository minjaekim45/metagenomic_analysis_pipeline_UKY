#!/bin/bash
set -euo pipefail

# -----------------------
# Defaults (edit 거의 필요 없음)
# -----------------------
CONDA_SH="/project/mki314_uksr/miniconda3/etc/profile.d/conda.sh"
CONDA_ENV="eggnog"

BASE="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/34.eggnog"
SCRIPT_DIR="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/Functional_annotation_Pipeline"
FILTER_SCRIPT="${SCRIPT_DIR}/filter_by_module.py"

GROUP_LIST="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/IR37_group_list.txt"
MODULE_MAP="./modules.tsv"        # module_id -> out_dir
COLUMN="KEGG_Module"                   # default
MODULES=""                             # empty = use all in MODULE_MAP

# -----------------------
# Parse args
# -----------------------
usage() {
  cat <<EOF
Usage:
  bash run_filter_module.sh [--modules M00567,M00357] [--module-map modules_map.tsv]
                            [--group-list IR37_group_list.txt] [--column KEGG_Module]
                            [--base 34.eggnog] [--script-dir Functional_annotation_Pipeline]

Notes:
  - If --modules is omitted, all module IDs in --module-map are processed.
  - --column can be KEGG_Module (default) or other eggNOG columns (e.g. KEGG_Pathway).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --modules) MODULES="$2"; shift 2;;
    --module-map) MODULE_MAP="$2"; shift 2;;
    --group-list) GROUP_LIST="$2"; shift 2;;
    --column) COLUMN="$2"; shift 2;;
    --base) BASE="$2"; shift 2;;
    --script-dir) SCRIPT_DIR="$2"; FILTER_SCRIPT="${SCRIPT_DIR}/filter_by_module.py"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "[ERROR] Unknown arg: $1" >&2; usage; exit 1;;
  esac
done

# -----------------------
# Conda activation
# -----------------------
[[ -f "${CONDA_SH}" ]] || { echo "[ERROR] conda.sh not found: ${CONDA_SH}" >&2; exit 1; }
# shellcheck source=/dev/null
source "${CONDA_SH}"
conda activate "${CONDA_ENV}"
echo "[INFO ] Activated conda env: ${CONDA_ENV}"
echo "[INFO ] Using python: $(command -v python)"

# pandas check (원래 스크립트 스타일 유지)
python - <<'PY' || {
import sys
try:
    import pandas  # noqa
except Exception:
    sys.exit(1)
sys.exit(0)
PY
echo "[INFO ] pandas import OK."

# -----------------------
# Sanity checks
# -----------------------
[[ -x "${FILTER_SCRIPT}" ]] || { echo "[ERROR] filter script not executable: ${FILTER_SCRIPT}" >&2; exit 1; }
[[ -f "${GROUP_LIST}" ]] || { echo "[ERROR] GROUP_LIST not found: ${GROUP_LIST}" >&2; exit 1; }
[[ -f "${MODULE_MAP}" ]] || { echo "[ERROR] MODULE_MAP not found: ${MODULE_MAP}" >&2; exit 1; }

# -----------------------
# Load module map: module_id -> out_dir
# -----------------------
declare -A MODULE_DIR
while IFS=$'\t' read -r mod outdir; do
  [[ -z "${mod}" ]] && continue
  [[ "${mod}" =~ ^# ]] && continue
  [[ -z "${outdir}" ]] && { echo "[ERROR] Bad line in module map (missing outdir): ${mod}" >&2; exit 1; }
  MODULE_DIR["$mod"]="$outdir"
done < "${MODULE_MAP}"

# Choose module IDs
mods_to_run=()
if [[ -n "${MODULES}" ]]; then
  IFS=',' read -r -a mods_to_run <<< "${MODULES}"
else
  for m in "${!MODULE_DIR[@]}"; do
    mods_to_run+=("$m")
  done
fi

# Prepare output dirs
for mod in "${mods_to_run[@]}"; do
  out_dir="${BASE}/${MODULE_DIR[$mod]}"
  mkdir -p "${out_dir}"
  echo "[INFO ] Output directory for ${mod}: ${out_dir}"
done

# -----------------------
# Loop: group -> MAG -> module
# -----------------------
while read -r group_prefix; do
  [[ -z "${group_prefix}" ]] && continue
  [[ "${group_prefix}" =~ ^# ]] && continue

  for MAG_DIR in "${BASE}/${group_prefix}."*; do
    [[ -d "${MAG_DIR}" ]] || continue
    MAG=$(basename "${MAG_DIR}")
    ANN="${MAG_DIR}/${MAG}.eggnog.emapper.annotations"
    [[ -f "${ANN}" ]] || { echo "[WARN ] Missing: ${ANN}" >&2; continue; }

    echo "== MAG ${MAG} =="

    for mod in "${mods_to_run[@]}"; do
      out_dir="${BASE}/${MODULE_DIR[$mod]}"
      out_tsv="${out_dir}/${MAG}_${mod}.tsv"
      rm -f "${out_tsv}"

      echo "[RUN  ] ${MAG}  ${COLUMN} contains ${mod} -> ${out_tsv}"
      python "${FILTER_SCRIPT}" --input "${ANN}" --column "${COLUMN}" --id "${mod}" --out "${out_tsv}"

      [[ -f "${out_tsv}" ]] || echo "[SKIP] No hits for ${mod} in ${MAG}"
    done
    echo
  done
done < "${GROUP_LIST}"

echo "[DONE ] All processed."