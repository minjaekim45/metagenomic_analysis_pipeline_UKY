#!/usr/bin/env python3
"""Prune a GTDB taxonomy tree by ANI clades and generate iTOL annotations."""

import argparse
import os
import re
from collections import Counter, defaultdict

import pandas as pd
from Bio import Phylo
from matplotlib import cm
from matplotlib.colors import to_hex


DEFAULT_PATHS = {
    "tree": "gtdbtk.taxonomy_tree.nwk",
    "clusters": "dRep_clusters.csv",
    "summary": "gtdbtk.all.summary.tsv",
    "abundance": "04.abundance.tsv",
    "acetate": "candidate_mags_acetate.txt",
    "propionate": "candidate_mags_propionate.txt",
    "butyrate": "candidate_mags_butyrate.txt",
}

FALLBACK_PATHS = {
    "tree": ["FASTQ/fastq_files/17.gtdbtk/gtdbtk.taxonomy_tree.nwk"],
    "clusters": ["FASTQ/fastq_files/dRep_clusters.csv"],
    "summary": ["FASTQ/fastq_files/17.gtdbtk/gtdbtk.all.summary.tsv"],
    "abundance": ["FASTQ/fastq_files/29.TAD80/TAD80/abundance/04.abundance.tsv"],
    "acetate": ["FASTQ/fastq_files/36.functionalprofiling/candidate_mags_acetate.txt"],
    "propionate": [
        "FASTQ/fastq_files/36.functionalprofiling/candidate_mags_propionate.txt"
    ],
    "butyrate": ["FASTQ/fastq_files/36.functionalprofiling/candidate_mags_butyrate.txt"],
}

GUILD_COLORS = {
    "SAOB": "#e41a1c",
    "SPOB": "#377eb8",
    "SBOB": "#4daf4a",
}

RANK_ORDER_LOWEST = ["s", "g", "f", "o", "c", "p"]


def normalize_mag_id(value):
    base = os.path.basename(str(value).strip())
    base = re.sub(r"\.(fa|fna|fasta)(\.gz)?$", "", base, flags=re.IGNORECASE)
    return base


def tip_from_mag_id(mag_id):
    return normalize_mag_id(mag_id) + ".fa"


def resolve_path(path_value, key):
    if path_value and os.path.exists(path_value):
        return path_value
    if path_value and path_value != DEFAULT_PATHS[key]:
        raise FileNotFoundError("Input file not found: {}".format(path_value))

    for candidate in FALLBACK_PATHS.get(key, []):
        if os.path.exists(candidate):
            return candidate

    raise FileNotFoundError(
        "Input file not found for {}. Tried '{}' and fallbacks: {}".format(
            key, path_value, ", ".join(FALLBACK_PATHS.get(key, []))
        )
    )


def read_candidate_set(path):
    mags = set()
    with open(path, "r") as fh:
        for line in fh:
            item = line.strip()
            if not item:
                continue
            mags.add(normalize_mag_id(item))
    return mags


def parse_classification(classification):
    tokens = {}
    if pd.isna(classification):
        return tokens
    for item in str(classification).split(";"):
        item = item.strip()
        if len(item) < 3 or item[1:3] != "__":
            continue
        rank = item[0]
        name = item[3:].strip()
        tokens[rank] = name
    return tokens


def species_or_lowest_rank(classification):
    ranks = parse_classification(classification)
    species = ranks.get("s", "")
    if species:
        return species
    for rank in ["g", "f", "o", "c", "p"]:
        val = ranks.get(rank, "")
        if val:
            return "{} sp.".format(val)
    return "Unclassified sp."


def phylum_name(classification):
    ranks = parse_classification(classification)
    return ranks.get("p", "") or "Unclassified"


def parse_day_label(sample_name):
    name = str(sample_name)
    cleaned = name.split("_", 1)[1] if "_" in name else name
    cleaned = cleaned.replace("-", ".")
    m = re.match(r"^([0-9]+(?:\.[0-9]+)?)d$", cleaned)
    if m:
        return cleaned, float(m.group(1))
    return cleaned, float("inf")


def sample_columns_sorted(columns):
    parsed = []
    for col in columns:
        cleaned, day = parse_day_label(col)
        if day != float("inf"):
            parsed.append((col, cleaned, day))
    parsed.sort(key=lambda x: (x[2], x[1]))
    ordered_cols = [x[0] for x in parsed]
    ordered_labels = [x[1] for x in parsed]
    return ordered_cols, ordered_labels


def make_distinct_colors(n):
    if n <= 0:
        return []
    tab20 = [to_hex(c, keep_alpha=False) for c in cm.get_cmap("tab20").colors]
    if n <= len(tab20):
        return tab20[:n]

    colors = list(tab20)
    extra = n - len(tab20)
    hsv = cm.get_cmap("hsv", extra + 1)
    for i in range(extra):
        c = to_hex(hsv(i), keep_alpha=False)
        if c not in colors:
            colors.append(c)
        else:
            # In the rare event of a collision, perturb index and retry.
            c2 = to_hex(hsv((i + 0.5) / (extra + 1)), keep_alpha=False)
            colors.append(c2)
    return colors[:n]


def load_clusters(path):
    mag_to_clade = {}
    clade_to_members = defaultdict(list)
    with open(path, "r") as fh:
        for idx, line in enumerate(fh):
            line = line.strip()
            if not line:
                continue
            clade_name = "ANIsp_{:03d}".format(idx)
            members = [normalize_mag_id(x) for x in line.split(",") if x.strip()]
            for m in members:
                mag_to_clade[m] = clade_name
            clade_to_members[clade_name].extend(members)
    return mag_to_clade, clade_to_members


def choose_guild(members, acetate_set, propionate_set, butyrate_set):
    mset = set(members)
    if mset & acetate_set:
        return "SAOB"
    if mset & propionate_set:
        return "SPOB"
    if mset & butyrate_set:
        return "SBOB"
    return None


def write_labels(path, rep_tip_to_clade, tip_to_species_label):
    with open(path, "w") as out:
        out.write("LABELS\n")
        out.write("SEPARATOR TAB\n")
        out.write("DATA\n")
        for tip in sorted(rep_tip_to_clade):
            clade = rep_tip_to_clade[tip]
            label = "{}_{}".format(clade, tip_to_species_label.get(tip, "Unclassified sp."))
            out.write("{}\t{}\n".format(tip, label))


def write_heatmap(path, rep_tips, abundance_df):
    ordered_cols, ordered_labels = sample_columns_sorted(
        [c for c in abundance_df.columns if c != "Bin"]
    )
    if not ordered_cols:
        raise ValueError("No day-like sample columns found in abundance table.")

    with open(path, "w") as out:
        out.write("DATASET_HEATMAP\n")
        out.write("SEPARATOR TAB\n")
        out.write("DATASET_LABEL\tRepMAG_Abundance_TAD80\n")
        out.write("COLOR\t#000000\n")
        out.write("FIELD_LABELS\t{}\n".format("\t".join(ordered_labels)))
        out.write("SHOW_INTERNAL\t0\n\n")
        out.write("DATA\n")
        for tip in sorted(rep_tips):
            mag = normalize_mag_id(tip)
            if mag in abundance_df.index:
                vals = abundance_df.loc[mag, ordered_cols].fillna(0.0)
                vals = [str(float(v)) for v in vals.tolist()]
            else:
                vals = ["0.0"] * len(ordered_cols)
            out.write("{}\t{}\n".format(tip, "\t".join(vals)))


def write_tree_colors(path, rep_tips, tip_to_guild):
    with open(path, "w") as out:
        out.write("TREE_COLORS\n")
        out.write("SEPARATOR TAB\n")
        out.write("DATA\n")
        for tip in sorted(rep_tips):
            guild = tip_to_guild.get(tip)
            if guild is None:
                continue
            color = GUILD_COLORS[guild]
            out.write("{}\tbranch\t{}\t{}\t{}\n".format(tip, color, color, color))


def write_guild_colorstrip(path, rep_tips, tip_to_guild):
    with open(path, "w") as out:
        out.write("DATASET_COLORSTRIP\n")
        out.write("SEPARATOR TAB\n")
        out.write("DATASET_LABEL\tGuild\n")
        out.write("COLOR\t#000000\n")
        out.write("STRIP_WIDTH\t25\n")
        out.write("MARGIN\t5\n")
        out.write("SHOW_INTERNAL\t0\n\n")
        out.write("DATA\n")
        for tip in sorted(rep_tips):
            guild = tip_to_guild.get(tip)
            if guild is None:
                continue
            out.write("{}\t{}\t{}\n".format(tip, GUILD_COLORS[guild], guild))


def write_phylum_colorstrip(path, rep_tips, tip_to_phylum):
    phyla = sorted(set(tip_to_phylum[t] for t in rep_tips))
    phylum_to_color = {}
    colors = make_distinct_colors(len(phyla))
    for i, p in enumerate(phyla):
        phylum_to_color[p] = colors[i]

    with open(path, "w") as out:
        out.write("DATASET_COLORSTRIP\n")
        out.write("SEPARATOR TAB\n")
        out.write("DATASET_LABEL\tPhylum\n")
        out.write("COLOR\t#000000\n")
        out.write("STRIP_WIDTH\t25\n")
        out.write("MARGIN\t5\n")
        out.write("SHOW_INTERNAL\t0\n")
        out.write("LEGEND_TITLE\tPhylum\n")
        out.write("LEGEND_SHAPES\t{}\n".format("\t".join(["1"] * len(phyla))))
        out.write(
            "LEGEND_COLORS\t{}\n".format("\t".join(phylum_to_color[p] for p in phyla))
        )
        out.write("LEGEND_LABELS\t{}\n\n".format("\t".join(phyla)))
        out.write("DATA\n")
        for tip in sorted(rep_tips):
            phylum = tip_to_phylum[tip]
            out.write("{}\t{}\t{}\n".format(tip, phylum_to_color[phylum], phylum))


def main():
    parser = argparse.ArgumentParser(
        description="Prune GTDB tree by ANIsp representatives and generate iTOL files."
    )
    parser.add_argument("--tree", default=DEFAULT_PATHS["tree"])
    parser.add_argument("--clusters", default=DEFAULT_PATHS["clusters"])
    parser.add_argument("--summary", default=DEFAULT_PATHS["summary"])
    parser.add_argument("--abundance", default=DEFAULT_PATHS["abundance"])
    parser.add_argument("--acetate", default=DEFAULT_PATHS["acetate"])
    parser.add_argument("--propionate", default=DEFAULT_PATHS["propionate"])
    parser.add_argument("--butyrate", default=DEFAULT_PATHS["butyrate"])
    args = parser.parse_args()

    tree_path = resolve_path(args.tree, "tree")
    clusters_path = resolve_path(args.clusters, "clusters")
    summary_path = resolve_path(args.summary, "summary")
    abundance_path = resolve_path(args.abundance, "abundance")
    acetate_path = resolve_path(args.acetate, "acetate")
    propionate_path = resolve_path(args.propionate, "propionate")
    butyrate_path = resolve_path(args.butyrate, "butyrate")

    tree = Phylo.read(tree_path, "newick")
    tip_clades = tree.get_terminals()
    original_tips = [t.name for t in tip_clades]
    tip_to_mag = {tip: normalize_mag_id(tip) for tip in original_tips}

    mag_to_clade, clade_to_members = load_clusters(clusters_path)

    # Assign each tree tip to a clade; keep unmapped MAGs as singleton pseudo-clades.
    mag_clade_assignments = {}
    for tip, mag in tip_to_mag.items():
        if mag in mag_to_clade:
            mag_clade_assignments[mag] = mag_to_clade[mag]
        else:
            singleton = "ANIsp_UNMAPPED_{}".format(mag)
            mag_clade_assignments[mag] = singleton
            clade_to_members[singleton] = [mag]

    abundance_df = pd.read_csv(abundance_path, sep="\t")
    if "Bin" not in abundance_df.columns:
        raise ValueError("Column 'Bin' is required in {}".format(abundance_path))
    abundance_df["Bin"] = abundance_df["Bin"].map(normalize_mag_id)
    sample_cols = [c for c in abundance_df.columns if c != "Bin"]
    abundance_df[sample_cols] = abundance_df[sample_cols].apply(
        pd.to_numeric, errors="coerce"
    )
    abundance_df["mean_abundance"] = abundance_df[sample_cols].mean(axis=1, skipna=True)
    abundance_df = abundance_df.set_index("Bin", drop=True)

    reps_by_clade = {}
    clade_to_tree_mags = defaultdict(list)
    for tip, mag in tip_to_mag.items():
        clade_to_tree_mags[mag_clade_assignments[mag]].append(mag)

    for clade, mags in clade_to_tree_mags.items():
        unique_mags = sorted(set(mags))
        mags_with_abund = [m for m in unique_mags if m in abundance_df.index]
        if mags_with_abund:
            best = sorted(
                mags_with_abund,
                key=lambda m: (-float(abundance_df.loc[m, "mean_abundance"]), m),
            )[0]
        else:
            best = unique_mags[0]
        reps_by_clade[clade] = best

    representative_tips = sorted([tip_from_mag_id(m) for m in reps_by_clade.values()])
    keep_set = set(representative_tips)

    pruned_tree = Phylo.read(tree_path, "newick")
    for terminal in list(pruned_tree.get_terminals()):
        if terminal.name not in keep_set:
            pruned_tree.prune(terminal)
    Phylo.write(pruned_tree, "pruned_ANIsp.treefile", "newick")

    summary_df = pd.read_csv(summary_path, sep="\t", dtype=str)
    if "user_genome" not in summary_df.columns or "classification" not in summary_df.columns:
        raise ValueError(
            "Columns 'user_genome' and 'classification' are required in {}".format(
                summary_path
            )
        )
    summary_df["user_genome_norm"] = summary_df["user_genome"].map(tip_from_mag_id)
    tax_by_tip = (
        summary_df.dropna(subset=["user_genome_norm"])
        .drop_duplicates(subset=["user_genome_norm"], keep="first")
        .set_index("user_genome_norm")["classification"]
        .to_dict()
    )

    acetate_set = read_candidate_set(acetate_path)
    propionate_set = read_candidate_set(propionate_path)
    butyrate_set = read_candidate_set(butyrate_path)

    rep_tip_to_clade = {}
    tip_to_species_label = {}
    tip_to_guild = {}
    tip_to_phylum = {}
    for clade, rep_mag in sorted(reps_by_clade.items()):
        tip = tip_from_mag_id(rep_mag)
        rep_tip_to_clade[tip] = clade

        classification = tax_by_tip.get(tip, "")
        tip_to_species_label[tip] = species_or_lowest_rank(classification)
        tip_to_phylum[tip] = phylum_name(classification)

        members = clade_to_members.get(clade, [rep_mag])
        guild = choose_guild(members, acetate_set, propionate_set, butyrate_set)
        tip_to_guild[tip] = guild

    write_labels(
        "iTOL_labels_pruned_ANIsp_species.txt", rep_tip_to_clade, tip_to_species_label
    )
    write_heatmap("iTOL_heatmap_pruned_abundance.txt", representative_tips, abundance_df)
    # Backward-compatible alias with requested alternate filename.
    write_heatmap(
        "iTOL_heatmap_pruned_repMAG_abundance.txt", representative_tips, abundance_df
    )
    write_tree_colors(
        "iTOL_tree_colors_pruned_SAOB_SPOB_SBOB.txt", representative_tips, tip_to_guild
    )
    write_guild_colorstrip(
        "iTOL_colorstrip_pruned_guild.txt", representative_tips, tip_to_guild
    )
    write_phylum_colorstrip(
        "iTOL_colorstrip_pruned_phylum.txt", representative_tips, tip_to_phylum
    )

    guild_counter = Counter([g for g in tip_to_guild.values() if g is not None])
    phylum_counter = Counter([tip_to_phylum[t] for t in representative_tips])

    print("Summary report")
    print("Number of tips in original tree: {}".format(len(original_tips)))
    print("Number of unique ANIsp clades: {}".format(len(reps_by_clade)))
    print("Number of tips kept in pruned tree: {}".format(len(representative_tips)))
    print(
        "Guild counts: SAOB={0}, SPOB={1}, SBOB={2}".format(
            guild_counter.get("SAOB", 0),
            guild_counter.get("SPOB", 0),
            guild_counter.get("SBOB", 0),
        )
    )
    print("Phylum counts:")
    for p, c in sorted(phylum_counter.items(), key=lambda x: (-x[1], x[0])):
        print("  {}: {}".format(p, c))


if __name__ == "__main__":
    main()
