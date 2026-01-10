#!/bin/bash
set -euo pipefail

###############################################
# Config
###############################################

# Root directory that contains per-MAG eggNOG outputs
# (EDIT this path to your real 19.eggnog directory)
EGGNOG_ROOT="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/34.eggnog"

# MAG directory name patterns to process
# e.g. IR37_0d.2, IR37_06-5d.7, IR37_20d.15, ...
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
# Main loop
###############################################

for pat in "${PATTERNS[@]}"; do
    for MAG_DIR in "${EGGNOG_ROOT}"/${pat}; do
        # Skip if glob did not match anything
        [[ -e "${MAG_DIR}" ]] || continue
        [[ -d "${MAG_DIR}" ]] || continue

        MAG=$(basename "${MAG_DIR}")

        # Expected annotation file:
        #   <MAG>.eggnog.emapper.annotations
        ANN="${MAG_DIR}/${MAG}.eggnog.emapper.annotations"

        if [[ ! -f "${ANN}" ]]; then
            echo "WARNING: annotation file not found for MAG ${MAG} (${ANN})" >&2
            continue
        fi

        OUT="${MAG_DIR}/${MAG}_map00680.tsv"

        echo "[RUN ] ${MAG} → ${OUT}"

        {
            # Header: last comment line (starts with '#'), remove leading '#'
            grep '^#' "${ANN}" | tail -n 1 | sed 's/^#//'

            # Body: non-comment lines containing map00680 (Methane metabolism)
            grep -v '^#' "${ANN}" | grep 'map00680'
        } > "${OUT}"

        echo "[DONE] ${MAG}"
    done
done

echo "All done."
