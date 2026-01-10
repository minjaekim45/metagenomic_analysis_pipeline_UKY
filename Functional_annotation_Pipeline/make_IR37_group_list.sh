#!/bin/bash
set -euo pipefail

# Bakta result root (where IR37_0d.2, IR37_06-5d.3 ... directories live)
BAKTA_ROOT="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/11.bakta/results"

# Output file for group prefixes
GROUP_LIST="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/IR37_group_list.txt"

echo "BAKTA_ROOT = ${BAKTA_ROOT}"
echo "GROUP_LIST = ${GROUP_LIST}"
echo

cd "${BAKTA_ROOT}"

# Collect directory names starting with IR37_, strip everything after first '.',
# make them unique and sorted, write to GROUP_LIST
ls -d IR37_* 2>/dev/null \
  | xargs -n1 basename \
  | cut -d'.' -f1 \
  | sort -u > "${GROUP_LIST}"

echo "== Group list created =="
wc -l "${GROUP_LIST}"
echo
cat "${GROUP_LIST}"
