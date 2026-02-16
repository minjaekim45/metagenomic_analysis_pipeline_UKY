#!/bin/bash
#SBATCH --time=24:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=Functional_profiling_step4           # Job name
#SBATCH --ntasks=4                  # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e 37.Blastp_hold_fail-step4-%j.err             # Error file for this job.
#SBATCH -o 37.Blastp_hold_fail-step4-%j.out             # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)
#SBATCH --mem=10G

set -euo pipefail

source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh
conda activate python

# Download/update BLAST DB (skip existing tarballs)
cd databases/blastdb/
if ! command -v update_blastdb.pl >/dev/null 2>&1; then
  echo "ERROR: update_blastdb.pl not found in PATH."
  exit 1
fi

# Download or update the DB (will skip already-downloaded parts)
update_blastdb.pl --decompress refseq_protein

# Ensure tarballs are extracted to produce .pin/.psq/.phr
for tarball in refseq_protein.*.tar.gz; do
  [ -f "${tarball}" ] || continue
  base="${tarball%.tar.gz}"
  if [ -f "${base}.pin" ] && [ -f "${base}.psq" ] && [ -f "${base}.phr" ]; then
    continue
  fi
  tar -xzf "${tarball}"
done

cd - >/dev/null

# Update this path to your BLAST protein database prefix
BLAST_DB="databases/blastdb/refseq_protein"

python3 scripts/step4_blastp_hold_fail.py \
  --pfam_gene_tsv FASTQ/fastq_files/36.functionalprofiling/pfam_validation_gene_level.tsv \
  --bakta_root FASTQ/fastq_files/11.bakta/results \
  --outdir FASTQ/fastq_files/37.blastp_hold_fail \
  --db "${BLAST_DB}" \
  --cpu 8 \
  --max_target_seqs 10 \
  --evalue 1e-5 \
  --min_qcov 0.70 \
  --min_pident 50
