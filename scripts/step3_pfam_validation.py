#!/usr/bin/env python3
"""
Step 3: Validate candidate marker genes using Pfam HMMER hmmscan.
"""

from __future__ import annotations

import argparse
import csv
import logging
import math
import shutil
import subprocess
from collections import defaultdict
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Set, Tuple


def parse_fasta_lengths(path: Path) -> Dict[str, int]:
    lengths: Dict[str, int] = {}
    current_id: Optional[str] = None
    current_seq: List[str] = []

    def flush() -> None:
        nonlocal current_id, current_seq
        if current_id is None:
            return
        seq = "".join(current_seq).rstrip("*")
        lengths[current_id] = len(seq)
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

    return lengths


def write_subset_fasta(
    source_faa: Path, query_ids: Set[str], out_faa: Path
) -> Tuple[int, int]:
    found = 0
    missing = 0
    out_faa.parent.mkdir(parents=True, exist_ok=True)

    with source_faa.open("r", encoding="utf-8", errors="replace") as src, out_faa.open(
        "w", encoding="utf-8"
    ) as out:
        current_id: Optional[str] = None
        current_seq: List[str] = []

        def flush() -> None:
            nonlocal found, missing, current_id, current_seq
            if current_id is None:
                return
            if current_id in query_ids:
                out.write(f">{current_id}\n")
                seq = "".join(current_seq).rstrip("*")
                for i in range(0, len(seq), 60):
                    out.write(seq[i : i + 60] + "\n")
                found += 1
            current_id = None
            current_seq = []

        for line in src:
            line = line.rstrip("\n")
            if line.startswith(">"):
                flush()
                current_id = line[1:].split()[0]
                current_seq = []
            else:
                current_seq.append(line.strip())
        flush()

    missing = len(query_ids) - found
    return found, missing


def parse_domtblout(
    path: Path, query_lengths: Dict[str, int]
) -> Dict[str, List[Dict[str, str]]]:
    hits: Dict[str, List[Dict[str, str]]] = defaultdict(list)
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            if not line or line.startswith("#"):
                continue
            parts = line.rstrip("\n").split()
            if len(parts) < 23:
                continue
            target_name = parts[0]
            target_acc = parts[1]
            tlen = int(parts[2])
            query_name = parts[3]
            # parts[4] is query acc, parts[5] is qlen (use FASTA instead)
            i_evalue = float(parts[12])
            hmm_from = int(parts[15])
            hmm_to = int(parts[16])
            ali_from = int(parts[17])
            ali_to = int(parts[18])

            hmm_len = tlen
            hmm_cov = (abs(hmm_to - hmm_from) + 1) / hmm_len if hmm_len else 0.0
            qlen = query_lengths.get(query_name, 0)
            query_ali_len = abs(ali_to - ali_from) + 1
            query_cov = query_ali_len / qlen if qlen else 0.0

            hits[query_name].append(
                {
                    "pfam_name": target_name,
                    "pfam_acc": target_acc,
                    "i_evalue": i_evalue,
                    "hmm_cov": hmm_cov,
                    "query_cov": query_cov,
                }
            )
    return hits


def label_query(
    hits: List[Dict[str, str]],
    evalue_pass: float,
    cov_pass: float,
    cov_hold: float,
) -> str:
    if not hits:
        return "NO_PFAM"

    qualifying = [h for h in hits if h["i_evalue"] <= evalue_pass]
    if not qualifying:
        return "FAIL"

    if any(h["hmm_cov"] >= cov_pass for h in qualifying):
        return "PASS"
    if any(cov_hold <= h["hmm_cov"] < cov_pass for h in qualifying):
        return "HOLD"
    return "FAIL"


def best_hit(hits: List[Dict[str, str]]) -> Optional[Dict[str, str]]:
    if not hits:
        return None
    return sorted(hits, key=lambda h: h["i_evalue"])[0]


def read_candidate_csv(path: Path) -> List[Dict[str, str]]:
    rows = []
    with path.open("r", encoding="utf-8", errors="replace", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            rows.append(row)
    return rows


def ensure_hmmscan_available() -> None:
    if shutil.which("hmmscan") is None:
        raise SystemExit("ERROR: hmmscan not found in PATH.")


def check_pfam_hmm(path: Path) -> None:
    if not path.exists():
        raise SystemExit(f"ERROR: Pfam HMM not found: {path}")
    # Basic hmmpress presence check
    pressed = [path.with_suffix(path.suffix + ext) for ext in [".h3f", ".h3i", ".h3m", ".h3p"]]
    if not all(p.exists() for p in pressed):
        raise SystemExit(
            f"ERROR: Pfam HMM appears not hmmpress'ed. Run: hmmpress {path}"
        )


def run_hmmscan(
    pfam_hmm: Path, query_faa: Path, domtblout: Path, cpu: int
) -> None:
    cmd = [
        "hmmscan",
        "--cpu",
        str(cpu),
        "--domtblout",
        str(domtblout),
        str(pfam_hmm),
        str(query_faa),
    ]
    try:
        subprocess.run(cmd, check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as exc:
        err = exc.stderr.strip() if exc.stderr else "hmmscan failed with no stderr"
        raise SystemExit(f"ERROR: hmmscan failed: {err}") from exc


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate candidate marker genes using Pfam HMMER hmmscan."
    )
    parser.add_argument("--pfam_hmm", required=True, help="Path to Pfam-A.hmm")
    parser.add_argument(
        "--functional_dir",
        default="FASTQ/fastq_files/36.functionalprofiling",
        help="Root directory with Step 2 evidence CSVs.",
    )
    parser.add_argument(
        "--bakta_root",
        default="FASTQ/fastq_files/11.bakta/results",
        help="Root directory containing Bakta results.",
    )
    parser.add_argument(
        "--metabolisms",
        default="propionate,butyrate,acetate",
        help="Comma-separated metabolism names to evaluate.",
    )
    parser.add_argument("--cpu", type=int, default=8, help="Threads for hmmscan.")
    parser.add_argument("--threshold", type=float, default=0.75, help="Step threshold.")
    parser.add_argument("--evalue_pass", type=float, default=1e-5, help="E-value pass.")
    parser.add_argument("--cov_pass", type=float, default=0.60, help="Coverage pass.")
    parser.add_argument("--cov_hold", type=float, default=0.40, help="Coverage hold.")
    parser.add_argument(
        "--overwrite", action="store_true", help="Overwrite existing domtblout."
    )

    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    ensure_hmmscan_available()

    pfam_hmm = Path(args.pfam_hmm)
    functional_dir = Path(args.functional_dir)
    bakta_root = Path(args.bakta_root)

    check_pfam_hmm(pfam_hmm)

    metabolisms = [m.strip().lower() for m in args.metabolisms.split(",") if m.strip()]
    if not metabolisms:
        raise SystemExit("No metabolisms specified.")

    gene_rows: List[Dict[str, str]] = []
    mag_rows: List[Dict[str, str]] = []

    for metabolism in metabolisms:
        metab_dir = functional_dir / metabolism
        if not metab_dir.exists():
            logging.warning("Missing metabolism directory: %s", metab_dir)
            continue

        csv_paths = sorted(p for p in metab_dir.glob("*.csv"))
        if not csv_paths:
            logging.warning("No CSV files for metabolism %s", metabolism)
            continue

        logging.info("Processing metabolism: %s (%d MAGs)", metabolism, len(csv_paths))

        for csv_path in csv_paths:
            mag_id = csv_path.stem
            logging.info("  MAG: %s", mag_id)

            rows = read_candidate_csv(csv_path)
            if not rows:
                continue

            query_ids = {row["query"] for row in rows if row.get("query")}
            steps = {row["step"] for row in rows if row.get("step")}

            source_faa = bakta_root / mag_id / f"{mag_id}.faa"
            if not source_faa.exists():
                logging.warning("Missing FASTA: %s", source_faa)
                continue

            subset_faa = metab_dir / f"{mag_id}.candidates.faa"
            found, missing = write_subset_fasta(source_faa, query_ids, subset_faa)
            if missing:
                logging.warning("Missing %d queries in FASTA for %s", missing, mag_id)

            domtblout = metab_dir / f"{mag_id}.pfam.domtblout"
            if not domtblout.exists() or args.overwrite:
                run_hmmscan(pfam_hmm, subset_faa, domtblout, args.cpu)

            query_lengths = parse_fasta_lengths(subset_faa)
            dom_hits = parse_domtblout(domtblout, query_lengths)

            query_labels: Dict[str, str] = {}
            for query in query_ids:
                hits = dom_hits.get(query, [])
                query_labels[query] = label_query(
                    hits, args.evalue_pass, args.cov_pass, args.cov_hold
                )

            # Gene-level rows
            for row in rows:
                query = row.get("query", "")
                hits = dom_hits.get(query, [])
                best = best_hit(hits)
                label = query_labels.get(query, "NO_PFAM")
                all_hits = []
                for hit in hits:
                    if hit["i_evalue"] <= args.evalue_pass:
                        all_hits.append(
                            f"{hit['pfam_name']}|{hit['pfam_acc']}|{hit['i_evalue']:.2e}|{hit['hmm_cov']:.3f}"
                        )
                gene_rows.append(
                    {
                        "metabolism": metabolism,
                        "MAG_ID": mag_id,
                        "step": row.get("step", ""),
                        "KEGG_ko": row.get("KEGG_ko", ""),
                        "query": query,
                        "protein_length_aa": row.get("protein_length_aa", ""),
                        "best_pfam_name": best["pfam_name"] if best else "",
                        "best_pfam_acc": best["pfam_acc"] if best else "",
                        "best_i_evalue": f"{best['i_evalue']:.2e}" if best else "",
                        "best_hmm_cov": f"{best['hmm_cov']:.3f}" if best else "",
                        "best_query_cov": f"{best['query_cov']:.3f}" if best else "",
                        "label": label,
                        "all_pfam_hits": ";".join(all_hits),
                    }
                )

            # MAG-level summary
            n_queries = len(query_ids)
            n_pass = sum(1 for q in query_ids if query_labels.get(q) == "PASS")
            n_hold = sum(1 for q in query_ids if query_labels.get(q) == "HOLD")
            n_fail = sum(1 for q in query_ids if query_labels.get(q) == "FAIL")
            n_no = sum(1 for q in query_ids if query_labels.get(q) == "NO_PFAM")

            pass_fraction = n_pass / n_queries if n_queries else 0.0
            hold_fraction = n_hold / n_queries if n_queries else 0.0

            step_to_queries = defaultdict(list)
            for row in rows:
                step_to_queries[row.get("step", "")].append(row.get("query", ""))

            steps_total = len(steps)
            steps_with_pass = 0
            steps_with_hold_or_pass = 0
            for step_id, qs in step_to_queries.items():
                labels = {query_labels.get(q, "NO_PFAM") for q in qs if q}
                if "PASS" in labels:
                    steps_with_pass += 1
                if "PASS" in labels or "HOLD" in labels:
                    steps_with_hold_or_pass += 1

            step_threshold = int(math.ceil(steps_total * args.threshold)) if steps_total else 0
            if steps_with_pass >= step_threshold and steps_total:
                step_label = "CONFIRMED"
            elif steps_with_hold_or_pass >= step_threshold and steps_total:
                step_label = "PUTATIVE"
            else:
                step_label = "NOT_SUPPORTED"

            mag_rows.append(
                {
                    "metabolism": metabolism,
                    "MAG_ID": mag_id,
                    "n_queries": n_queries,
                    "n_pass": n_pass,
                    "n_hold": n_hold,
                    "n_fail": n_fail,
                    "n_no_pfam": n_no,
                    "pass_fraction": f"{pass_fraction:.3f}",
                    "hold_fraction": f"{hold_fraction:.3f}",
                    "steps_total": steps_total,
                    "steps_with_pass": steps_with_pass,
                    "steps_with_hold_or_pass": steps_with_hold_or_pass,
                    "step_validation_label": step_label,
                }
            )

    # Write outputs
    gene_out = functional_dir / "pfam_validation_gene_level.tsv"
    mag_out = functional_dir / "pfam_validation_mag_level.tsv"

    with gene_out.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "metabolism",
                "MAG_ID",
                "step",
                "KEGG_ko",
                "query",
                "protein_length_aa",
                "best_pfam_name",
                "best_pfam_acc",
                "best_i_evalue",
                "best_hmm_cov",
                "best_query_cov",
                "label",
                "all_pfam_hits",
            ],
            delimiter="\t",
        )
        writer.writeheader()
        writer.writerows(gene_rows)

    with mag_out.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "metabolism",
                "MAG_ID",
                "n_queries",
                "n_pass",
                "n_hold",
                "n_fail",
                "n_no_pfam",
                "pass_fraction",
                "hold_fraction",
                "steps_total",
                "steps_with_pass",
                "steps_with_hold_or_pass",
                "step_validation_label",
            ],
            delimiter="\t",
        )
        writer.writeheader()
        writer.writerows(mag_rows)

    logging.info("Wrote: %s", gene_out)
    logging.info("Wrote: %s", mag_out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
