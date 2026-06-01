#!/bin/bash
#SBATCH --time=12:00:00
#SBATCH --job-name=make_ANIspp
#SBATCH --ntasks=4
#SBATCH --partition=normal
#SBATCH -e zz.out/make_ANIspp-%j.err
#SBATCH -o zz.out/make_ANIspp-%j.out
#SBATCH --account=coa_mki314_uksr
#SBATCH --mem=10G

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: sbatch ./05.make_ANIspp_abundance.bash [folder]
   folder     Path to the folder containing 29.TAD80 directory.

   Example:
   sbatch ./06.make_ANIspp_abundance.bash /scratch/sag239/PNA
   " >&2
   exit 1
fi

dir=$(readlink -f "$1")

CONSOLIDATE_DIR="$dir/29.TAD80/consolidate"
ABUNDANCE_DIR="$dir/29.TAD80/abundance"

CDB_FILE="$dir/18.dRep/output/dereplicate/data_tables/Cdb.csv"
ABUNDANCE_FILE="$ABUNDANCE_DIR/04.abundance.tsv"

DREP_CLUSTERS="$CONSOLIDATE_DIR/dRep_clusters.csv"
COPIED_ABUNDANCE="$CONSOLIDATE_DIR/04.abundance.tsv"
ANISPP_FILE="$CONSOLIDATE_DIR/ANIspp.abundance.tsv"

mkdir -p "$CONSOLIDATE_DIR"

if [[ ! -f "$CDB_FILE" ]]; then
   echo "ERROR: Cdb.csv not found:"
   echo "$CDB_FILE"
   exit 1
fi

if [[ ! -f "$ABUNDANCE_FILE" ]]; then
   echo "ERROR: 04.abundance.tsv not found:"
   echo "$ABUNDANCE_FILE"
   exit 1
fi

echo "Step 1: Creating dRep_clusters.csv"

awk -F',' '
NR == 1 {
   for (i=1; i<=NF; i++) {
      gsub(/\r/, "", $i)
      if ($i == "genome") genome_col=i
      if ($i == "secondary_cluster") cluster_col=i
   }

   if (genome_col == "" || cluster_col == "") {
      print "ERROR: genome or secondary_cluster column not found in Cdb.csv" > "/dev/stderr"
      exit 1
   }

   next
}
{
   genome=$genome_col
   cluster=$cluster_col

   gsub(/\r/, "", genome)
   gsub(/\r/, "", cluster)

   if (!(cluster in seen)) {
      seen[cluster]=1
      order[++n]=cluster
   }

   clusters[cluster] = (clusters[cluster] == "" ? genome : clusters[cluster] "," genome)
}
END {
   for (i=1; i<=n; i++) {
      cluster=order[i]
      print clusters[cluster]
   }
}
' "$CDB_FILE" > "$DREP_CLUSTERS"

echo "Step 2: Copying 04.abundance.tsv to consolidate folder"

cp "$ABUNDANCE_FILE" "$COPIED_ABUNDANCE"

echo "Step 3: Creating ANIspp.abundance.tsv"

awk -F'\t' '
BEGIN {
   OFS="\t"
}

NR == FNR {
   cluster_id = FNR - 1
   n = split($0, genomes, ",")

   for (i=1; i<=n; i++) {
      genome = genomes[i]

      gsub(/\r/, "", genome)
      gsub(/^ +| +$/, "", genome)

      sub(/\.fa$/, "", genome)
      sub(/\.fasta$/, "", genome)
      sub(/\.fna$/, "", genome)

      classif[genome] = cluster_id
   }

   next
}

FNR == 1 {
   for (i=2; i<=NF; i++) {
      samples[i-1] = $i
   }

   header = "Clade"
   for (i=1; i<=length(samples); i++) {
      header = header OFS samples[i]
   }

   print header
   next
}

{
   genome = $1

   gsub(/\r/, "", genome)
   gsub(/^ +| +$/, "", genome)

   if (!(genome in classif)) {
      next
   }

   sp = classif[genome]

   for (i=2; i<=NF; i++) {
      ab[sp, i-1] += $i
   }

   if (!(sp in seen_sp)) {
      seen_sp[sp] = 1
      order[++n_sp] = sp
   }
}

END {
   for (j=1; j<=n_sp; j++) {
      sp = order[j]

      clade = sprintf("ANIsp_%03d", sp)
      line = clade

      for (i=1; i<=length(samples); i++) {
         line = line OFS ab[sp, i]
      }

      print line
   }
}
' "$DREP_CLUSTERS" "$COPIED_ABUNDANCE" > "$ANISPP_FILE"

echo "Done."
echo "dRep clusters:"
echo "$DREP_CLUSTERS"
echo "Copied abundance file:"
echo "$COPIED_ABUNDANCE"
echo "ANIspp abundance file:"
echo "$ANISPP_FILE"
