#!/usr/bin/env python3
"""
Extract 16S rRNA sequences from Bakta outputs.

Steps:
1) Find rows with Type containing "rRNA" and Product containing "16S" in {MAG}.tsv.
2) Get corresponding Locus Tag(s).
3) Pull sequences from {MAG}.ffn by Locus Tag.
4) Write FASTQ/fastq_files/38.16SrRNA/16S_sequence.csv with columns: MAG ID, sequence.
"""

from __future__ import annotations

import csv
from pathlib import Path
from typing import Dict, Iterable, List, Tuple


ROOT = Path("/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY")
RESULTS_DIR = ROOT / "FASTQ/fastq_files/11.bakta/results"
OUT_DIR = ROOT / "FASTQ/fastq_files/38.16SrRNA"
OUT_PATH = OUT_DIR / "16S_sequence.csv"
CLASSIFICATION_PATH = OUT_DIR / "TAD80_classfication.csv"
FASTA_OUT_PATH = OUT_DIR / "mags_16S_queries.fasta"


def parse_tsv_for_locus_tags(tsv_path: Path) -> List[str]:
    locus_tags: List[str] = []
    header: List[str] | None = None

    with tsv_path.open(newline="") as f:
        for line in f:
            if not line.strip():
                continue
            if line.startswith("#"):
                # Capture header line, if present.
                if line.startswith("#Sequence Id"):
                    header = line.lstrip("#").rstrip("\n").split("\t")
                continue
            # First data line implies header already known or fixed order.
            break

    # Re-open for csv parsing
    with tsv_path.open(newline="") as f:
        reader: csv.reader | csv.DictReader
        if header:
            reader = csv.DictReader(
                (line for line in f if line.strip() and not line.startswith("#")),
                fieldnames=header,
                delimiter="\t",
            )
            for row in reader:
                type_val = (row.get("Type") or "")
                product_val = (row.get("Product") or "")
                if "rRNA" in type_val and "16S" in product_val:
                    locus = (row.get("Locus Tag") or "").strip()
                    if locus:
                        locus_tags.append(locus)
        else:
            # Fallback to Bakta TSV column order
            reader = csv.reader(
                (line for line in f if line.strip() and not line.startswith("#")),
                delimiter="\t",
            )
            for row in reader:
                # Expected order:
                # Sequence Id, Type, Start, Stop, Strand, Locus Tag, Gene, Product, DbXrefs
                if len(row) < 8:
                    continue
                type_val = row[1]
                product_val = row[7]
                if "rRNA" in type_val and "16S" in product_val:
                    locus = row[5].strip()
                    if locus:
                        locus_tags.append(locus)

    return locus_tags


def parse_fasta(ffn_path: Path) -> Dict[str, str]:
    sequences: Dict[str, List[str]] = {}
    current_id: str | None = None

    with ffn_path.open() as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            if line.startswith(">"):
                # Use first token as ID
                current_id = line[1:].split(None, 1)[0]
                if current_id not in sequences:
                    sequences[current_id] = []
                continue
            if current_id is None:
                continue
            sequences[current_id].append(line)

    return {k: "".join(v) for k, v in sequences.items()}


def iter_mag_ids(results_dir: Path) -> Iterable[str]:
    for entry in sorted(results_dir.iterdir()):
        if entry.is_dir():
            yield entry.name


def clean_seq(seq: str) -> str:
    seq = (seq or "").upper()
    # Remove whitespace and keep IUPAC DNA codes only.
    cleaned = []
    for ch in seq:
        if ch.isspace():
            continue
        if ch in "ACGTRYSWKMBDHVN":
            cleaned.append(ch)
    return "".join(cleaned)


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    rows: List[Tuple[str, str, str]] = []

    for mag_id in iter_mag_ids(RESULTS_DIR):
        tsv_path = RESULTS_DIR / mag_id / f"{mag_id}.tsv"
        ffn_path = RESULTS_DIR / mag_id / f"{mag_id}.ffn"

        if not tsv_path.exists() or not ffn_path.exists():
            rows.append((mag_id, ""))
            continue

        locus_tags = parse_tsv_for_locus_tags(tsv_path)
        if not locus_tags:
            rows.append((mag_id, ""))
            continue

        seqs = parse_fasta(ffn_path)
        matched_seqs: List[str] = []
        for locus in locus_tags:
            if locus in seqs:
                matched_seqs.append(seqs[locus])

        multiple_matches = 1 if len(matched_seqs) > 1 else 0
        seq = ";".join(matched_seqs)
        rows.append((mag_id, seq, multiple_matches))

    with OUT_PATH.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["MAG ID", "sequence", "multiple_matches"])
        writer.writerows(rows)

    # If classification file exists, build fasta queries from it.
    if CLASSIFICATION_PATH.exists():
        records = 0
        with CLASSIFICATION_PATH.open(newline="") as f, FASTA_OUT_PATH.open("w") as out_f:
            reader = csv.DictReader(f)
            for row in reader:
                mag = (row.get("MAG ID") or "").strip()
                clade = (row.get("Clade") or "").strip()
                raw_seq = row.get("sequence") or ""
                parts = [p.strip() for p in raw_seq.split(";") if p.strip()]
                if not parts:
                    continue
                for idx, part in enumerate(parts, 1):
                    seq = clean_seq(part)
                    if not seq:
                        continue
                    suffix = f"-{idx}" if len(parts) > 1 else ""
                    out_f.write(f">{mag}|Clade={clade}{suffix}\n")
                    for i in range(0, len(seq), 80):
                        out_f.write(seq[i : i + 80] + "\n")
                    records += 1
        print(f"Wrote: {FASTA_OUT_PATH} records: {records}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
