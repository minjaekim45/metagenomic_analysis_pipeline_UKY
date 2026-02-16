#!/usr/bin/env python3
"""
Generate per-MAG evidence CSVs by combining eggNOG KO hits with Bakta GFF3/FAA.
"""

from __future__ import annotations

import argparse
import csv
import logging
import re
from collections import defaultdict
from pathlib import Path
from typing import Dict, Iterable, List, Set, Tuple


KO_RE = re.compile(r"K\d{5}")
PFAM_RE = re.compile(r"PFAM:(PF\d{5})(?:\.\d+)?")


def normalize_header(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.strip().lower()).strip("_")


def parse_kos(value: str) -> Set[str]:
    if not value:
        return set()
    kos: Set[str] = set()
    for token in value.split(","):
        token = token.strip()
        if not token or token == "-":
            continue
        token = token.replace("ko:", "")
        kos.update(KO_RE.findall(token))
    return kos


def read_gene_set_tsv(
    path: Path, metabolisms: Set[str]
) -> Tuple[Dict[str, Dict[str, Set[str]]], Dict[str, Dict[str, Set[str]]]]:
    ko_map: Dict[str, Dict[str, Set[str]]] = defaultdict(lambda: defaultdict(set))
    product_map: Dict[str, Dict[str, Set[str]]] = defaultdict(lambda: defaultdict(set))
    metabolisms_norm = {m.strip().lower() for m in metabolisms}

    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.reader(handle, delimiter="\t")
        try:
            header = next(reader)
        except StopIteration as exc:
            raise ValueError(f"Gene-set TSV is empty: {path}") from exc

        norm = [normalize_header(col) for col in header]
        try:
            metabolism_idx = norm.index("metabolism")
            step_idx = norm.index("step")
            ko_idx = norm.index("kegg_ko")
            product_idx = norm.index("product")
        except ValueError as exc:
            raise ValueError(
                "Gene-set TSV missing required columns: Metabolism, Step, KEGG_ko, Product"
            ) from exc

        for row in reader:
            if not row or all(not cell.strip() for cell in row):
                continue
            if len(row) <= max(metabolism_idx, step_idx, ko_idx):
                continue

            metabolism_raw = row[metabolism_idx].strip()
            if not metabolism_raw:
                continue
            metabolism = metabolism_raw.lower()
            if metabolism not in metabolisms_norm:
                continue

            step_id = str(row[step_idx]).strip()
            if not step_id:
                continue

            kos = parse_kos(row[ko_idx])
            product = row[product_idx].strip()
            if kos:
                ko_map[metabolism][step_id].update(kos)
                if product:
                    for ko in kos:
                        product_map[metabolism][ko].add(product)
            else:
                ko_map[metabolism][step_id] = ko_map[metabolism][step_id]

    return ko_map, product_map


def read_candidate_mags(path: Path) -> List[str]:
    mags: List[str] = []
    with path.open() as handle:
        for line in handle:
            mag = line.strip()
            if mag:
                mags.append(mag)
    return mags


def parse_eggnog_hits(
    path: Path, ko_to_steps: Dict[str, Set[str]]
) -> Dict[str, Set[Tuple[str, str]]]:
    hits: Dict[str, Set[Tuple[str, str]]] = defaultdict(set)
    header: List[str] | None = None
    query_idx: int | None = None
    ko_idx: int | None = None

    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            if line.startswith("##"):
                continue
            if line.startswith("#query"):
                header = line.lstrip("#").rstrip("\n").split("\t")
                norm = [normalize_header(col) for col in header]
                if "query" in norm:
                    query_idx = norm.index("query")
                if "kegg_ko" in norm:
                    ko_idx = norm.index("kegg_ko")
                if query_idx is None or ko_idx is None:
                    return hits
                continue
            if line.startswith("#"):
                continue

            if header is None or query_idx is None or ko_idx is None:
                continue

            parts = line.rstrip("\n").split("\t")
            if len(parts) <= max(query_idx, ko_idx):
                continue

            query = parts[query_idx].strip()
            if not query:
                continue

            kos = parse_kos(parts[ko_idx])
            for ko in kos:
                for step_id in ko_to_steps.get(ko, set()):
                    hits[query].add((step_id, ko))

    return hits


def parse_bakta_gff3(path: Path) -> Dict[str, Dict[str, str]]:
    info: Dict[str, Dict[str, str]] = {}
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            if not line or line.startswith("#"):
                continue
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 9:
                continue
            if parts[2] != "CDS":
                continue
            attrs = parts[8]
            attr_map = {}
            for item in attrs.split(";"):
                if "=" in item:
                    key, val = item.split("=", 1)
                    attr_map[key] = val
            gff_id = attr_map.get("ID", "").strip()
            if not gff_id:
                continue

            product = attr_map.get("product", "").strip()
            dbxref = attr_map.get("Dbxref", "")
            pfams = sorted(set(match.group(1) for match in PFAM_RE.finditer(dbxref)))
            info[gff_id] = {
                "product": product,
                "pfams": ";".join(pfams),
            }
    return info


def parse_faa_lengths(path: Path) -> Dict[str, int]:
    lengths: Dict[str, int] = {}
    current_id = None
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


def write_rows(
    path: Path, rows: Iterable[Tuple[str, str, str, str, str, str, str]]
) -> int:
    path.parent.mkdir(parents=True, exist_ok=True)
    unique_rows = sorted(set(rows))
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(
            [
                "step",
                "KEGG_ko",
                "gene_set_product",
                "query",
                "bakta_product",
                "bakta_PFAM",
                "protein_length_aa",
            ]
        )
        writer.writerows(unique_rows)
    return len(unique_rows)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Extract KO evidence for candidate MAGs using eggNOG and Bakta."
    )
    parser.add_argument(
        "--gene_set_tsv",
        default="scripts/gene_sets_step1.tsv",
        help="Path to gene-set TSV (default: scripts/gene_sets_step1.tsv)",
    )
    parser.add_argument(
        "--candidate_dir",
        default="FASTQ/fastq_files/Step1_functional_profiling",
        help="Directory with candidate_mags_{metabolism}.txt files.",
    )
    parser.add_argument(
        "--eggnog_root",
        default="FASTQ/fastq_files/34.eggnog",
        help="Root directory containing eggNOG annotations.",
    )
    parser.add_argument(
        "--bakta_root",
        default="FASTQ/fastq_files/11.bakta/results",
        help="Root directory containing Bakta results.",
    )
    parser.add_argument(
        "--out_root",
        default="FASTQ/fastq_files/36.functionalprofiling",
        help="Output root directory for evidence CSVs.",
    )
    parser.add_argument(
        "--metabolisms",
        default="propionate,butyrate,acetate",
        help="Comma-separated metabolism names to evaluate.",
    )

    args = parser.parse_args()

    metabolisms = {m.strip().lower() for m in args.metabolisms.split(",") if m.strip()}
    if not metabolisms:
        raise ValueError("No metabolisms specified.")

    gene_set_path = Path(args.gene_set_tsv)
    candidate_dir = Path(args.candidate_dir)
    eggnog_root = Path(args.eggnog_root)
    bakta_root = Path(args.bakta_root)
    out_root = Path(args.out_root)

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    logging.info("Reading gene-set TSV: %s", gene_set_path)
    ko_map, product_map = read_gene_set_tsv(gene_set_path, metabolisms)

    summary = {}

    for metabolism in sorted(metabolisms):
        candidate_path = candidate_dir / f"candidate_mags_{metabolism}.txt"
        if not candidate_path.exists():
            logging.warning("Missing candidate list: %s", candidate_path)
            continue

        mags = read_candidate_mags(candidate_path)
        if not mags:
            logging.warning("No candidate MAGs for %s", metabolism)
            continue

        ko_to_steps: Dict[str, Set[str]] = defaultdict(set)
        for step_id, kos in ko_map.get(metabolism, {}).items():
            for ko in kos:
                ko_to_steps[ko].add(step_id)

        total_ko_hit_genes = 0
        missing_in_gff3 = 0
        missing_in_faa = 0
        total_rows = 0

        for mag_id in mags:
            eggnog_path = eggnog_root / mag_id / f"{mag_id}.eggnog.emapper.annotations"
            gff3_path = bakta_root / mag_id / f"{mag_id}.gff3"
            faa_path = bakta_root / mag_id / f"{mag_id}.faa"

            if not eggnog_path.exists() or not gff3_path.exists() or not faa_path.exists():
                logging.warning(
                    "Skipping %s (missing file): eggnog=%s gff3=%s faa=%s",
                    mag_id,
                    eggnog_path.exists(),
                    gff3_path.exists(),
                    faa_path.exists(),
                )
                continue

            eggnog_hits = parse_eggnog_hits(eggnog_path, ko_to_steps)
            if not eggnog_hits:
                continue

            gff_info = parse_bakta_gff3(gff3_path)
            faa_lengths = parse_faa_lengths(faa_path)

            rows: List[Tuple[str, str, str, str, str, str, str]] = []

            for query_id, hit_pairs in eggnog_hits.items():
                total_ko_hit_genes += 1
                product = ""
                pfams = ""
                if query_id in gff_info:
                    product = gff_info[query_id]["product"]
                    pfams = gff_info[query_id]["pfams"]
                else:
                    missing_in_gff3 += 1

                length = ""
                if query_id in faa_lengths:
                    length = str(faa_lengths[query_id])
                else:
                    missing_in_faa += 1

                for step_id, ko in hit_pairs:
                    products = sorted(product_map.get(metabolism, {}).get(ko, set()))
                    gene_set_product = ";".join(products)
                    rows.append(
                        (step_id, ko, gene_set_product, query_id, product, pfams, length)
                    )

            out_path = out_root / metabolism / f"{mag_id}.csv"
            total_rows += write_rows(out_path, rows)

        summary[metabolism] = {
            "total_ko_hit_genes": total_ko_hit_genes,
            "missing_in_gff3": missing_in_gff3,
            "missing_in_faa": missing_in_faa,
            "total_output_rows": total_rows,
        }

    for metabolism, counts in summary.items():
        logging.info(
            "%s: total KO-hit genes=%d, missing_in_gff3=%d, missing_in_faa=%d, total rows=%d",
            metabolism,
            counts["total_ko_hit_genes"],
            counts["missing_in_gff3"],
            counts["missing_in_faa"],
            counts["total_output_rows"],
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
