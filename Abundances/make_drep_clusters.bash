#!/usr/bin/env bash
#SBATCH --time=00:10:00
#SBATCH --job-name=drep_clusters
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --partition=normal
#SBATCH --account=coa_mki314_uksr

set -euo pipefail

if [[ "${1:-}" == "" || "${1:-}" == "-h" ]]; then
  cat <<'EOF' >&2
Usage: ./02.drep_clusters.bash [folder] [cluster_level] [keep_ext]

  folder         Project root (contains 18.dRep/output/...)
  cluster_level  secondary (default) | primary | cluster
  keep_ext       yes to keep .fa/.fna/.fasta(.gz); default removes extensions

Output:
  Writes dRep_clusters.csv under [folder] (no header, one cluster per line).
EOF
  exit 1
fi

FOLDER="$(readlink -f "$1")"
LEVEL="${2:-secondary}"
KEEP="${3:-no}"

# Find Cdb.csv: prefer dereplicate, then compare, lastly directly under folder
CDB=""
for p in \
  "$FOLDER/18.dRep/output/dereplicate/data_tables/Cdb.csv" \
  "$FOLDER/18.dRep/output/compare/data_tables/Cdb.csv" \
  "$FOLDER/Cdb.csv"
do
  [[ -f "$p" ]] && { CDB="$p"; break; }
done
[[ -n "$CDB" ]] || { echo "ERROR: Cdb.csv not found under $FOLDER" >&2; exit 2; }

# choose cluster column
case "$LEVEL" in
  secondary|sec|species) KEY="secondary_cluster" ;;
  primary|pri|strain)    KEY="primary_cluster"   ;;
  cluster)               KEY="cluster"           ;;
  *)                     KEY="secondary_cluster" ;;
esac

OUT="$FOLDER/dRep_clusters.csv"
echo "[INFO] Cdb: $CDB"
echo "[INFO] cluster_level: $KEY   keep_ext: $KEEP"
echo "[INFO] -> $OUT"

# Cdb.csv -> dRep_clusters.csv (no header, one row = one cluster, comma-separated genome IDs)
awk -F',' -v key="$KEY" -v keep_ext="$KEEP" '
NR==1{
  for(i=1;i<=NF;i++) h[$i]=i
  c = (h[key] ? h[key] : (h["cluster"] ? h["cluster"] : h["primary_cluster"]))
  g = (h["genome"] ? h["genome"] : (h["Genome"] ? h["Genome"] : h["genome_id"]))
  if(!c || !g){ print "ERROR: need cluster + genome columns in Cdb.csv" > "/dev/stderr"; exit 3 }
  next
}
{
  k=$c; id=$g
  sub(/^.*[\/\\]/,"",id)                         # basename
  if(keep_ext!="yes" && keep_ext!="keep")        # 확장자 제거(기본)
    sub(/\.(fa|fna|fasta)(\.gz)?$/,"",id)
  gsub(/[[:space:]]/,"",id)                      # 공백 제거
  a[k]=(a[k]?a[k]"," : "") id
}
END{
  for(k in a) print a[k]
}
' "$CDB" > "$OUT"

echo "[OK] Wrote: $OUT"
