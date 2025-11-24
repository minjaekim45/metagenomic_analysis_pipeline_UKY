#!/bin/bash
#SBATCH --job-name=gtdbtk_tree
#SBATCH --partition=normal
#SBATCH --nodes=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=64G
#SBATCH --time=2-00:00:00
#SBATCH -o gtdbtk_tree-%j.out
#SBATCH -e gtdbtk_tree-%j.err
#SBATCH --account=coa_mki314_uksr

set -euo pipefail

# === 입력/출력 ===
# IN: 17.gtdbtk 또는 그 안의 align 디렉토리, 또는 프로젝트 루트(그 안에 17.gtdbtk 있어야 함)
IN=${1:?Usage: sbatch gtdbtk_tree.bash <path_to_17.gtdbtk_or_align_or_project_root> [OUT_DIR]}
OUT=${2:-/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/17.gtdbtk}
mkdir -p "$OUT"

# === conda hook 찾기 (pscratch 우선) ===
for base in /pscratch/mki314_uksr/miniconda3 /project/mki314_uksr/miniconda3 "$HOME/miniconda3"; do
  if [[ -f "$base/etc/profile.d/conda.sh" ]]; then
    # shellcheck disable=SC1090
    source "$base/etc/profile.d/conda.sh"
    CONDA_BASE="$base"
    break
  fi
done
: "${CONDA_BASE:?No conda base found at /pscratch or /project or \$HOME.}"

# === env 보장 (scratch에 없으면 자동 생성) ===
ENV_PREFIX="/scratch/$USER/gtdbtk_env"
if [[ ! -x "$ENV_PREFIX/bin/iqtree2" ]]; then
  # defaults 채널 TOS 우회: conda-forge/bioconda만 사용
  conda create -y -p "$ENV_PREFIX" --override-channels -c conda-forge -c bioconda \
    iqtree=2.* fasttree gotree biopython matplotlib
fi
RUN="conda run -p $ENV_PREFIX"

# === 파이썬 의존성 확인(heredoc 대신 -c 사용) ===
if ! "$ENV_PREFIX/bin/python" -c "import Bio, matplotlib" >/dev/null 2>&1; then
  conda install -y -p "$ENV_PREFIX" --override-channels -c conda-forge biopython matplotlib
fi

# === align 디렉토리 찾아 표준화 ===
if [[ -d "$IN/align" ]]; then
  ALIGN="$IN/align"
elif [[ -d "$IN" && "$(basename "$IN")" == "align" ]]; then
  ALIGN="$IN"
elif [[ -d "$IN/17.gtdbtk/align" ]]; then
  ALIGN="$IN/17.gtdbtk/align"
else
  echo "ERROR: align dir not found under '$IN' (expected .../17.gtdbtk/align)" >&2
  exit 2
fi

# === 입력 MSA 선택 (user_msa 우선, 없으면 전체 msa) ===
MSA_GZ=/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/17.gtdbtk/align/gtdbtk.bac120.user_msa.fasta.gz
OUT=/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/17.gtdbtk

# === tip 라벨 정리(파일명 첫 '.' 이전만 남김) ===
MSA_AA="$OUT/msa_user.aa.fasta"
gunzip -c "$MSA_GZ" > "$MSA_AA"

# === IQ-TREE2로 트리 추정 + midpoint 루팅 ===
THR=${SLURM_CPUS_PER_TASK:-8}
PREFIX="$OUT/bac120_user"

$RUN iqtree2 -s "$MSA_AA" -st AA -m MFP -B 1000 --alrt 1000 -T "$THR" -pre "$PREFIX"
$RUN gotree reroot midpoint -i "${PREFIX}.treefile" -o "${PREFIX}.mid.nwk"

echo "DONE."
echo "Outputs:"
echo " - $MSA_AA"
echo " - ${PREFIX}.treefile (Newick)"
echo " - ${PREFIX}.mid.nwk   (midpoint-rooted Newick)"

conda install -y -p /scratch/sch496/gtdbtk_env biopython matplotlib

# (2) 그림 내보내기 (경로는 네가 쓰던 OUT 디렉터리)
OUT=/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/17.gtdbtk
TREE=$OUT/bac120_user.mid.nwk

conda run -p /scratch/sch496/gtdbtk_env python - <<'PY'
from Bio import Phylo
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

tree_path = r"/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/17.gtdbtk/bac120_user.mid.nwk"
png_path  = r"/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/17.gtdbtk/tree.png"
pdf_path  = r"/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/17.gtdbtk/tree.pdf"

t = Phylo.read(tree_path, "newick")
fig = plt.figure(figsize=(12, 18))       # 필요하면 크기 조절
ax  = fig.add_subplot(1,1,1)
Phylo.draw(t, do_show=False, axes=ax)
plt.savefig(png_path, dpi=300, bbox_inches="tight")
plt.savefig(pdf_path, dpi=300, bbox_inches="tight")
PY

echo "Saved: $OUT/tree.png  and  $OUT/tree.pdf"
