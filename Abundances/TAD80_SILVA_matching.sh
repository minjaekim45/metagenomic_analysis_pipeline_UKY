#!/bin/bash
#SBATCH --job-name=gtdb_to_silva
#SBATCH --nodes=1
#SBATCH --ntasks=4
#SBATCH --time=12:00:00
#SBATCH --mem=12G
#SBATCH --output=gtdb_to_silva.%j.out
#SBATCH --error=gtdb_to_silva.%j.err

set -euo pipefail

#######################
# 0. Set input path
#######################

# sbatch 29.gtdb_to_silva.sh /scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/
if [[ $# -lt 1 ]]; then
    echo "Usage: sbatch $0 [project_root_dir]" >&2
    exit 1
fi

dir=$(readlink -f "$1")
echo $dir

WORKDIR="$dir/29.TAD80/"
cd "$WORKDIR"

echo "Working directory: $WORKDIR"

# Path to SILVA 138.1 SSURef NR99 FASTA
SILVA_FASTA="/project/mki314_uksr/SILVA_138.1_SSURef_NR99_tax_silva_trunc.fasta"

if [[ ! -f "$SILVA_FASTA" ]]; then
    echo "ERROR: SILVA FASTA not found at: $SILVA_FASTA" >&2
    echo "Please download SILVA 138.1 SSURef NR99 and update SILVA_FASTA path in the script." >&2
    exit 1
fi

#######################
# 1. Conda environment setup
#######################

source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh

#######################
# 2. Extract closest genome references from MAGs
#######################
conda activate python
python << 'PY'
import pandas as pd
from pathlib import Path
tad80_path = Path()"TAD80_abundance_by_taxonomy.xlsx")
out_path = Path("MAG_genome_reference.txt")

df = pd.read_excel(tad80_path, sheet_name="TAD80")
refs = (
    df["closest_genome_reference"]
    .dropna()
    .astype(str)
    .str.strip()
)
refs = refs[refs != ""].unique()

with out_path.open("w") as f:
    for acc in refs:
        f.write(acc + "\n")

print(f"Wrote {len(refs)} genome accessions to {out_path}")
PY

#######################
# 3. Download reference genomes from NCBI
#######################
if ! conda env list | grep -q "^gtdb_silva"; then
    echo "Creating conda environment 'gtdb_silva'..."
    conda create -n gtdb_silva python=3.10 -y
fi

conda activate gtdb_silva


mkdir -p genomes

echo "Downloading genomes from NCBI for each closest_genome_reference..."

while read -r ACC; do
    [[ -z "$ACC" ]] && continue
    OUTFILE="genomes/${ACC}.fna"

    if [[ -f "$OUTFILE" ]]; then
        echo "Genome for $ACC already exists, skip download."
        continue
    fi

    echo "Downloading $ACC ..."
    # bacteria, archaea
    ncbi-genome-download bacteria,archaea \
        --assembly-accessions "$ACC" \
        --format fasta \
        --output-folder genomes || {
            echo "WARNING: Failed to download $ACC" >&2
            continue
        }
   
    gzfile=$(find genomes -maxdepth 6 -type f -name "${ACC}*genomic.fna.gz" | head -n 1)

    if [[ -z "$gzfile" ]]; then
        echo "WARNING: Could not find downloaded file for $ACC" >&2
        continue
    fi

    echo "Unzipping and renaming $gzfile -> $OUTFILE"
    gunzip -c "$gzfile" > "$OUTFILE" || {
        echo "WARNING: gunzip failed for $ACC" >&2
        continue
    }

done < MAG_genome_reference.txt


#######################
# 4. Extract 16S rRNA sequences from MAGs using barrnap
#######################

mkdir -p 16S

echo "Extracting 16S rRNA sequences with barrnap..."

while read -r ACC; do
    [[ -z "$ACC" ]] && continue
    GENOME="genomes/${ACC}.fna"
    OUTFA="16S/${ACC}_16S.fa"

    if [[ ! -f "$GENOME" ]]; then
        echo "Genome not found for $ACC, skip 16S extraction."
        continue
    fi

    if [[ -f "$OUTFA" ]]; then
        echo "16S for $ACC already exists, skip."
        continue
    fi

    echo "Running barrnap for $ACC..."
    GFF="tmp_${ACC}.gff"
    barrnap --kingdom bac "$GENOME" > "$GFF" 2>/dev/null || {
        echo "WARNING: barrnap failed for $ACC" >&2
        rm -f "$GFF"
        continue
    }

    # GFF에서 16S 위치 기반으로 FASTA 추출
    bedtools getfasta -fi "$GENOME" -bed "$GFF" -fo "$OUTFA" || {
        echo "WARNING: bedtools getfasta failed for $ACC" >&2
        rm -f "$GFF"
        continue
    }

    rm -f "$GFF"
done < MAG_genome_reference.txt

#######################
# 5. Build BLAST database for SILVA 138.1
#######################

echo "Preparing BLAST database for SILVA 138.1..."

if [[ ! -f "${SILVA_FASTA}.nin" && ! -f "${SILVA_FASTA%.fasta}.nin" && ! -f "silva138_1_nr99.nin" ]]; then
    makeblastdb \
        -in "$SILVA_FASTA" \
        -dbtype nucl \
        -out silva138_1_nr99
    DB_PREFIX="silva138_1_nr99"
else
    if [[ -f "silva138_1_nr99.nin" ]]; then
        DB_PREFIX="silva138_1_nr99"
    else
        DB_PREFIX="${SILVA_FASTA}"
    fi
fi


#######################
# 6. 16S vs SILVA BLAST
#######################

mkdir -p blast_results

echo "Running BLAST of each 16S sequence against SILVA 138.1..."

while read -r ACC; do
    [[ -z "$ACC" ]] && continue
    QUERY="16S/${ACC}_16S.fa"
    OUTTSV="blast_results/${ACC}_silva.tsv"

    if [[ ! -f "$QUERY" ]]; then
        echo "No 16S FASTA for $ACC, skip BLAST."
        continue
    fi

    if [[ -f "$OUTTSV" ]]; then
        echo "BLAST result for $ACC already exists, skip."
        continue
    fi

    echo "BLAST $ACC ..."
    blastn \
      -query "$QUERY" \
      -db "$DB_PREFIX" \
      -out "$OUTTSV" \
      -num_threads 4 \
      -max_target_seqs 5 \
      -evalue 1e-20 \
      -outfmt '6 qseqid sseqid pident length evalue bitscore sscinames staxids stitle' || {
        echo "WARNING: BLAST failed for $ACC" >&2
        continue
      }
done < MAG_genome_reference.txt

#######################
# 7. BLAST best hit + TAD80 merge (Python)
#######################

echo "Merging BLAST hits with TAD80 abundance table..."

python << 'PY'
import pandas as pd
from pathlib import Path

tad80_path = "TAD80_abundance_by_taxonomy.xlsx"
df = pd.read_excel(tad80_path, sheet_name="TAD80")

blast_dir = Path("blast_results")
records = []

for tsv in blast_dir.glob("*_silva.tsv"):
    acc = tsv.stem.replace("_silva", "")
    tmp = pd.read_csv(
        tsv,
        sep="\t",
        header=None,
        names=[
            "qseqid", "sseqid", "pident", "length",
            "evalue", "bitscore", "sscinames", "staxids", "stitle"
        ]
    )
    if tmp.empty:
        continue
    
    # Select best hit based on highest bitscore
    best = tmp.sort_values("bitscore", ascending=False).iloc[0].copy()
    best["closest_genome_reference"] = acc
    records.append(best)

blast_df = pd.DataFrame(records)

if blast_df.empty:
    print("WARNING: No BLAST hits were parsed. Check blast_results/*.tsv")
else:
    def extract_taxonomy(stitle):
        # example: "AB000001.1.1496 Bacteria;Proteobacteria;..."
        parts = str(stitle).split(" ", 1)
        return parts[1] if len(parts) > 1 else stitle

    blast_df["SILVA1381_taxonomy"] = blast_df["stitle"].apply(extract_taxonomy)

    merged = df.merge(
        blast_df[["closest_genome_reference", "SILVA1381_taxonomy", "sscinames", "staxids", "pident", "length", "bitscore"]],
        on="closest_genome_reference",
        how="left"
    )

    out_path = "TAD80_with_SILVA1381.xlsx"
    with pd.ExcelWriter(out_path) as writer:
        merged.to_excel(writer, sheet_name="TAD80_SILVA", index=False)

    print(f"Merged table written to {out_path}")
PY

echo "All done."