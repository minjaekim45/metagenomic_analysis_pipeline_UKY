#!/usr/bin/env python3
"""
Summarize KEGG modules per MAG from filtered eggNOG files.

It scans module-specific directories like:
  34.eggnog/Hydrogenotrophic/IR37_0d.6_M00567.tsv
  34.eggnog/Acetoclastic/IR37_0d.6_M00357.tsv
  ...

and produces:
  - a long table: MAG, Module, n_genes
  - a wide table: one row per MAG, one column per Module (gene counts)

Usage:
    summarize_modules_per_MAG.py <base_dir> <out_prefix>

Example:
    summarize_modules_per_MAG.py \
      /scratch/.../FASTQ/fastq_files/34.eggnog \
      /scratch/.../FASTQ/fastq_files/34.eggnog/IR37_modules
"""

import sys
import os
import glob
import pandas as pd

if len(sys.argv) != 3:
    print("Usage: summarize_modules_per_MAG.py <base_dir> <out_prefix>", file=sys.stderr)
    sys.exit(1)

BASE = sys.argv[1]       # e.g. /.../34.eggnog
OUT_PREFIX = sys.argv[2] # e.g. /.../34.eggnog/IR37_modules

# Module → subdir mapping (must match run_filter_modules.sh)
MODULE_DIR = {
    "M00567": "Hydrogenotrophic",  # CO2 → CH4
    "M00357": "Acetoclastic",      # acetate → CH4
    "M00356": "Methanol",          # methanol → CH4
    "M00563": "Methylamine",       # methylamines → CH4
    "M00422": "AcetylCoA",         # acetyl-CoA pathway
}

rows = []

for module_id, subdir in MODULE_DIR.items():
    mod_dir = os.path.join(BASE, subdir)
    if not os.path.isdir(mod_dir):
        print(f"[WARN] Module dir not found: {mod_dir}", file=sys.stderr)
        continue

    pattern = os.path.join(mod_dir, f"*_{module_id}.tsv")
    for path in glob.glob(pattern):
        # MAG name = filename without trailing "_M00xxx.tsv"
        fname = os.path.basename(path)
        mag = fname[: -len(f"_{module_id}.tsv")]

        try:
            df = pd.read_csv(path, sep="\t")
        except Exception as e:
            print(f"[WARN] Could not read {path}: {e}", file=sys.stderr)
            continue

        n_genes = len(df)
        rows.append({"MAG": mag, "Module": module_id, "n_genes": n_genes})

        # optional: you could also store KO set etc. here if needed

long_df = pd.DataFrame(rows)

if long_df.empty:
    print("[ERROR] No module hits found in any directory.", file=sys.stderr)
    sys.exit(1)

# long format
long_out = OUT_PREFIX + "_long.tsv"
long_df.to_csv(long_out, sep="\t", index=False)
print(f"[DONE] Wrote long table: {long_out}")

# wide format: MAG × Module matrix (gene counts)
wide_df = long_df.pivot_table(
    index="MAG",
    columns="Module",
    values="n_genes",
    fill_value=0,
    aggfunc="sum",
)

wide_out = OUT_PREFIX + "_wide.tsv"
wide_df.to_csv(wide_out, sep="\t")
print(f"[DONE] Wrote wide table: {wide_out}")
