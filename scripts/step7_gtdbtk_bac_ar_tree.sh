#!/bin/bash
#SBATCH --job-name=gtdbtk_bac_ar_tree
#SBATCH --partition=normal
#SBATCH --nodes=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=64G
#SBATCH --time=2-00:00:00
#SBATCH -o gtdbtk_bac_ar_tree-%j.out
#SBATCH -e gtdbtk_bac_ar_tree-%j.err
#SBATCH --account=coa_mki314_uksr

set -euo pipefail

usage() {
  echo "Usage: sbatch scripts/step7_gtdbtk_bac_ar_tree.sh <path_to_gtdbtk_or_align_or_project_root> [OUT_DIR]" >&2
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 1
fi

IN="$1"
OUT="${2:-$IN}"

if [[ -d "$IN/align" ]]; then
  ALIGN_DIR="$IN/align"
elif [[ -d "$IN" && "$(basename "$IN")" == "align" ]]; then
  ALIGN_DIR="$IN"
elif [[ -d "$IN/17.gtdbtk/align" ]]; then
  ALIGN_DIR="$IN/17.gtdbtk/align"
else
  echo "ERROR: align directory not found from input '$IN'." >&2
  echo "Expected one of: <gtdbtk_out>/align, <align>, or <project_root>/17.gtdbtk/align" >&2
  exit 2
fi

if [[ "$OUT" == "$IN" ]]; then
  OUT="$(dirname "$ALIGN_DIR")"
fi
mkdir -p "$OUT"

CONDA_BASE=""
for base in /pscratch/mki314_uksr/miniconda3 /project/mki314_uksr/miniconda3 "$HOME/miniconda3"; do
  if [[ -f "$base/etc/profile.d/conda.sh" ]]; then
    # shellcheck disable=SC1090
    source "$base/etc/profile.d/conda.sh"
    CONDA_BASE="$base"
    break
  fi
done

if [[ -z "$CONDA_BASE" ]]; then
  echo "ERROR: conda base not found at /pscratch, /project, or \$HOME." >&2
  exit 3
fi

ENV_PREFIX="/scratch/$USER/gtdbtk_env"
if [[ ! -x "$ENV_PREFIX/bin/iqtree2" || ! -x "$ENV_PREFIX/bin/gotree" ]]; then
  conda create -y -p "$ENV_PREFIX" --override-channels -c conda-forge -c bioconda \
    iqtree=2.* gotree
fi

RUN="conda run -p $ENV_PREFIX"
THR="${SLURM_CPUS_PER_TASK:-8}"

build_one_tree() {
  local marker="$1"
  local msa_gz=""

  if [[ -f "$ALIGN_DIR/gtdbtk.${marker}.user_msa.fasta.gz" ]]; then
    msa_gz="$ALIGN_DIR/gtdbtk.${marker}.user_msa.fasta.gz"
  elif [[ -f "$ALIGN_DIR/gtdbtk.${marker}.msa.fasta.gz" ]]; then
    msa_gz="$ALIGN_DIR/gtdbtk.${marker}.msa.fasta.gz"
  else
    echo "WARN: No MSA found for marker '${marker}' in $ALIGN_DIR. Skipping ${marker} tree." >&2
    return 0
  fi

  local msa_aa="$OUT/${marker}_user.aa.fasta"
  local prefix="$OUT/${marker}_user"
  local mid_nwk="${prefix}.mid.nwk"

  echo "[INFO] Building ${marker} tree from: $msa_gz"
  gunzip -c "$msa_gz" > "$msa_aa"

  local nseq
  nseq="$(grep -c '^>' "$msa_aa" || true)"
  echo "[INFO] ${marker} sequences in MSA: $nseq"
  if [[ "${nseq:-0}" -lt 2 ]]; then
    echo "WARN: ${marker} has <2 sequences; cannot infer a tree. Skipping." >&2
    return 0
  fi

  "$RUN" iqtree2 -s "$msa_aa" -st AA -m MFP -B 1000 --alrt 1000 -T "$THR" -pre "$prefix"
  "$RUN" gotree reroot midpoint -i "${prefix}.treefile" -o "$mid_nwk"

  echo "[INFO] Outputs for ${marker}:"
  echo "  - $msa_aa"
  echo "  - ${prefix}.treefile"
  echo "  - ${mid_nwk}"
}

echo "[INFO] ALIGN_DIR: $ALIGN_DIR"
echo "[INFO] OUT: $OUT"
build_one_tree "bac120"
build_one_tree "ar53"

echo "[INFO] Done."
