#!/usr/bin/env python3
"""
Summarize module-filtered eggNOG files and merge MAG abundance.

Inputs:
  base_dir      : root of 34.eggnog (contains Hydrogenotrophic/, Acetoclastic/, ...)
  abundance_tsv : MAG × sample abundance table (column 'Bin' = MAG name)

Outputs (under base_dir):
  IR37_modules_MAG_summary.tsv
    MAG, Module, n_genes, <abundance columns...>

  IR37_modules_sample_potential.tsv
    Module, Sample, Potential
    (Potential = sum_over_MAG( abundance_sample * presence ),
     where presence = 1 if n_genes > 0 else 0)
"""

import sys
import os
import glob
import pandas as pd

if len(sys.argv) != 3:
    print("Usage: summarize_modules_with_abundance.py <base_dir> <abundance_tsv>",
          file=sys.stderr)
    sys.exit(1)

BASE = sys.argv[1]
ABUN_PATH = sys.argv[2]

# --- load abundance ---
abun = pd.read_csv(ABUN_PATH, sep="\t")
if "Bin" not in abun.columns:
    print(f"[ERROR] Column 'Bin' not found in {ABUN_PATH}", file=sys.stderr)
    sys.exit(1)

abun = abun.rename(columns={"Bin": "MAG"}).set_index("MAG")
abun_cols = list(abun.columns)
print(f"[INFO ] Loaded abundance for {abun.shape[0]} MAGs.")
print(f"[INFO ] Abundance columns: {abun_cols}")

# --- module directories (must match your pipeline) ---
MODULE_DIR = {
    "M00567": "Hydrogenotrophic",   # CO2 → CH4
    "M00357": "Acetoclastic",       # acetate → CH4
    "M00356": "Methanol",           # methanol → CH4
    "M00563": "Methylamine",        # methylamines → CH4
    "M00422": "AcetylCoA",          # acetyl-CoA pathway
}

rows = []

for module_id, subdir in MODULE_DIR.items():
    mod_dir = os.path.join(BASE, subdir)
    if not os.path.isdir(mod_dir):
        print(f"[WARN] Module dir not found: {mod_dir}", file=sys.stderr)
        continue

    pattern = os.path.join(mod_dir, f"*_{module_id}.tsv")
    files = sorted(glob.glob(pattern))
    print(f"[INFO ] Module {module_id} ({subdir}): {len(files)} files")

    for path in files:
        fname = os.path.basename(path)
        mag = fname[: -len(f"_{module_id}.tsv")]

        try:
            df = pd.read_csv(path, sep="\t")
        except Exception as e:
            print(f"[WARN] Could not read {path}: {e}", file=sys.stderr)
            continue

        n_genes = len(df)
        rows.append({"MAG": mag, "Module": module_id, "n_genes": n_genes})

# --- build MAG × Module table ---
mod_df = pd.DataFrame(rows)
if mod_df.empty:
    print("[ERROR] No module hits found.", file=sys.stderr)
    sys.exit(1)

# merge with abundance (left join = only MAGs with modules)
mod_df = mod_df.merge(abun.reset_index(), on="MAG", how="left")

out_mag = os.path.join(BASE, "IR37_modules_MAG_summary.tsv")
mod_df.to_csv(out_mag, sep="\t", index=False)
print(f"[DONE ] Wrote MAG summary: {out_mag}")

# --- compute sample-wise module potential ---
sample_cols = abun_cols  # columns in abundance table

records = []
for module in sorted(MODULE_DIR.keys()):
    sub = mod_df[mod_df["Module"] == module].copy()
    if sub.empty:
        continue

    # presence indicator (1 if at least one gene)
    sub["presence"] = (sub["n_genes"] > 0).astype(int)

    for sample in sample_cols:
        # Potential = sum(abundance_sample * presence)
        pot = (sub[sample] * sub["presence"]).sum()
        records.append({"Module": module, "Sample": sample, "Potential": pot})

pot_df = pd.DataFrame(records)
out_pot = os.path.join(BASE, "IR37_modules_sample_potential.tsv")
pot_df.to_csv(out_pot, sep="\t", index=False)
print(f"[DONE ] Wrote sample potential: {out_pot}")
