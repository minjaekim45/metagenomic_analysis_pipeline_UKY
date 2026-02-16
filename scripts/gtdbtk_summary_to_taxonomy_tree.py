#!/usr/bin/env python3
"""Build a taxonomy hierarchy tree (Newick) from GTDB-Tk summary TSV."""

import argparse
import csv
import re
from collections import OrderedDict
from pathlib import Path

RANKS = ("d", "p", "c", "o", "f", "g", "s")


class Node:
    def __init__(self, name):
        self.name = name
        self.children = OrderedDict()
        self.leaves = OrderedDict()


def sanitize_label(label):
    label = label.strip()
    label = re.sub(r"\s+", "_", label)
    label = re.sub(r"[^A-Za-z0-9_.|:-]", "_", label)
    return label or "unknown"


def normalize_taxonomy(taxonomy):
    parts = [p.strip() for p in taxonomy.split(";") if p.strip()]
    by_rank = {r: f"{r}__unclassified" for r in RANKS}
    for token in parts:
        if len(token) >= 3 and token[1:3] == "__":
            rank = token[0]
            if rank in by_rank:
                by_rank[rank] = token
    return [by_rank[r] for r in RANKS]


def add_record(root, taxonomy, genome_id):
    current = root
    for rank_token in normalize_taxonomy(taxonomy):
        node_key = sanitize_label(rank_token)
        if node_key not in current.children:
            current.children[node_key] = Node(name=node_key)
        current = current.children[node_key]

    leaf = sanitize_label(genome_id)
    current.leaves[leaf] = None


def to_newick(node):
    child_parts = []
    for child in node.children.values():
        child_parts.append(to_newick(child))
    for leaf in node.leaves.keys():
        child_parts.append(leaf)

    if not child_parts:
        return node.name

    joined = ",".join(child_parts)
    if node.name == "ROOT":
        return f"({joined});"
    return f"({joined}){node.name}"


def build_tree(input_tsv, output_newick):
    root = Node("ROOT")
    total = 0
    used = 0

    with input_tsv.open(newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        required = {"user_genome", "classification"}
        missing = required.difference(reader.fieldnames or [])
        if missing:
            cols = ", ".join(sorted(missing))
            raise ValueError(f"Missing required columns in {input_tsv}: {cols}")

        for row in reader:
            total += 1
            genome_id = (row.get("user_genome") or "").strip()
            taxonomy = (row.get("classification") or "").strip()
            if not genome_id or not taxonomy or taxonomy.upper() == "N/A":
                continue
            add_record(root, taxonomy, genome_id)
            used += 1

    output_newick.write_text(to_newick(root) + "\n")
    return total, used


def parse_args():
    parser = argparse.ArgumentParser(
        description="Convert GTDB-Tk summary classification table to taxonomy-based Newick tree."
    )
    parser.add_argument("input_tsv", type=Path, help="Path to gtdbtk.all.summary.tsv")
    parser.add_argument(
        "output_newick",
        type=Path,
        nargs="?",
        help="Output Newick path (default: <input_dir>/gtdbtk.taxonomy_tree.nwk)",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    input_tsv = args.input_tsv
    if not input_tsv.exists():
        raise FileNotFoundError(f"Input file not found: {input_tsv}")

    output_newick = args.output_newick
    if output_newick is None:
        output_newick = input_tsv.parent / "gtdbtk.taxonomy_tree.nwk"

    total, used = build_tree(input_tsv, output_newick)
    print(f"Wrote taxonomy tree: {output_newick}")
    print(f"Records read: {total}")
    print(f"Records used: {used}")


if __name__ == "__main__":
    main()
