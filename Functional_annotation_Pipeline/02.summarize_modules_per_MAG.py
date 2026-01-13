#!/usr/bin/env python3
"""
Summarize target hits per MAG from filtered eggNOG TSVs.

It scans target-specific directories like:
  <base_dir>/<subdir>/<MAG>_<ID>.tsv

where ID can be module (Mxxxxx) or pathway (mapxxxxx), etc.

Outputs:
  - long table: MAG, TargetID, n_hits
  - wide table: MAG × TargetID matrix (n_hits)

Usage:
  summarize_targets_per_MAG.py <base_dir> <targets_map_tsv> <out_prefix> [--jobs 8]
"""

import argparse
import os
import glob
from concurrent.futures import ThreadPoolExecutor, as_completed

import pandas as pd


def load_targets_map(path: str) -> pd.DataFrame:
    df = pd.read_csv(path, sep="\t", dtype=str, comment="#", header=None)
    if df.shape[1] < 2:
        raise ValueError(f"targets_map_tsv must have at least 2 columns: id, subdir. Got: {df.shape[1]}")
    df = df.rename(columns={0: "id", 1: "subdir"})
    if df.shape[1] >= 3:
        df = df.rename(columns={2: "label"})
    else:
        df["label"] = df["id"]
    df = df.fillna("")
    df = df[df["id"].str.len() > 0]
    return df[["id", "subdir", "label"]]


def count_rows_tsv(path: str) -> int:
    # Fast line count; filtered TSVs usually have header row.
    n = 0
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        first = f.readline()
        if not first:
            return 0
        for _ in f:
            n += 1
    # n currently counts lines after the first line -> header excluded
    return n


def parse_mag_from_filename(fname: str, target_id: str) -> str:
    # "<MAG>_<ID>.tsv" -> MAG
    suffix = f"_{target_id}.tsv"
    if fname.endswith(suffix):
        return fname[: -len(suffix)]
    # fallback
    return os.path.splitext(fname)[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("base_dir", help="e.g. .../34.eggnog")
    ap.add_argument("targets_map_tsv", help="tsv with columns: id, subdir[, label]")
    ap.add_argument("out_prefix", help="e.g. .../34.eggnog/IR37_targets")
    ap.add_argument("--jobs", type=int, default=8, help="threads for counting")
    args = ap.parse_args()

    base = args.base_dir
    if not os.path.isdir(base):
        raise SystemExit(f"[ERROR] base_dir not found: {base}")

    targets = load_targets_map(args.targets_map_tsv)

    tasks = []
    rows = []

    # Prepare all file paths first
    for _, t in targets.iterrows():
        tid = t["id"]
        subdir = t["subdir"]
        mod_dir = os.path.join(base, subdir)
        if not os.path.isdir(mod_dir):
            print(f"[WARN] Target dir not found: {mod_dir}")
            continue
        pattern = os.path.join(mod_dir, f"*_{tid}.tsv")
        files = sorted(glob.glob(pattern))
        for p in files:
            tasks.append((tid, p))

    if not tasks:
        raise SystemExit("[ERROR] No target hit TSV files found (check targets_map.tsv & directory layout).")

    # Count lines in parallel (I/O-bound)
    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as ex:
        futs = {ex.submit(count_rows_tsv, path): (tid, path) for tid, path in tasks}
        for fut in as_completed(futs):
            tid, path = futs[fut]
            try:
                n_hits = fut.result()
            except Exception as e:
                print(f"[WARN] Failed to read {path}: {e}")
                continue
            fname = os.path.basename(path)
            mag = parse_mag_from_filename(fname, tid)
            rows.append({"MAG": mag, "TargetID": tid, "n_hits": int(n_hits)})

    long_df = pd.DataFrame(rows)
    if long_df.empty:
        raise SystemExit("[ERROR] No rows generated. Are your TSVs empty?")

    long_out = args.out_prefix + "_long.tsv"
    long_df.to_csv(long_out, sep="\t", index=False)
    print(f"[DONE] Wrote long table: {long_out}")

    wide_df = long_df.pivot_table(
        index="MAG",
        columns="TargetID",
        values="n_hits",
        fill_value=0,
        aggfunc="sum",
    )

    wide_out = args.out_prefix + "_wide.tsv"
    wide_df.to_csv(wide_out, sep="\t")
    print(f"[DONE] Wrote wide table: {wide_out}")


if __name__ == "__main__":
    main()
