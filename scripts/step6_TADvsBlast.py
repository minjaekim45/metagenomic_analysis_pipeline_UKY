import csv
from collections import defaultdict
from pathlib import Path

tad_path = Path("FASTQ/fastq_files/38.16SrRNA/TAD80_classfication.csv")
silva_path = Path("FASTQ/fastq_files/38.16SrRNA/mags_vs_silva.besthit.tsv")
out_path = Path("FASTQ/fastq_files/38.16SrRNA/TAD80_vs_SILVA.csv")

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
