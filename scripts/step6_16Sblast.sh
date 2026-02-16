#!/bin/bash
#SBATCH --time=18:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=16srRNA           # Job name
#SBATCH --ntasks=4                  # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e 38.16srRNA-MAGs-%j.err             # Error file for this job.
#SBATCH -o 36.16srRNA-%j.out             # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)
#SBATCH --mem=10G

set -euo pipefail

source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh
conda activate gtdb_silva

OUT_SILVA="FASTQ/fastq_files/38.16SrRNA/mags_vs_silva.tsv"
OUT_BEST="FASTQ/fastq_files/38.16SrRNA/mags_vs_silva.besthit.tsv"
OUT_TAD80_VS_SILVA="FASTQ/fastq_files/38.16SrRNA/TAD80_vs_SILVA.csv"
TAD80_TABLE="FASTQ/fastq_files/38.16SrRNA/TAD80_classfication.csv"
export OUT_BEST OUT_TAD80_VS_SILVA TAD80_TABLE

EVAL=1e-5
PIDENT=90

blastn \
-task megablast \
-query FASTQ/fastq_files/38.16SrRNA/mags_16S_queries.fasta \
-db databases/SILVAdb/SILVA_138.1_SSURef_NR99_tax_silva_trunc.fasta \
-max_target_seqs 10 \
-evalue ${EVAL} \
-perc_identity ${PIDENT} \
-outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore qlen slen stitle" \
-num_threads 16 \
> "${OUT_SILVA}"

sort -k1,1 -k8,8nr "${OUT_SILVA}" | awk '!seen[$1]++' > "${OUT_BEST}"

python3 - <<'PY'
import csv
import os
from pathlib import Path
from collections import defaultdict

tad_path = Path(os.environ["TAD80_TABLE"])
silva_path = Path(os.environ["OUT_BEST"])
out_path = Path(os.environ["OUT_TAD80_VS_SILVA"])

tad_rows = []
with tad_path.open(newline="") as f:
    reader = csv.DictReader(f)
    for r in reader:
        mag = (r.get("MAG ID") or "").strip()
        clade = (r.get("Clade") or "").strip()
        tad80 = (r.get("classification") or "").strip()
        if mag:
            tad_rows.append((mag, clade, tad80))

silva_by_mag = defaultdict(list)
with silva_path.open() as f:
    for line in f:
        line = line.rstrip("\n")
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        qid = parts[0].strip()
        identity = parts[2].strip()
        silva = parts[-1].strip()
        mag = qid.split("|", 1)[0].strip()
        if mag:
            silva_by_mag[mag].append((identity, silva))

with out_path.open("w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["MAG ID", "Clade", "TAD80", "identity", "SILVA"])
    for mag, clade, tad80 in tad_rows:
        hits = silva_by_mag.get(mag, [])
        if not hits:
            writer.writerow([mag, clade, tad80, "", ""])
            continue
        if len(hits) == 1:
            identity, silva = hits[0]
            writer.writerow([mag, clade, tad80, identity, silva])
            continue
        for i, (identity, silva) in enumerate(hits, start=1):
            writer.writerow([mag, f"{clade}-{i}" if clade else "", tad80, identity, silva])
PY
