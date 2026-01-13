#!/bin/bash
#SBATCH --time=1-00:00:00
#SBATCH --job-name=TPM_RPKM
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --partition=normal
#SBATCH --account=coa_mki314_uksr
#SBATCH -o ./zz.out/normTPM-%j.out
#SBATCH -e ./zz.out/normTPM-%j.err

set -euo pipefail

BASE="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files"
FC_DIR="$BASE/35.featureCounts"
OUT_DIR="$FC_DIR/normalized"

mkdir -p "$OUT_DIR"

# conda (python만 있으면 됨: 표준라이브러리만 사용)
source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh
conda activate subread   # python 있는 env면 아무거나 OK (subread에 보통 python 있음)

echo "==[ normalize TPM/RPKM: $(date) ]=="
echo "FC_DIR=$FC_DIR"
echo "OUT_DIR=$OUT_DIR"

# python script 위치 (원하는 곳에 저장해둔 경로로 맞춰)
PY="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/Functional_annotation_Pipeline/03.normalize_featureCounts_samples.py"

python3 "$PY" \
  --fc_dir "$FC_DIR" \
  --out_dir "$OUT_DIR" \
  --prefix "IR37_" \
  --compress

conda deactivate
echo "Done: $(date)"
