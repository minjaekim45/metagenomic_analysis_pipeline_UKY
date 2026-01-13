#!/bin/bash
#SBATCH --time=2-00:00:00
#SBATCH --job-name=featureCounts_all
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --partition=normal
#SBATCH --account=coa_mki314_uksr
#SBATCH -o ./zz.out/featureCounts_all-%j.out
#SBATCH -e ./zz.out/featureCounts_all-%j.err

set -euo pipefail

# ======================
# Paths / settings
# ======================
BASE="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files"

BAKTA_DIR="$BASE/11.bakta/results_keepHeaders"
BAM_DIR="$BASE/29.TAD80/TAD80"
OUT_DIR="$BASE/35.featureCounts"
LOG_DIR="$OUT_DIR/logs"

THREADS="${SLURM_CPUS_PER_TASK:-8}"

mkdir -p "$OUT_DIR" "$LOG_DIR"

# ======================
# Conda activation
# ======================
source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh
conda activate subread   # <-- 네 featureCounts 들어있는 env 이름으로 맞춰

# featureCounts 존재 확인
command -v featureCounts >/dev/null 2>&1 || {
  echo "[ERROR] featureCounts not found in current env. Check conda env (subread)." >&2
  exit 1
}

echo "==[ featureCounts all MAGs: $(date) ]=="
echo "BASE=$BASE"
echo "BAKTA_DIR=$BAKTA_DIR"
echo "BAM_DIR=$BAM_DIR"
echo "OUT_DIR=$OUT_DIR"
echo "LOG_DIR=$LOG_DIR"
echo "THREADS=$THREADS"
echo

# ======================
# Collect GFFs
# ======================
shopt -s nullglob
gffs=("$BAKTA_DIR"/IR37_*/*.gff3)

if [[ ${#gffs[@]} -eq 0 ]]; then
  echo "[ERROR] No GFF3 files found under: $BAKTA_DIR" >&2
  exit 1
fi

echo "[INFO] Found ${#gffs[@]} GFF3 files."

# ======================
# Summary logs
# ======================
LOG_OK="$LOG_DIR/featureCounts.OK.tsv"
LOG_SKIP="$LOG_DIR/featureCounts.SKIP.tsv"
LOG_WARN="$LOG_DIR/featureCounts.WARN.tsv"
: > "$LOG_OK"
: > "$LOG_SKIP"
: > "$LOG_WARN"

# ======================
# Main loop
# ======================
for gff in "${gffs[@]}"; do
  mag="$(basename "$(dirname "$gff")")"   # e.g. IR37_0d.100
  sample="${mag%.*}"                      # e.g. IR37_0d

  bam="$BAM_DIR/${sample}.sorted.bam"

  if [[ ! -s "$bam" ]]; then
    echo -e "${mag}\t${sample}\tBAM_NOT_FOUND\t${bam}" >> "$LOG_WARN"
    continue
  fi

  out_gff="$OUT_DIR/${mag}.forCounts.gff3"
  out_counts="$OUT_DIR/${mag}.gene_counts.txt"
  out_summary="${out_counts}.summary"
  per_mag_log="$LOG_DIR/${mag}.featureCounts.log"

  # Skip if already done
  if [[ -s "$out_counts" && -s "$out_summary" ]]; then
    echo -e "${mag}\t${sample}\tALREADY_DONE\t${out_counts}" >> "$LOG_SKIP"
    continue
  fi

  echo "[RUN] MAG=$mag  SAMPLE=$sample"

  # 1) Make forCounts GFF (prefix contig with MAG:)
  awk -v mag="$mag" '
  BEGIN{FS=OFS="\t"}
  /^##FASTA/ {exit}
  /^#/ {print; next}
  NF>=9 {$1 = mag ":" $1; print; next}
  {print}
  ' "$gff" > "$out_gff"

  # 2) Run featureCounts (paired-end)
  #    Log stdout/stderr into per-MAG log
  if ! featureCounts \
      -T "$THREADS" \
      -p -B -C \
      -a "$out_gff" \
      -o "$out_counts" \
      -t CDS \
      -g ID \
      "$bam" \
      > "$per_mag_log" 2>&1
  then
    echo -e "${mag}\t${sample}\tFEATURECOUNTS_FAILED\tsee:${per_mag_log}" >> "$LOG_WARN"
    continue
  fi

  # 3) Record Assigned
  assigned=$(awk '$1=="Assigned"{print $2}' "$out_summary" | head -n 1)
  assigned=${assigned:-NA}
  echo -e "${mag}\t${sample}\tAssigned=${assigned}\t${out_counts}" >> "$LOG_OK"
done

conda deactivate

echo
echo "==[ Done: $(date) ]=="
echo "OK   : $LOG_OK"
echo "SKIP : $LOG_SKIP"
echo "WARN : $LOG_WARN"
echo "Per-MAG logs: $LOG_DIR/*.featureCounts.log"
