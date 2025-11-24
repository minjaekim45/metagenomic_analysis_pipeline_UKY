#!/bin/bash
#SBATCH --time=2-00:00:00
#SBATCH --job-name=MicrobC_all
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --partition=normal
#SBATCH -e argDB-%j.err
#SBATCH -o argDB-%j.out
#SBATCH --account=coa_mki314_uksr

set -euo pipefail

# 입력 폴더(프로젝트 루트) 필수
FOLDER=${1:?Usage: sbatch MicrobeCensus_all.bash /path/to/project_folder}
INDIR="$FOLDER/04.trimmed_fasta"
OUTDIR="$FOLDER/14.microbe_census"
THR=${SLURM_CPUS_PER_TASK:-8}

mkdir -p "$OUTDIR"
cd "$OUTDIR"

echo "==[14.microbe_census: $(date)]=="
echo "FOLDER=$FOLDER"
echo "THR=$THR"

# ---- Conda 활성화 (module 없이 고정 경로) ----
# conda.sh 경로는 네가 가진 미니콘다 설치 위치로 맞춰둔 것
if [[ -f /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh ]]; then
  # 현재 셸에 conda 훅 로드
  # (이 줄이 없으면 'Run conda init before conda activate' 에러)
  source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh
  conda activate microbecensus
else
  # conda.sh가 없다면 hook 방법(직접 conda 바이너리 경로 사용)
  eval "$(/project/mki314_uksr/miniconda3/bin/conda shell.bash hook)"
  conda activate microbecensus
fi

# 유틸 존재 확인
if ! command -v run_microbe_census.py >/dev/null 2>&1; then
  echo "ERROR: run_microbe_census.py not found in active env 'microbecensus'." >&2
  echo " -> 'microbeCensus'가 해당 env에 설치되어 있는지 확인하세요." >&2
  exit 1
fi

# 파일 글롭이 비어도 에러 안 나게
shopt -s nullglob

# 1) SingleReads 먼저 처리
for f in "$INDIR"/*.SingleReads.fa; do
  [[ -e "$f" ]] || continue
  b=$(basename "$f" .SingleReads.fa)
  out="$OUTDIR/$b.microbecensus.out"
  if [[ -s "$out" ]]; then
    echo "[$b] exists → skip"
    continue
  fi
  echo "[$b] Single Reads"
  run_microbe_census.py -n 100000000 -t "$THR" -l 50 \
    "$f" "$out"
done

# 2) PairedReads (_1/_2) — 같은 basename의 SingleReads가 있으면 패스
for f1 in "$INDIR"/*_1.fa; do
  [[ -e "$f1" ]] || continue
  b=$(basename "$f1" _1.fa)
  # 같은 basename의 SingleReads가 있으면 SingleReads만 사용
  if [[ -s "$INDIR/$b.SingleReads.fa" ]]; then
    echo "[$b] has SingleReads → skip paired"
    continue
  fi
  f2="$INDIR/${b}_2.fa"
  if [[ ! -s "$f2" ]]; then
    echo "[$b] missing pair (_2.fa) → skip" >&2
    continue
  fi
  out="$OUTDIR/$b.microbecensus.out"
  if [[ -s "$out" ]]; then
    echo "[$b] exists → skip"
    continue
  fi
  echo "[$b] Paired Reads"
  run_microbe_census.py -n 100000000 -t "$THR" -l 50 \
    "$f1,$f2" "$out"
done

shopt -u nullglob
conda deactivate
echo "MicrobeCensus Completed (all)"