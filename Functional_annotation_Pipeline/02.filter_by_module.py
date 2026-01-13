#!/usr/bin/env python3
"""
Filter eggNOG emapper annotations by a specified column (default: KEGG_Module).

Backwards-compatible usage (old):
    filter_by_module.py <emapper_annotations.tsv> <ID> <out.tsv>

New usage:
    filter_by_module.py --input <emapper_annotations.tsv> --id <ID> --out <out.tsv> \
        [--column KEGG_Module]
    filter_by_module.py --input <emapper_annotations.tsv> --ids <ID1,ID2,...> --out <out.tsv> \
        [--column KEGG_Module]
"""

import sys
import argparse
import pandas as pd


def find_header(emapper_tsv: str):
    header = None
    header_line_idx = None
    with open(emapper_tsv) as f:
        for i, line in enumerate(f):
            if line.startswith("#query"):
                header_line_idx = i
                header = line.lstrip("#").rstrip("\n").split("\t")
                break
    return header, header_line_idx


def main():
    # --- Backwards compatibility: 3 positional args ---
    if len(sys.argv) == 4 and not sys.argv[1].startswith("-"):
        emapper_tsv = sys.argv[1]
        ids = [sys.argv[2].strip()]
        out_tsv = sys.argv[3]
        column = "KEGG_Module"
    else:
        ap = argparse.ArgumentParser()
        ap.add_argument("--input", required=True, help="emapper annotations tsv")
        ap.add_argument("--out", required=True, help="output tsv")
        ap.add_argument("--column", default="KEGG_Module", help="column to filter (default: KEGG_Module)")
        g = ap.add_mutually_exclusive_group(required=True)
        g.add_argument("--id", help="single ID (e.g., M00567 or map00680)")
        g.add_argument("--ids", help="comma-separated IDs (e.g., M00567,M00422)")
        args = ap.parse_args()

        emapper_tsv = args.input
        out_tsv = args.out
        column = args.column
        if args.id:
            ids = [args.id.strip()]
        else:
            ids = [x.strip() for x in args.ids.split(",") if x.strip()]

    header, header_line_idx = find_header(emapper_tsv)
    if header is None or header_line_idx is None:
        print(f"[ERROR] Could not find header line starting with '#query' in {emapper_tsv}", file=sys.stderr)
        sys.exit(1)

    df = pd.read_csv(
        emapper_tsv,
        sep="\t",
        header=None,
        names=header,
        skiprows=header_line_idx + 1,
        dtype=str,
    )

    if column not in df.columns:
        print(f"[ERROR] Column '{column}' not found in {emapper_tsv}", file=sys.stderr)
        print(f"Columns: {list(df.columns)}", file=sys.stderr)
        sys.exit(1)

    df[column] = df[column].fillna("")

    idset = set(ids)

    def has_any_id(field: str) -> bool:
        if not field:
            return False
        items = [m.strip() for m in field.split(",") if m.strip()]
        return any(x in idset for x in items)

    mask = df[column].apply(has_any_id)
    sub = df[mask].copy()
    n_hits = int(mask.sum())

    if n_hits == 0:
        print(f"[INFO] No hits for {ids} in column {column} ({emapper_tsv}); no output written.", file=sys.stderr)
        sys.exit(0)

    sub.to_csv(out_tsv, sep="\t", index=False)
    print(f"[DONE] Wrote {out_tsv} ({n_hits} rows)", file=sys.stderr)


if __name__ == "__main__":
    main()
