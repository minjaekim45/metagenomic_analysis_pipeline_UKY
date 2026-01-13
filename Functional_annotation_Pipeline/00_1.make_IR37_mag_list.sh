#!/bin/bash
set -euo pipefail
# Usage: chmod +x make_IR37_mag_list.sh 
# ./make_IR37_mag_list.sh

# Bakta root
BAKTA_ROOT="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/11.bakta/results"

# File path to save MAG list
MAG_LIST="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/IR37_mag_list.txt"

echo "BAKTA_ROOT = ${BAKTA_ROOT}"
echo "MAG_LIST   = ${MAG_LIST}"
echo

# Move to Bakta directory
cd "${BAKTA_ROOT}"

# Make MAG lists
ls -d IR37_* 2>/dev/null | sort | xargs -n1 basename > "${MAG_LIST}"

echo "== done =="
echo "Total MAGS:"
wc -l "${MAG_LIST}"

