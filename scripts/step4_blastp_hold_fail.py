#!/usr/bin/env python3
"""
Step 4: Run BLASTp for HOLD/FAIL genes and summarize best hits.
"""

from __future__ import annotations

import argparse
import csv
import logging
import shutil
import subprocess
from collections import defaultdict
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Set, Tuple


def ensure_blastp_available() -> None:
    if shutil.which("blastp") is None:
        raise SystemExit("ERROR: blastp not found in PATH.")


def check_blast_db(db_prefix: Path) -> None:
    needed = [db_prefix.with_suffix(ext) for ext in [".pin", ".psq", ".phr"]]
    if not all(p.exists() for p in needed):
        missing = [str(p) for p in needed if not p.exists()]
        raise SystemExit(
            "ERROR: BLAST database files missing. Expected .pin/.psq/.phr.\n"
            f"Missing: {', '.join(missing)}"
        )


def parse_pfam_gene_table(path: Path) -> Tuple[Dict[Tuple[str, str], Dict[str, str]], Set[str]]:
    info: Dict[Tuple[str, str], Dict[str, str]] = {}
    missing_fields: Set[str] = set()
    with path.open("r", encoding="utf-8", errors="replace", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        if reader.fieldnames is None:
            raise SystemExit(f"ERROR: No header found in {path}")
        required = {"metabolism", "MAG_ID", "step", "KEGG_ko", "query", "protein_length_aa", "label"}
        missing_fields = required - set(reader.fieldnames)
        if missing_fields:
            raise SystemExit(f"ERROR: Missing columns in pfam table: {', '.join(sorted(missing_fields))}")

        for row in reader:
            label = (row.get("label") or "").strip()
            if label not in {"HOLD", "FAIL"}:
                continue
            mag_id = (row.get("MAG_ID") or "").strip()
            query = (row.get("query") or "").strip()
            if not mag_id or not query:
                continue

            key = (mag_id, query)
            if key not in info:
                info[key] = {
                    "metabolism": row.get("metabolism", "").strip(),
                    "MAG_ID": mag_id,
                    "query": query,
                    "label": label,
                    "protein_length_aa": row.get("protein_length_aa", "").strip(),
                    "steps": set(),
                    "kos": set(),
                }
            # Merge steps/KOs across duplicates
            step = (row.get("step") or "").strip()
            ko = (row.get("KEGG_ko") or "").strip()
            if step:
                info[key]["steps"].add(step)
            if ko:
                info[key]["kos"].add(ko)
            # Preserve HOLD over FAIL if mixed
            if info[key]["label"] != "HOLD" and label == "HOLD":
                info[key]["label"] = "HOLD"

    return info, missing_fields


def parse_fasta(path: Path) -> Dict[str, str]:
    seqs: Dict[str, str] = {}
    current_id: Optional[str] = None
    current_seq: List[str] = []

    def flush() -> None:
        nonlocal current_id, current_seq
        if current_id is None:
            return
        seqs[current_id] = "".join(current_seq).rstrip("*")
        current_id = None
        current_seq = []

    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            line = line.rstrip("\n")
            if line.startswith(">"):
                flush()
                current_id = line[1:].split()[0]
                current_seq = []
            else:
                current_seq.append(line.strip())
        flush()

    return seqs


def write_queries_faa(
    queries: Dict[Tuple[str, str], Dict[str, str]],
    bakta_root: Path,
    out_faa: Path,
    missing_path: Path,
) -> Tuple[int, int]:
    out_faa.parent.mkdir(parents=True, exist_ok=True)
    missing_path.parent.mkdir(parents=True, exist_ok=True)

    found = 0
    missing = 0

    with out_faa.open("w", encoding="utf-8") as out_fh, missing_path.open(
        "w", encoding="utf-8", newline=""
    ) as miss_fh:
        miss_writer = csv.writer(miss_fh, delimiter="\t")
        miss_writer.writerow(["MAG_ID", "query"])

        mags = defaultdict(list)
        for (mag_id, query), meta in queries.items():
            mags[mag_id].append(query)

        for mag_id, query_list in mags.items():
            faa_path = bakta_root / mag_id / f"{mag_id}.faa"
            if not faa_path.exists():
                for query in query_list:
                    miss_writer.writerow([mag_id, query])
                    missing += 1
                continue

            seqs = parse_fasta(faa_path)
            for query in query_list:
                seq = seqs.get(query)
                if not seq:
                    miss_writer.writerow([mag_id, query])
                    missing += 1
                    continue
                out_fh.write(f">{mag_id}|{query}\n")
                for i in range(0, len(seq), 60):
                    out_fh.write(seq[i : i + 60] + "\n")
                found += 1

    return found, missing


def run_blastp(
    query_faa: Path,
    db_prefix: Path,
    out_path: Path,
    cpu: int,
    evalue: float,
    max_target_seqs: int,
) -> None:
    cmd = [
        "blastp",
        "-query",
        str(query_faa),
        "-db",
        str(db_prefix),
        "-num_threads",
        str(cpu),
        "-evalue",
        str(evalue),
        "-max_target_seqs",
        str(max_target_seqs),
        "-outfmt",
        "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle qcovs",
        "-out",
        str(out_path),
    ]
    try:
        subprocess.run(cmd, check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as exc:
        err = exc.stderr.strip() if exc.stderr else "blastp failed with no stderr"
        raise SystemExit(f"ERROR: blastp failed: {err}") from exc


def load_blast_hits(path: Path) -> Dict[str, List[Dict[str, str]]]:
    hits: Dict[str, List[Dict[str, str]]] = defaultdict(list)
    if not path.exists():
        return hits
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            if not line.strip():
                continue
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 13:
                continue
            qseqid = parts[0]
            hits[qseqid].append(
                {
                    "sseqid": parts[1],
                    "pident": float(parts[2]),
                    "length": int(parts[3]),
                    "evalue": float(parts[10]),
                    "bitscore": float(parts[11]),
                    "stitle": parts[12],
                    "qcovs": float(parts[13]) if len(parts) > 13 else 0.0,
                }
            )
    return hits


def best_hit(hits: List[Dict[str, str]]) -> Optional[Dict[str, str]]:
    if not hits:
        return None
    return sorted(hits, key=lambda h: (h["evalue"], -h["bitscore"]))[0]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run BLASTp for HOLD/FAIL queries and summarize best hits."
    )
    parser.add_argument(
        "--pfam_gene_tsv",
        default="FASTQ/fastq_files/36.functionalprofiling/pfam_validation_gene_level.tsv",
        help="Pfam gene-level TSV.",
    )
    parser.add_argument(
        "--bakta_root",
        default="FASTQ/fastq_files/11.bakta/results",
        help="Root directory containing Bakta results.",
    )
    parser.add_argument(
        "--outdir",
        default="FASTQ/fastq_files/37.blastp_hold_fail",
        help="Output directory for BLASTp results.",
    )
    parser.add_argument("--db", required=True, help="BLAST protein database prefix.")
    parser.add_argument("--cpu", type=int, default=8, help="Threads for blastp.")
    parser.add_argument("--max_target_seqs", type=int, default=10, help="Max targets.")
    parser.add_argument("--evalue", type=float, default=1e-5, help="E-value cutoff.")
    parser.add_argument("--min_qcov", type=float, default=0.70, help="Min query coverage.")
    parser.add_argument("--min_pident", type=float, default=50, help="Min percent identity.")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite outputs.")

    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    ensure_blastp_available()

    pfam_gene_tsv = Path(args.pfam_gene_tsv)
    bakta_root = Path(args.bakta_root)
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    db_prefix = Path(args.db)
    check_blast_db(db_prefix)

    queries, _ = parse_pfam_gene_table(pfam_gene_tsv)
    logging.info("Unique HOLD/FAIL queries: %d", len(queries))

    queries_faa = outdir / "queries_hold_fail.faa"
    missing_path = outdir / "missing_queries.tsv"
    if not queries_faa.exists() or args.overwrite:
        found, missing = write_queries_faa(queries, bakta_root, queries_faa, missing_path)
    else:
        found = sum(1 for _ in queries_faa.open("r", encoding="utf-8") if _.startswith(">"))
        missing = 0

    logging.info("Missing sequences: %d", missing)

    blast_out = outdir / "blastp_hits.tsv"
    if not blast_out.exists() or args.overwrite:
        run_blastp(
            queries_faa,
            db_prefix,
            blast_out,
            args.cpu,
            args.evalue,
            args.max_target_seqs,
        )

    hits_by_query = load_blast_hits(blast_out)

    summary_path = outdir / "blastp_hold_fail_summary.tsv"
    good = weak = no_hit = 0
    with summary_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(
            [
                "metabolism",
                "MAG_ID",
                "query",
                "label",
                "protein_length_aa",
                "steps",
                "KOs",
                "best_hit_sseqid",
                "best_hit_pident",
                "best_hit_qcovs",
                "best_hit_length",
                "best_hit_evalue",
                "best_hit_bitscore",
                "best_hit_stitle",
                "hit_quality_label",
            ]
        )

        for (mag_id, query), meta in sorted(queries.items()):
            qseqid = f"{mag_id}|{query}"
            hits = hits_by_query.get(qseqid, [])
            best = best_hit(hits)
            if best is None:
                hit_label = "NO_HIT"
                no_hit += 1
                writer.writerow(
                    [
                        meta["metabolism"],
                        mag_id,
                        query,
                        meta["label"],
                        meta["protein_length_aa"],
                        ";".join(sorted(meta["steps"])),
                        ";".join(sorted(meta["kos"])),
                        "",
                        "",
                        "",
                        "",
                        "",
                        "",
                        "",
                        hit_label,
                    ]
                )
                continue

            qcovs = best["qcovs"]
            pident = best["pident"]
            if qcovs >= args.min_qcov * 100 and pident >= args.min_pident:
                hit_label = "GOOD"
                good += 1
            else:
                hit_label = "WEAK"
                weak += 1

            writer.writerow(
                [
                    meta["metabolism"],
                    mag_id,
                    query,
                    meta["label"],
                    meta["protein_length_aa"],
                    ";".join(sorted(meta["steps"])),
                    ";".join(sorted(meta["kos"])),
                    best["sseqid"],
                    f"{pident:.2f}",
                    f"{qcovs:.2f}",
                    best["length"],
                    f"{best['evalue']:.2e}",
                    f"{best['bitscore']:.2f}",
                    best["stitle"],
                    hit_label,
                ]
            )

    logging.info("Queries with GOOD hits: %d", good)
    logging.info("Queries with WEAK hits: %d", weak)
    logging.info("Queries with NO_HIT: %d", no_hit)
    logging.info("Wrote: %s", summary_path)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
