#!/usr/bin/env python3
"""
Step 5: Build SOB_TAD80.csv by filtering ANI clades using Step 1 criteria
and merging with TAD80 abundance by taxonomy.
"""

from __future__ import annotations

import argparse
import math
import re
import sys
from pathlib import Path
from typing import List

import pandas as pd
import matplotlib.pyplot as plt

KO_RE = re.compile(r"K\d{5}")


def count_steps(val: str) -> int:
    if val is None:
        return 0
    text = str(val).strip()
    if not text:
        return 0
    return len([s for s in text.split(",") if s])


def count_kos(val: str) -> int:
    if val is None:
        return 0
    return len(set(KO_RE.findall(str(val))))


def build_label(row: pd.Series, hierarchy: List[str]) -> str:
    ani = str(row.get("ANI_clade", "")).strip()
    species = str(row.get("Species", "")).strip()
    if species and species.lower() != "nan":
        return f"{ani}_{species}"

    for level in hierarchy:
        value = str(row.get(level, "")).strip()
        if value and value.lower() != "nan":
            return f"{ani}_{value} sp."

    return f"{ani}_Unclassified sp."


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create SOB_TAD80.csv by filtering ANI clades and merging abundance."
    )
    parser.add_argument(
        "--tad_xlsx",
        default="FASTQ/fastq_files/29.TAD80/TAD80_abundance_by_taxonomy.xlsx",
        help="Path to TAD80 abundance Excel file.",
    )
    parser.add_argument(
        "--tad_csv",
        default="FASTQ/fastq_files/29.TAD80/TAD80.csv",
        help="Output CSV converted from TAD80 Excel (first sheet).",
    )
    parser.add_argument(
        "--ani_summary",
        default="FASTQ/fastq_files/36.functionalprofiling/ani_clade_summary.tsv",
        help="ANI clade summary TSV.",
    )
    parser.add_argument(
        "--gene_set_tsv",
        default="scripts/gene_sets_step1.tsv",
        help="Gene set TSV used to compute total steps per metabolism.",
    )
    parser.add_argument(
        "--out_csv",
        default="FASTQ/fastq_files/29.TAD80/SOB_TAD80.csv",
        help="Output merged SOB_TAD80 CSV.",
    )
    parser.add_argument(
        "--threshold",
        type=float,
        default=0.75,
        help="Step coverage threshold (default 0.75).",
    )
    parser.add_argument(
        "--thresholds",
        default="acetate=0.75,propionate=1,butyrate=1",
        help=(
            "Optional per-metabolism thresholds, e.g. "
            "'acetate=0.75,propionate=1,butyrate=1'. "
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
    parser.add_argument(
        "--plot_dir",
        default="FASTQ/fastq_files/29.TAD80/plots",
        help="Output directory for stacked bar plots.",
    )
    parser.add_argument(
        "--plot_label",
        default="Label",
        help=(
            "Column name used for stacked bar plot labels. "
            "If not 'Label', data will be grouped by this column and summed."
        ),
    )

    args = parser.parse_args()

    tad_xlsx = Path(args.tad_xlsx)
    tad_csv = Path(args.tad_csv)
    ani_summary = Path(args.ani_summary)
    gene_set_tsv = Path(args.gene_set_tsv)
    out_csv = Path(args.out_csv)
    plot_dir = Path(args.plot_dir)
    plot_label = args.plot_label

    if not tad_xlsx.exists():
        print(f"ERROR: Missing TAD80 Excel file: {tad_xlsx}", file=sys.stderr)
        return 1
    if not ani_summary.exists():
        print(f"ERROR: Missing ANI summary TSV: {ani_summary}", file=sys.stderr)
        return 1
    if not gene_set_tsv.exists():
        print(f"ERROR: Missing gene set TSV: {gene_set_tsv}", file=sys.stderr)
        return 1

    # 1) Convert first sheet of TAD80 Excel to CSV
    df_tad = pd.read_excel(tad_xlsx, sheet_name=0)
    tad_csv.parent.mkdir(parents=True, exist_ok=True)
    df_tad.to_csv(tad_csv, index=False)

    # 2) Filter ANI clades by Step 1 criteria
    ani = pd.read_csv(ani_summary, sep="\t")
    geneset = pd.read_csv(gene_set_tsv, sep="\t")
    if not {"Metabolism", "Step", "KEGG_ko"}.issubset(geneset.columns):
        print(
            "ERROR: gene_set_tsv missing Metabolism/Step/KEGG_ko columns.",
            file=sys.stderr,
        )
        return 1

    steps_total = (
        geneset[["Metabolism", "Step"]]
        .dropna()
        .drop_duplicates()
        .groupby("Metabolism")
        .size()
        .to_dict()
    )
    required_kos = (
        geneset[["Metabolism", "KEGG_ko"]]
        .dropna()
        .assign(ko=lambda df: df["KEGG_ko"].astype(str).str.findall(KO_RE))
        .explode("ko")
        .dropna(subset=["ko"])
        .drop_duplicates(subset=["Metabolism", "ko"])
    )
    required_genes_total = (
        required_kos.groupby("Metabolism").size().to_dict()
    )

    ani["covered_steps"] = ani["covered_step_ids"].apply(count_steps)
    ani["metabolism_norm"] = ani["metabolism"].str.lower()
    ani["total_steps"] = ani["metabolism"].map(steps_total).fillna(0).astype(int)
    required_genes_total_norm = {
        str(k).strip().lower(): int(v) for k, v in required_genes_total.items()
    }
    ani["total_required_genes"] = (
        ani["metabolism_norm"].map(required_genes_total_norm).fillna(0).astype(int)
    )

    if "present_required_genes" in ani.columns:
        ani["present_required_genes"] = (
            pd.to_numeric(ani["present_required_genes"], errors="coerce")
            .fillna(0)
            .astype(int)
        )
    elif "matched_kos" in ani.columns:
        ani["present_required_genes"] = ani["matched_kos"].apply(count_kos)
    else:
        print(
            "ERROR: ani_summary missing both 'present_required_genes' and 'matched_kos' columns.",
            file=sys.stderr,
        )
        return 1

    thresholds = {}
    if args.thresholds.strip():
        for item in args.thresholds.split(","):
            if not item.strip():
                continue
            if "=" not in item:
                print(
                    f"ERROR: Invalid --thresholds entry '{item}'. Use metabolism=0.75 format.",
                    file=sys.stderr,
                )
                return 1
            name, val = item.split("=", 1)
            name = name.strip().lower()
            try:
                thresholds[name] = float(val.strip())
            except ValueError:
                print(
                    f"ERROR: Invalid threshold value in --thresholds: '{item}'.",
                    file=sys.stderr,
                )
                return 1

    def required_steps(row):
        threshold = thresholds.get(row["metabolism_norm"], args.threshold)
        return int(math.ceil(row["total_steps"] * threshold))

    ani["required_steps"] = ani.apply(required_steps, axis=1)
    ani["gene_presence_fraction"] = ani.apply(
        lambda row: (
            row["present_required_genes"] / row["total_required_genes"]
            if row["total_required_genes"] > 0
            else 0.0
        ),
        axis=1,
    )

    filtered = ani[
        (ani["covered_steps"] >= 1)
        & (ani["covered_steps"] >= ani["required_steps"])
        & (ani["gene_presence_fraction"] > args.gene_presence_threshold)
    ].copy()

    # 3) Merge with TAD80.csv based on Clade -> ANI_clade
    if "Clade" not in df_tad.columns:
        print("ERROR: TAD80 CSV missing 'Clade' column.", file=sys.stderr)
        return 1

    merged = df_tad.merge(filtered, how="inner", left_on="Clade", right_on="ANI_clade")

    # 4) Add Label column
    hierarchy = ["Genus", "Family", "Order", "Class", "Phylum", "Kingdom", "Domain"]
    merged["Label"] = merged.apply(build_label, axis=1, hierarchy=hierarchy)

    # 5) Remove columns not needed in output
    drop_cols = ["Clade", "covered_steps", "total_steps", "required_steps"]
    merged = merged.drop(columns=[c for c in drop_cols if c in merged.columns])

    # 4) Write output
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    merged.to_csv(out_csv, index=False)

    # 5) Visualization: stacked bar plots per metabolism
    time_cols = [
        "IR37_0d",
        "IR37_6-5d",
        "IR37_11-5d",
        "IR37_13-5d",
        "IR37_18-5d",
        "IR37_20d",
        "IR37_58d",
        "IR37_120d",
    ]
    label_map = {
        "IR37_0d": "0d",
        "IR37_6-5d": "6.5d",
        "IR37_11-5d": "11.5d",
        "IR37_13-5d": "13.5d",
        "IR37_18-5d": "18.5d",
        "IR37_20d": "20d",
        "IR37_58d": "58d",
        "IR37_120d": "120d",
    }

    missing_cols = [c for c in time_cols + ["Label", "metabolism"] if c not in merged.columns]
    if missing_cols:
        print(
            f"WARNING: Missing columns for plotting: {', '.join(missing_cols)}",
            file=sys.stderr,
        )
    else:
        plot_dir.mkdir(parents=True, exist_ok=True)
        for metabolism, group in merged.groupby("metabolism"):
            label_col = plot_label
            if label_col not in group.columns:
                print(
                    f"WARNING: plot_label '{label_col}' not found. Falling back to 'Label'.",
                    file=sys.stderr,
                )
                label_col = "Label"

            data = group[[label_col] + time_cols].copy()
            data[time_cols] = data[time_cols].apply(pd.to_numeric, errors="coerce").fillna(0)
            if label_col == "Label":
                data = data.set_index("Label")
            else:
                data = data.groupby(label_col)[time_cols].sum()

            ax = data.T.plot(
                kind="bar",
                stacked=True,
                figsize=(10, 6),
                width=0.8,
            )
            ax.set_xlabel("Elapsed days")
            ax.set_ylabel("Relative abundance")
            ax.set_title(f"{metabolism} (SOB abundance, by {label_col})")
            ax.set_xticklabels([label_map.get(c, c) for c in data.columns], rotation=0)
            ax.legend(
                title="Label",
                bbox_to_anchor=(1.02, 1),
                loc="upper left",
                borderaxespad=0.0,
                fontsize="small",
            )

            fig = ax.get_figure()
            fig.tight_layout()
            out_plot = plot_dir / f"SOB_TAD80_{metabolism}.png"
            fig.savefig(out_plot, dpi=300)
            plt.close(fig)

        # Combined SAOB/SPOB/SBOB plot (sum by metabolism)
        metab_label_map = {
            "acetate": "SAOB",
            "propionate": "SPOB",
            "butyrate": "SBOB",
        }
        combined_src = merged[["metabolism"] + time_cols].copy()
        combined_src["metabolism"] = combined_src["metabolism"].str.lower()
        combined = combined_src.groupby("metabolism").sum(numeric_only=True)
        # Keep only known metabolisms in a stable order
        combined = combined.loc[
            [m for m in ["acetate", "propionate", "butyrate"] if m in combined.index]
        ]
        if not combined.empty:
            combined.index = [metab_label_map.get(m, m) for m in combined.index]
            ax = combined.T.plot(
                kind="bar",
                stacked=True,
                figsize=(8, 5),
                width=0.8,
            )
            ax.set_xlabel("Elapsed days")
            ax.set_ylabel("Relative abundance")
            ax.set_title("SAOB / SPOB / SBOB (combined)")
            ax.set_xticklabels([label_map.get(c, c) for c in combined.T.index], rotation=0)
            ax.legend(
                title="Group",
                bbox_to_anchor=(1.02, 1),
                loc="upper left",
                borderaxespad=0.0,
                fontsize="small",
            )
            fig = ax.get_figure()
            fig.tight_layout()
            out_plot = plot_dir / "SOB_TAD80_SAOB_SPOB_SBOB.png"
            fig.savefig(out_plot, dpi=300)
            plt.close(fig)

    print(tad_csv)
    print(out_csv)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
