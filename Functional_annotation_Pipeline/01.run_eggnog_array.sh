#!/bin/bash
#SBATCH --job-name=eggnog_IR37_groups
#SBATCH --time=2-00:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=40G
#SBATCH --partition=normal
#SBATCH --account=coa_mki314_uksr
#SBATCH -o /scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/zz.out/eggnog-group-%A_%a.out
#SBATCH -e /scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/zz.out/eggnog-group-%A_%a.err
#SBATCH --array=0-7    # 8 groups

set -euo pipefail
# Usage: sbatch ./run_eggnog_array.sh

# ----- conda env -----
source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh
conda activate eggnog

command -v emapper.py >/dev/null 2>&1 || {
  echo "ERROR: emapper.py not found in PATH. Activate eggnog env." >&2
  exit 1
}

BAKTA_ROOT="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/11.bakta/results"
SCRIPT_DIR="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/Functional_annotation_Pipeline"
GROUP_LIST="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/IR37_group_list.txt"

# ----- pick group prefix for this array task -----
N_GROUPS=$(wc -l < "${GROUP_LIST}")
TASK_ID=${SLURM_ARRAY_TASK_ID:-0}

if (( TASK_ID >= N_GROUPS )); then
  echo "Array index ${TASK_ID} >= N_GROUPS ${N_GROUPS}, nothing to do."
  exit 0
fi

LINE_NO=$(( TASK_ID + 1 ))
GROUP_PREFIX=$(sed -n "${LINE_NO}p" "${GROUP_LIST}")

if [[ -z "${GROUP_PREFIX}" ]]; then
  echo "Empty group prefix at line ${LINE_NO} in ${GROUP_LIST}" >&2
  exit 1
fi

export CPUS=${SLURM_CPUS_PER_TASK:-8}

echo "== Job ${SLURM_JOB_ID}, task ${TASK_ID} → group ${GROUP_PREFIX}, CPUS=${CPUS} =="

# ----- loop over all MAGs in this group -----
for MAG_DIR in "${BAKTA_ROOT}/${GROUP_PREFIX}."*; do
  [[ -d "${MAG_DIR}" ]] || continue
  MAG=$(basename "${MAG_DIR}")

  echo "[RUN ] ${MAG}"
  bash "${SCRIPT_DIR}/run_eggnog_single.sh" "${MAG}"
  echo "[DONE] ${MAG}"
  echo
done

echo "== Group ${GROUP_PREFIX} completed =="
