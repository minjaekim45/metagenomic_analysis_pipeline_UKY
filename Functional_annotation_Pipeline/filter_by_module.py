#!/usr/bin/env python3
"""
Filter eggNOG emapper annotations by a KEGG Module ID.

Usage:
    filter_by_module.py <emapper_annotations.tsv> <MODULE_ID> <out.tsv>

Example:
    filter_by_module.py IR37_0d.6.eggnog.emapper.annotations M00567 \
        IR37_0d.6_M00567.tsv
"""

import sys
import pandas as pd

if len(sys.argv) != 4:
    print("Usage: filter_by_module.py <emapper_annotations.tsv> <MODULE_ID> <out.tsv>",
          file=sys.stderr)
    sys.exit(1)

emapper_tsv = sys.argv[1]
module_id   = sys.argv[2].strip()   # e.g. M00567
out_tsv     = sys.argv[3]

# ----- find header line that starts with "#query" -----
header = None
header_line_idx = None

with open(emapper_tsv) as f:
    for i, line in enumerate(f):
        if line.startswith("#query"):
            header_line_idx = i
            header = line.lstrip("#").rstrip("\n").split("\t")
            break

if header is None or header_line_idx is None:
    print(f"[ERROR] Could not find header line starting with '#query' in {emapper_tsv}",
          file=sys.stderr)
    sys.exit(1)

# ----- load annotations using the discovered header -----
df = pd.read_csv(
    emapper_tsv,
    sep="\t",
    header=None,
    names=header,
    skiprows=header_line_idx + 1,
    dtype=str,
)

if "KEGG_Module" not in df.columns:
    print(f"[ERROR] Column 'KEGG_Module' not found in {emapper_tsv}", file=sys.stderr)
    print(f"Columns: {list(df.columns)}", file=sys.stderr)
    sys.exit(1)

df["KEGG_Module"] = df["KEGG_Module"].fillna("")

def has_module(field: str) -> bool:
    """
    KEGG_Module field example:
        'M00567,M00422'
        ''
    Return True if MODULE_ID is one of the comma-separated entries.
    """
    if not field:
        return False
    mods = [m.strip() for m in field.split(",") if m.strip()]
    return module_id in mods

mask = df["KEGG_Module"].apply(has_module)
sub = df[mask].copy()
n_hits = int(mask.sum())

if n_hits == 0:
    # No genes annotated with this module in this MAG → do not create output file
    print(f"[INFO] No hits for module {module_id} in {emapper_tsv}; no output written.",
          file=sys.stderr)
    sys.exit(0)

print(f"[INFO] {n_hits} rows matched module {module_id} in {emapper_tsv}",
      file=sys.stderr)

# Write output only when there is at least one hit
sub.to_csv(out_tsv, sep="\t", index=False)
print(f"[DONE] Wrote {out_tsv}", file=sys.stderr)
