#!/usr/bin/env python3
import argparse, os, re, gzip, glob
import pandas as pd

def infer_sample_from_mag(mag: str) -> str:
    # MAG like IR37_0d.13  -> sample IR37_0d
    # MAG like IR37_6-5d.94 -> sample IR37_6-5d
    if "." in mag:
        return mag.split(".", 1)[0]
    return mag

def parse_mag_and_moduleid_from_filename(path: str):
    # expects: <MAG>_<MODULEID>.tsv  (e.g., IR37_0d.13_M00357.tsv)
    base = os.path.basename(path)
    m = re.match(r"(.+?)_(M\d{5})\.tsv$", base)
    if not m:
        raise ValueError(f"Unexpected filename format (need <MAG>_Mxxxxx.tsv): {base}")
    return m.group(1), m.group(2)

def load_gene_table(gz_path: str) -> pd.DataFrame:
    # keep only needed cols; be forgiving about column names
    df = pd.read_csv(gz_path, sep="\t", compression="gzip", dtype=str)
    # try common column names
    col_mag = "MAG" if "MAG" in df.columns else ("Bin" if "Bin" in df.columns else None)
    if col_mag is None:
        raise ValueError(f"No MAG/Bin column in {gz_path}")
    df = df.rename(columns={col_mag: "MAG"})
    need = ["MAG", "Geneid"]
    for c in ["TPM", "RPKM", "Count", "Length"]:
        if c in df.columns:
            need.append(c)
    df = df[need].copy()
    # numeric
    for c in ["TPM", "RPKM", "Count", "Length"]:
        if c in df.columns:
            df[c] = pd.to_numeric(df[c], errors="coerce")
    return df

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--eggnog_root", required=True, help=".../34.eggnog")
    ap.add_argument("--normalized_dir", required=True, help=".../35.featureCounts/normalized")
    ap.add_argument("--module", required=True, help="module directory name (e.g., Acetoclastic) OR module ID (M00357)")
    ap.add_argument("--module_tsv", default=None, help="optional mapping file module.tsv")
    ap.add_argument("--out_root", default=None, help="output root; default: eggnog_root/<ModuleDir>_withTPM")
    ap.add_argument("--compress", action="store_true", help="write .tsv.gz (recommended)")
    ap.add_argument("--dry_run", action="store_true", help="print planned actions only")
    args = ap.parse_args()

    eggnog_root = args.eggnog_root.rstrip("/")
    norm_dir = args.normalized_dir.rstrip("/")

    # Resolve module directory + module ID if module.tsv is provided
    module_dir = None
    module_id = None

    if re.fullmatch(r"M\d{5}", args.module):
        module_id = args.module

    if args.module_tsv and os.path.isfile(args.module_tsv):
        mdf = pd.read_csv(args.module_tsv, sep="\t", dtype=str).fillna("")
        # try to find columns
        # accept many possible names
        cols = {c.lower(): c for c in mdf.columns}
        col_id = cols.get("module_id") or cols.get("module") or cols.get("id")
        col_dir = cols.get("out_dir") or cols.get("outdir") or cols.get("dir") or cols.get("folder")
        col_label = cols.get("label") or cols.get("name") or cols.get("module_name")

        # If user provided a directory-like name (Acetoclastic), match it
        if col_dir and args.module:
            hit = mdf[mdf[col_dir].str.lower() == args.module.lower()]
            if hit.shape[0] >= 1:
                module_dir = hit.iloc[0][col_dir]
                if col_id:
                    module_id = hit.iloc[0][col_id]

        # If user provided module ID, find directory
        if module_id and col_id and col_dir and module_dir is None:
            hit = mdf[mdf[col_id].str.upper() == module_id.upper()]
            if hit.shape[0] >= 1:
                module_dir = hit.iloc[0][col_dir]

        # If user provided label, also allow match
        if module_dir is None and col_label and col_dir:
            hit = mdf[mdf[col_label].str.lower() == args.module.lower()]
            if hit.shape[0] >= 1:
                module_dir = hit.iloc[0][col_dir]
                if col_id:
                    module_id = hit.iloc[0][col_id]

    # Fallback: treat --module as directory name
    if module_dir is None:
        module_dir = args.module

    in_dir = os.path.join(eggnog_root, module_dir)
    if not os.path.isdir(in_dir):
        raise SystemExit(f"[ERROR] module directory not found: {in_dir}")

    # Determine which files to process
    pattern = os.path.join(in_dir, "*.tsv")
    files = sorted(glob.glob(pattern))
    if module_id:
        files = [f for f in files if f.endswith(f"_{module_id}.tsv")]

    if not files:
        raise SystemExit(f"[ERROR] No TSV files found for module in: {in_dir}")

    out_root = args.out_root or os.path.join(eggnog_root, f"{module_dir}_withTPM")
    os.makedirs(out_root, exist_ok=True)

    # Cache gene tables per sample (0d, 6-5d, ...)
    gene_cache = {}

    for fp in files:
        mag, mid = parse_mag_and_moduleid_from_filename(fp)
        sample = infer_sample_from_mag(mag)

        gene_gz = os.path.join(norm_dir, f"{sample}.allMAG.gene_TPM_RPKM.tsv.gz")
        if sample not in gene_cache:
            if not os.path.isfile(gene_gz):
                raise SystemExit(f"[ERROR] gene TPM/RPKM file not found for sample={sample}: {gene_gz}")
            gene_cache[sample] = load_gene_table(gene_gz)

        gdf = gene_cache[sample]
        gdf_mag = gdf[gdf["MAG"] == mag]

        df = pd.read_csv(fp, sep="\t", dtype=str)
        if "query" not in df.columns:
            raise SystemExit(f"[ERROR] 'query' column not found in {fp}")
        df = df.rename(columns={"query": "Geneid"})

        merged = df.merge(gdf_mag, on="Geneid", how="left")

        out_name = os.path.basename(fp).replace(".tsv", ".withTPM.tsv")
        out_path = os.path.join(out_root, out_name + (".gz" if args.compress else ""))

        if args.dry_run:
            print(f"[DRY] {fp}  +  {gene_gz}  ->  {out_path}")
            continue

        if args.compress:
            with gzip.open(out_path, "wt", encoding="utf-8") as f:
                merged.to_csv(f, sep="\t", index=False)
        else:
            merged.to_csv(out_path, sep="\t", index=False)

    print(f"[DONE] wrote outputs under: {out_root}")

if __name__ == "__main__":
    main()
