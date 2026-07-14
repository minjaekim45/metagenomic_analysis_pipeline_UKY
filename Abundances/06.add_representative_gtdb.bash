#!/bin/bash
#SBATCH --time=12:00:00
#SBATCH --job-name=add_rep_gtdb
#SBATCH --ntasks=4
#SBATCH --partition=normal
#SBATCH -e zz.out/add_rep_gtdb-%j.err
#SBATCH -o zz.out/add_rep_gtdb-%j.out
#SBATCH --account=coa_mki314_uksr
#SBATCH --mem=10G

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: sbatch ./06.add_representative_gtdb.bash [folder]
   folder     Path to the folder containing 29.TAD80 directory

   Example:
   sbatch ./06.add_representative_gtdb.bash /scratch/sag239/PNA
   " >&2
   exit 1
fi

dir=$(readlink -f "$1")

CONSOLIDATE_DIR="$dir/29.TAD80/consolidate"
WDB_FILE="$dir/18.dRep/output/dereplicate/data_tables/Wdb.csv"
GTDB_FILE="$dir/17.gtdbtk/gtdbtk.bac120.summary.tsv"

DREP_CLUSTERS="$CONSOLIDATE_DIR/dRep_clusters.csv"
ANISPP_FILE="$CONSOLIDATE_DIR/ANIspp.abundance.tsv"

REP_CLUSTER_MAP="$CONSOLIDATE_DIR/representative_cluster_map.tsv"
REP_LIST="$CONSOLIDATE_DIR/representative_genomes.txt"
REP_GTDB_MAP="$CONSOLIDATE_DIR/representative_gtdb_classification.tsv"
CLADE_MAP="$CONSOLIDATE_DIR/representative_by_clade.tsv"

FINAL_OUT="$CONSOLIDATE_DIR/ANIspp.abundance.with_representative.tsv"

for f in "$WDB_FILE" "$GTDB_FILE" "$DREP_CLUSTERS" "$ANISPP_FILE"; do
   if [[ ! -f "$f" ]]; then
      echo "ERROR: File not found:"
      echo "$f"
      exit 1
   fi
done

echo "Step 1: Creating representative-cluster map from Wdb.csv"

awk -F',' '
BEGIN {
   OFS="\t"
}
NR == 1 {
   for (i=1; i<=NF; i++) {
      gsub(/\r/, "", $i)
      if ($i == "genome") genome_col=i
      if ($i == "cluster") cluster_col=i
   }

   if (genome_col == "" || cluster_col == "") {
      print "ERROR: genome or cluster column not found in Wdb.csv" > "/dev/stderr"
      exit 1
   }

   next
}
{
   genome=$genome_col
   cluster=$cluster_col

   gsub(/\r/, "", genome)
   gsub(/\r/, "", cluster)

   print cluster, genome
}
' "$WDB_FILE" > "$REP_CLUSTER_MAP"

cut -f2 "$REP_CLUSTER_MAP" > "$REP_LIST"

echo "Step 2: Finding GTDB classification for each representative genome"

awk -F'\t' '
BEGIN {
   OFS="\t"
}

NR == FNR {
   cluster=$1
   rep=$2

   rep_no_ext=rep
   sub(/\.fa$/, "", rep_no_ext)
   sub(/\.fasta$/, "", rep_no_ext)
   sub(/\.fna$/, "", rep_no_ext)

   rep_by_name[rep]=rep
   rep_by_name[rep_no_ext]=rep

   cluster_by_rep[rep]=cluster
   cluster_by_rep[rep_no_ext]=cluster

   next
}

FNR == 1 {
   for (i=1; i<=NF; i++) {
      if ($i == "user_genome") user_genome_col=i
      if ($i == "classification") classification_col=i
   }

   if (user_genome_col == "" || classification_col == "") {
      print "ERROR: user_genome or classification column not found in GTDB-Tk file" > "/dev/stderr"
      exit 1
   }

   next
}

{
   user_genome=$user_genome_col
   classification=$classification_col

   if (user_genome in rep_by_name) {
      rep=rep_by_name[user_genome]
      cluster=cluster_by_rep[user_genome]
      print cluster, rep, classification
   }
}
' "$REP_CLUSTER_MAP" "$GTDB_FILE" > "$REP_GTDB_MAP"

echo "Step 3: Computing the Clade ID for each dRep_clusters.csv row and attaching representative genome + classification to it"

awk -F'\t' '
BEGIN {
   OFS="\t"
}

NR == FNR {
   cluster=$1
   rep=$2
   classification=$3

   rep_by_cluster[cluster]=rep
   class_by_cluster[cluster]=classification

   next
}

{
   cluster_id = FNR - 1
   clade = sprintf("ANIsp_%03d", cluster_id)

   n = split($0, genomes, ",")
   found = 0

   for (c in rep_by_cluster) {
      rep = rep_by_cluster[c]
      for (i = 1; i <= n; i++) {
         g = genomes[i]
         gsub(/\r/, "", g)
         gsub(/^ +| +$/, "", g)
         if (g == rep) {
            print clade, c, rep, class_by_cluster[c]
            found = 1
            break
         }
      }
      if (found == 1) break
   }

   if (found == 0) {
      print clade, "NA", "NA", "NA"
   }
}
' "$REP_GTDB_MAP" "$DREP_CLUSTERS" > "$CLADE_MAP"

echo "Step 4: Adding representative genome and GTDB classification to ANIspp.abundance.tsv"

awk -F'\t' '
BEGIN {
   OFS="\t"
}

NR == FNR {
   clade = $1
   rep_by_clade[clade] = $3
   class_by_clade[clade] = $4
   next
}

FNR == 1 {
   print $0, "representative_genome", "GTDB_classification"
   next
}

{
   clade = $1

   if (clade in rep_by_clade) {
      print $0, rep_by_clade[clade], class_by_clade[clade]
   } else {
      print $0, "NA", "NA"
   }
}
' "$CLADE_MAP" "$ANISPP_FILE" > "$FINAL_OUT"

echo "Done."
echo "Representative cluster map:"
echo "$REP_CLUSTER_MAP"
echo "Representative genomes:"
echo "$REP_LIST"
echo "Representative GTDB map:"
echo "$REP_GTDB_MAP"
echo "Representative by Clade ID:"
echo "$CLADE_MAP"
echo "Final output:"
echo "$FINAL_OUT"
