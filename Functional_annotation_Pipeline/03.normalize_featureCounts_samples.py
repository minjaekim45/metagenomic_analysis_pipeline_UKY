#!/usr/bin/env python3
import os
import gzip
import argparse
from collections import defaultdict

def parse_featurecounts_file(path):
    """
    Returns: list of records (dict), and per-file stats
    Assumes one count column (single BAM) -> we take the last column as Count.
    Skips comment lines starting with '#'.
    """
    records = []
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        header = None
        idx = {}
        for line in f:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if header is None:
                header = parts
                # required columns
                for col in ["Geneid", "Chr", "Start", "End", "Strand", "Length"]:
                    if col not in header:
                        raise ValueError(f"Missing required column '{col}' in {path}")
                idx = {c: header.index(c) for c in header}
                continue

            # data line
            if len(parts) < len(header):
                # malformed line
                continue

            geneid = parts[idx["Geneid"]]
            chrom  = parts[idx["Chr"]]
            start  = parts[idx["Start"]]
            end    = parts[idx["End"]]
            strand = parts[idx["Strand"]]

            # Length and Count
            try:
                length_bp = int(parts[idx["Length"]])
            except ValueError:
                # sometimes Length can be float-ish; try float->int
                length_bp = int(float(parts[idx["Length"]]))

            # last column is the count (single BAM)
            try:
                count = int(parts[-1])
            except ValueError:
                count = int(float(parts[-1]))

            records.append({
                "Geneid": geneid,
                "Chr": chrom,
                "Start": start,
                "End": end,
                "Strand": strand,
                "Length": length_bp,
                "Count": count,
            })
    return records


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fc_dir", required=True, help="35.featureCounts directory")
    ap.add_argument("--out_dir", required=True, help="output directory for normalized tables")
    ap.add_argument("--prefix", default="IR37_", help="only process files starting with this prefix")
    ap.add_argument("--compress", action="store_true", help="write gene tables as .tsv.gz")
    args = ap.parse_args()

    fc_dir = args.fc_dir
    out_dir = args.out_dir
    os.makedirs(out_dir, exist_ok=True)
    log_dir = os.path.join(out_dir, "logs")
    os.makedirs(log_dir, exist_ok=True)

    # collect MAG gene_count files
    files = []
    for fn in os.listdir(fc_dir):
        if not fn.startswith(args.prefix):
            continue
        if fn.endswith(".gene_counts.txt"):
            files.append(fn)
    files.sort()

    if not files:
        raise SystemExit(f"[ERROR] No *.gene_counts.txt found in {fc_dir}")

    # group by sample: sample = MAG.rsplit('.', 1)[0]
    # ex: IR37_0d.100 -> IR37_0d
    #     IR37_11-5d.94 -> IR37_11-5d
    sample_to_files = defaultdict(list)
    for fn in files:
        mag = fn.replace(".gene_counts.txt", "")
        sample = mag.rsplit(".", 1)[0]
        sample_to_files[sample].append(fn)

    # write a global run log
    runlog = os.path.join(log_dir, "normalize.run.tsv")
    with open(runlog, "w", encoding="utf-8") as rl:
        rl.write("Sample\tnMAG\tnGene\tTotalCount\tTotalRPK\tTPMSum\n")

    for sample, fns in sorted(sample_to_files.items()):
        # pass 1: read all gene rows across all MAGs for this sample
        gene_rows = []
        mag_stats = defaultdict(lambda: {"nGene": 0, "sumCount": 0, "sumRPK": 0.0})

        total_count = 0
        total_rpk = 0.0

        for fn in fns:
            mag = fn.replace(".gene_counts.txt", "")
            path = os.path.join(fc_dir, fn)

            try:
                recs = parse_featurecounts_file(path)
            except Exception as e:
                # log and skip broken files
                with open(os.path.join(log_dir, f"{sample}.WARN.txt"), "a", encoding="utf-8") as wf:
                    wf.write(f"[WARN] Failed to parse {path}: {e}\n")
                continue

            for r in recs:
                L = r["Length"]
                C = r["Count"]
                rpk = (C * 1000.0 / L) if L > 0 else 0.0

                row = {
                    "Sample": sample,
                    "MAG": mag,
                    **r,
                    "RPK": rpk,
                }
                gene_rows.append(row)

                total_count += C
                total_rpk += rpk

                mag_stats[mag]["nGene"] += 1
                mag_stats[mag]["sumCount"] += C
                mag_stats[mag]["sumRPK"] += rpk

        if not gene_rows:
            with open(os.path.join(log_dir, f"{sample}.WARN.txt"), "a", encoding="utf-8") as wf:
                wf.write("[WARN] No gene rows found after parsing. Skipping sample.\n")
            continue

        # pass 2: compute TPM + RPKM (sample-wide normalization across all MAGs)
        # RPKM = (C * 1e9) / (L * total_count)
        # TPM  = (RPK / total_rpk) * 1e6
        for row in gene_rows:
            L = row["Length"]
            C = row["Count"]
            rpk = row["RPK"]

            if total_count > 0 and L > 0:
                row["RPKM"] = (C * 1e9) / (L * total_count)
            else:
                row["RPKM"] = 0.0

            if total_rpk > 0:
                row["TPM"] = (rpk / total_rpk) * 1e6
            else:
                row["TPM"] = 0.0

            # unique gene key (safe for merges)
            row["Gene_global"] = f"{row['MAG']}|{row['Geneid']}"

        # write gene table
        gene_out_base = os.path.join(out_dir, f"{sample}.allMAG.gene_TPM_RPKM.tsv")
        if args.compress:
            gene_out = gene_out_base + ".gz"
            out_fh = gzip.open(gene_out, "wt", encoding="utf-8")
        else:
            gene_out = gene_out_base
            out_fh = open(gene_out, "w", encoding="utf-8")

        with out_fh as out:
            cols = ["Sample", "MAG", "Gene_global", "Geneid", "Chr", "Start", "End", "Strand",
                    "Length", "Count", "RPK", "RPKM", "TPM"]
            out.write("\t".join(cols) + "\n")
            for row in gene_rows:
                out.write("\t".join(str(row[c]) for c in cols) + "\n")

        # write MAG summary
        mag_out = os.path.join(out_dir, f"{sample}.MAG_summary.tsv")
        with open(mag_out, "w", encoding="utf-8") as out:
            out.write("Sample\tMAG\tnGene\tsumCount\tsumRPK\tsumTPM\n")
            for mag, st in sorted(mag_stats.items()):
                sum_tpm = 0.0
                # TPM already normalized across sample; sum TPM per MAG = relative abundance proxy
                # compute from gene_rows to avoid float drift
                # (could also do st["sumRPK"]/total_rpk*1e6 if total_rpk>0)
                if total_rpk > 0:
                    sum_tpm = (st["sumRPK"] / total_rpk) * 1e6
                out.write(f"{sample}\t{mag}\t{st['nGene']}\t{st['sumCount']}\t{st['sumRPK']}\t{sum_tpm}\n")

        # sanity: TPM sum should be ~1e6
        tpm_sum = sum(r["TPM"] for r in gene_rows)

        # append to runlog
        with open(runlog, "a", encoding="utf-8") as rl:
            rl.write(f"{sample}\t{len(mag_stats)}\t{len(gene_rows)}\t{total_count}\t{total_rpk}\t{tpm_sum}\n")

        # write per-sample note
        with open(os.path.join(log_dir, f"{sample}.DONE.txt"), "w", encoding="utf-8") as df:
            df.write(f"Sample={sample}\n")
            df.write(f"nMAG={len(mag_stats)}\n")
            df.write(f"nGene={len(gene_rows)}\n")
            df.write(f"TotalCount={total_count}\n")
            df.write(f"TotalRPK={total_rpk}\n")
            df.write(f"TPMSum={tpm_sum}\n")
            df.write(f"GeneTable={gene_out}\n")
            df.write(f"MAGSummary={mag_out}\n")

    print(f"[OK] Finished. Outputs in: {out_dir}")
    print(f"[OK] Run log: {runlog}")

if __name__ == "__main__":
    main()
