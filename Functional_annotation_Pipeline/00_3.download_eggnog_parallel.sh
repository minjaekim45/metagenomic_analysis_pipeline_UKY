#!/bin/bash
set -euo pipefail

DBDIR="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/databases/eggnog_db"
BASE_URL="http://eggnog5.embl.de/download/emapperdb-5.0.2"

cd "$DBDIR"

echo "Downloading eggNOG DB files into: $DBDIR"
echo

# 1) 필요 파일들 병렬 다운로드
download() {
  local fname="$1"
  local url="${BASE_URL}/${fname}"

  if [[ -s "$fname" || -s "${fname%.gz}" ]]; then
    echo "[SKIP] $fname (이미 존재, size > 0)"
    return 0
  fi

  echo "[DL  ] $fname"
  wget -c "$url"
}

download "eggnog.db.gz" &
PID1=$!

download "eggnog.taxa.tar.gz" &
PID2=$!

download "eggnog_proteins.dmnd.gz" &
PID3=$!

wait $PID1 $PID2 $PID3
echo
echo "== 다운로드 완료, 압축 해제 시작 =="

# 2) 압축 해제
if [[ -f eggnog.db.gz ]]; then
  echo "[UNZIP] eggnog.db.gz"
  gunzip -f eggnog.db.gz
fi

if [[ -f eggnog_proteins.dmnd.gz ]]; then
  echo "[UNZIP] eggnog_proteins.dmnd.gz"
  gunzip -f eggnog_proteins.dmnd.gz
fi

if [[ -f eggnog.taxa.tar.gz ]]; then
  echo "[UNTAR] eggnog.taxa.tar.gz"
  tar -zxf eggnog.taxa.tar.gz
  rm -f eggnog.taxa.tar.gz
fi

echo
echo "== eggNOG DB 준비 완료 =="
ls -lh "$DBDIR"
