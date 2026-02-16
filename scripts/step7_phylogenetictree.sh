#!/bin/bash
#SBATCH --time=18:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=phylogenetic_tree           # Job name
#SBATCH --ntasks=1                  # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e 39.phylogenetic_tree-%j.err             # Error file for this job.
#SBATCH -o 39.phylogenetic_tree-%j.out             # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)
#SBATCH --mem=10G

set -euo pipefail

source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh
conda activate python

python scripts/gtdbtk_summary_to_taxonomy_tree.py FASTQ/fastq_files/17.gtdbtk/gtdbtk.all.summary.tsv
