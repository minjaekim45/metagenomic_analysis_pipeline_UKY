#!/usr/bin/env python3
"""
Summarize target-filtered eggNOG files and merge MAG abundance.

Inputs:
  base_dir         : root of 34.eggnog (contains subdirs listed in targets_map.tsv)
  abundance_tsv    : MAG × sample abundance table (default expects column 'Bin' = MAG name)
  targets_map_tsv  : tsv (id, subdir[, label])

Outputs:
  <base_dir>/IR37_targets_MAG_summary.tsv
    MAG, TargetID, n_hits, <abundance columns...>

  <base_dir>/IR37_targets_sample_potential.tsv
    TargetID, Sample, Potential
    Potential = sum_over_MAG( abundance_sample * weight )
    weight = presence (0/1) OR n_hits (gene counts)

Usage:
  summarize_targets_with_abundance.py <base_dir> <abundance_tsv> <targets_map_tsv>
    [--mag_col Bin] [--weight presence|n_hits] [--presence_min 1] [--jobs 8]
"""

import argparse
import os
import glob
from concurrent.futures import ThreadPoolExecutor, as_completed

import pandas as pd


def load_targets_map(path: str) -> pd.DataFrame:
    df = pd.read_csv(path, sep="\t", dtype=str, comment="#", header=None)
    if df.shape[1] < 2:
        raise ValueError("targets_map_tsv must have at least 2 columns: id, subdir")
    df = df.rename(columns={0: "id", 1: "subdir"})
    if df.shape[1] >= 3:
        df = df.rename(columns={2: "label"})
    else:
        df["label"] = df["id"]
    df = df.fillna("")
    df = df[df["id"].str.len() > 0]
    return df[["id", "subdir", "label"]]


def count_rows_tsv(path: str) -> int:
    # counts lines after header
    n = 0
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        first = f.readline()
        if not first:
            return 0
        for _ in f:
            n += 1
    return n


def parse_mag_from_filename(fname: str, target_id: str) -> str:
    suffix = f"_{target_id}.tsv"
    if fname.endswith(suffix):
        return fname[: -len(suffix)]
    return os.path.splitext(fname)[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("base_dir")
    ap.add_argument("abundance_tsv")
    ap.add_argument("targets_map_tsv")
    ap.add_argument("--mag_col", default="Bin", help="MAG column name in abundance table (default: Bin)")
    ap.add_argument("--weight", choices=["presence", "n_hits"], default="presence",
                    help="how to weight module potential across MAGs")
    ap.add_argument("--presence_min", type=int, default=1, help="n_hits >= this => present")
    ap.add_argument("--jobs", type=int, default=8, help="threads for counting")
    ap.add_argument("--out_mag", default=None, help="override MAG summary output path")
    ap.add_argument("--out_potential", default=None, help="override sample potential output path")
    args = ap.parse_args()

    base = args.base_dir
    if not os.path.isdir(base):
        raise SystemExit(f"[ERROR] base_dir not found: {base}")
    if not os.path.isfile(args.abundance_tsv):
        raise SystemExit(f"[ERROR] abundance_tsv not found: {args.abundance_tsv}")
    if not os.path.isfile(args.targets_map_tsv):
        raise SystemExit(f"[ERROR] targets_map_tsv not found: {args.targets_map_tsv}")

    # load abundance
    abun = pd.read_csv(args.abundance_tsv, sep="\t")
    if args.mag_col not in abun.columns:
        raise SystemExit(f"[ERROR] MAG column '{args.mag_col}' not found in abundance table.")
    abun = abun.rename(columns={args.mag_col: "MAG"}).set_index("MAG")
    sample_cols = list(abun.columns)

    targets = load_targets_map(args.targets_map_tsv)

    # gather all files to count
    tasks = []
    for _, t in targets.iterrows():
        tid = t["id"]
        subdir = t["subdir"]
        d = os.path.join(base, subdir)
        if not os.path.isdir(d):
            print(f"[WARN] Target dir not found: {d}")
            continue
        files = sorted(glob.glob(os.path.join(d, f"*_{tid}.tsv")))
        for p in files:
            tasks.append((tid, p))

    if not tasks:
        raise SystemExit("[ERROR] No target hit TSV files found.")

    # count in parallel
    rows = []
    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as ex:
        futs = {ex.submit(count_rows_tsv, path): (tid, path) for tid, path in tasks}
        for fut in as_completed(futs):
            tid, path = futs[fut]
            try:
                n_hits = int(fut.result())
            except Exception as e:
                print(f"[WARN] Failed to read {path}: {e}")
                continue
            fname = os.path.basename(path)
            mag = parse_mag_from_filename(fname, tid)
            rows.append({"MAG": mag, "TargetID": tid, "n_hits": n_hits})

    mod_df = pd.DataFrame(rows)
    if mod_df.empty:
        raise SystemExit("[ERROR] No target hits loaded (all empty?)")

    # merge with abundance (left join -> keep all MAG hits)
    mod_df = mod_df.merge(abun.reset_index(), on="MAG", how="left")

    out_mag = args.out_mag or os.path.join(base, "IR37_targets_MAG_summary.tsv")
    mod_df.to_csv(out_mag, sep="\t", index=False)
    print(f"[DONE] Wrote MAG summary: {out_mag}")

    # compute sample-wise potential
    records = []
    for tid in sorted(mod_df["TargetID"].unique()):
        sub = mod_df[mod_df["TargetID"] == tid].copy()
        if sub.empty:
            continue

        if args.weight == "presence":
            w = (sub["n_hits"] >= args.presence_min).astype(int)
        else:
            # n_hits weight (optionally thresholded)
            w = sub["n_hits"].where(sub["n_hits"] >= args.presence_min, 0)

        for s in sample_cols:
            # abundance may be NaN for missing MAGs -> treat as 0
            pot = (sub[s].fillna(0) * w).sum()
            records.append({"TargetID": tid, "Sample": s, "Potential": pot})

    pot_df = pd.DataFrame(records)
    out_pot = args.out_potential or os.path.join(base, "IR37_targets_sample_potential.tsv")
    pot_df.to_csv(out_pot, sep="\t", index=False)
    print(f"[DONE] Wrote sample potential: {out_pot}")


if __name__ == "__main__":
    main()
