#!/usr/bin/env python3
"""
First-pass screening of candidate MAGs based on KO step coverage.

This script scans eggNOG emapper annotations, matches KOs to the provided
gene-set TSV (metabolism -> step -> KOs), and reports candidate MAGs that
cover a threshold fraction of steps per metabolism.
"""

from __future__ import annotations

import argparse
import csv
import logging
import math
import re
from collections import defaultdict
from pathlib import Path
from typing import Dict, Iterable, List, Set, Tuple


KO_RE = re.compile(r"K\d{5}")


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
        for match in KO_RE.findall(token):
            kos.add(match)
    return kos


def read_gene_set_tsv(
    path: Path, metabolisms: Set[str]
) -> Tuple[Dict[str, List[str]], Dict[str, Dict[str, Set[str]]]]:
    steps_order: Dict[str, List[str]] = defaultdict(list)
    ko_map: Dict[str, Dict[str, Set[str]]] = defaultdict(lambda: defaultdict(set))

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
        except ValueError as exc:
            raise ValueError(
                "Gene-set TSV missing required columns: Metabolism, Step, KEGG_ko"
            ) from exc

        for row in reader:
            if not row or all(not cell.strip() for cell in row):
                continue
            if len(row) <= max(metabolism_idx, step_idx, ko_idx):
                continue

            metabolism = row[metabolism_idx].strip()
            if not metabolism or metabolism not in metabolisms:
                continue

            step_id = str(row[step_idx]).strip()
            if not step_id:
                continue

            if step_id not in ko_map[metabolism]:
                steps_order[metabolism].append(step_id)

            kos = parse_kos(row[ko_idx])
            if kos:
                ko_map[metabolism][step_id].update(kos)
            else:
                # Keep empty steps to preserve total step count
                ko_map[metabolism][step_id] = ko_map[metabolism][step_id]

    return steps_order, ko_map


def discover_eggnog_annotations(eggnog_root: Path) -> Dict[str, List[Path]]:
    mag_files: Dict[str, List[Path]] = defaultdict(list)
    for path in eggnog_root.rglob("*.eggnog.emapper.annotations"):
        mag_id = path.name.replace(".eggnog.emapper.annotations", "")
        mag_files[mag_id].append(path)
    return mag_files


def parse_eggnog_kos(path: Path) -> Set[str]:
    kos: Set[str] = set()
    header: List[str] | None = None
    ko_idx: int | None = None

    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            if line.startswith("##"):
                continue
            if line.startswith("#query"):
                header = line.lstrip("#").rstrip("\n").split("\t")
                norm = [normalize_header(col) for col in header]
                if "kegg_ko" in norm:
                    ko_idx = norm.index("kegg_ko")
                else:
                    return set()
                continue
            if line.startswith("#"):
                continue

            if header is None or ko_idx is None:
                continue

            parts = line.rstrip("\n").split("\t")
            if len(parts) <= ko_idx:
                continue
            kos.update(parse_kos(parts[ko_idx]))

    return kos


def compute_requirements(total_steps: int, threshold: float) -> int:
    if total_steps <= 0:
        return 0
    return int(math.ceil(total_steps * threshold))


def write_candidates(outdir: Path, metabolism: str, mags: Iterable[str]) -> None:
    outpath = outdir / f"candidate_mags_{metabolism.lower()}.txt"
    with outpath.open("w", encoding="utf-8") as handle:
        for mag_id in sorted(mags):
            handle.write(f"{mag_id}\n")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Screen candidate MAGs based on KO step coverage per metabolism."
    )
    parser.add_argument(
        "--gene_set_tsv",
        default="scripts/gene_sets_step1.tsv",
        help="Path to gene-set TSV (default: scripts/gene_sets_step1.tsv)",
    )
    parser.add_argument(
        "--eggnog_root",
        default="FASTQ/fastq_files/34.eggnog",
        help="Root directory containing eggNOG annotations.",
    )
    parser.add_argument(
        "--outdir",
        default="FASTQ/fastq_files/36.functionalprofiling",
        help="Output directory for candidate lists and summary TSV.",
    )
    parser.add_argument(
        "--metabolisms",
        default="Propionate,Butyrate,Acetate",
        help="Comma-separated metabolism names to evaluate.",
    )
    parser.add_argument(
        "--threshold",
        type=float,
        default=0.75,
        help="Fraction of steps required to pass (default: 0.75).",
    )
    parser.add_argument(
        "--thresholds",
        default="",
        help=(
            "Optional per-metabolism thresholds, e.g. "
            "'Acetate=0.75,Butyrate=1.0,Propionate=1.0'. "
            "Overrides --threshold when provided."
        ),
    )
    parser.add_argument(
        "--gene_presence_threshold",
        type=float,
        default=0.5,
        help=(
            "Required fraction of metabolism KOs that must be present. "
            "Passes only when present_required_genes / total_required_genes "
            "is strictly greater than this value (default: 0.5)."
        ),
    )

    args = parser.parse_args()

    metabolisms = {m.strip() for m in args.metabolisms.split(",") if m.strip()}
    if not metabolisms:
        raise ValueError("No metabolisms specified.")

    thresholds: Dict[str, float] = {}
    if args.thresholds.strip():
        for item in args.thresholds.split(","):
            if not item.strip():
                continue
            if "=" not in item:
                raise ValueError(
                    f"Invalid --thresholds entry '{item}'. Use Metabolism=0.75 format."
                )
            name, val = item.split("=", 1)
            name = name.strip()
            try:
                thresholds[name] = float(val.strip())
            except ValueError as exc:
                raise ValueError(
                    f"Invalid threshold value in --thresholds: '{item}'."
                ) from exc

    gene_set_path = Path(args.gene_set_tsv)
    eggnog_root = Path(args.eggnog_root)
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    logging.basicConfig(
        level=logging.INFO,
        format="%(levelname)s: %(message)s",
    )

    logging.info("Reading gene-set TSV: %s", gene_set_path)
    steps_order, ko_map = read_gene_set_tsv(gene_set_path, metabolisms)

    # Precompute union of KOs per metabolism for reporting
    ko_union: Dict[str, Set[str]] = {}
    for metabolism, steps in ko_map.items():
        union = set()
        for step_id in steps:
            union.update(ko_map[metabolism][step_id])
        ko_union[metabolism] = union

    logging.info("Scanning eggNOG annotations under: %s", eggnog_root)
    mag_files = discover_eggnog_annotations(eggnog_root)
    logging.info("Found %d MAGs with annotations", len(mag_files))

    summary_path = outdir / "mag_step_coverage_summary.tsv"
    summary_rows = []
    candidates: Dict[str, Set[str]] = {m: set() for m in metabolisms}

    for mag_id, paths in sorted(mag_files.items()):
        mag_kos: Set[str] = set()
        for path in paths:
            mag_kos.update(parse_eggnog_kos(path))

        for metabolism in sorted(metabolisms):
            threshold = thresholds.get(metabolism, args.threshold)
            total_steps = len(steps_order.get(metabolism, []))
            required_steps = compute_requirements(total_steps, threshold)

            covered_steps = []
            for step_id in steps_order.get(metabolism, []):
                step_kos = ko_map[metabolism][step_id]
                if step_kos and step_kos.intersection(mag_kos):
                    covered_steps.append(step_id)

            covered_count = len(covered_steps)
            coverage_fraction = (
                covered_count / total_steps if total_steps > 0 else 0.0
            )
            step_rule_pass = covered_count >= required_steps and covered_count >= 1

            matched_kos = sorted(ko_union.get(metabolism, set()).intersection(mag_kos))
            total_required_genes = len(ko_union.get(metabolism, set()))
            present_required_genes = len(matched_kos)
            gene_presence_fraction = (
                present_required_genes / total_required_genes
                if total_required_genes > 0
                else 0.0
            )
            gene_rule_pass = (
                total_required_genes > 0
                and gene_presence_fraction > args.gene_presence_threshold
            )
            is_candidate = int(step_rule_pass and gene_rule_pass)

            if is_candidate:
                candidates[metabolism].add(mag_id)

            summary_rows.append(
                {
                    "MAG_ID": mag_id,
                    "metabolism": metabolism,
                    "total_steps": total_steps,
                    "covered_steps": covered_count,
                    "required_steps": required_steps,
                    "step_coverage_fraction": f"{coverage_fraction:.4f}",
                    "total_required_genes": total_required_genes,
                    "present_required_genes": present_required_genes,
                    "gene_presence_fraction": f"{gene_presence_fraction:.4f}",
                    "is_candidate": is_candidate,
                    "covered_step_ids": ",".join(covered_steps),
                    "matched_kos": ",".join(matched_kos),
                }
            )

    logging.info("Writing summary: %s", summary_path)
    with summary_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "MAG_ID",
                "metabolism",
                "total_steps",
                "covered_steps",
                "required_steps",
                "step_coverage_fraction",
                "total_required_genes",
                "present_required_genes",
                "gene_presence_fraction",
                "is_candidate",
                "covered_step_ids",
                "matched_kos",
            ],
            delimiter="\t",
        )
        writer.writeheader()
        writer.writerows(summary_rows)

    for metabolism, mags in candidates.items():
        write_candidates(outdir, metabolism, mags)
        logging.info(
            "Metabolism %s: %d candidates",
            metabolism,
            len(mags),
        )

    logging.info("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
