#!/bin/bash
#SBATCH --time=12:00:00             # Time limit for the job
#SBATCH --job-name=gtdbtk_v2.5.2    # Job name
#SBATCH --nodes=1                   # Number of nodes
#SBATCH --ntasks=48                 # Number of cores
#SBATCH --partition=normal          # Partition
#SBATCH -e zz.out/GTDBtk-%j.err     # Error file
#SBATCH -o zz.out/GTDBtk-%j.out     # Output file
#SBATCH --account=coa_mki314_uksr   # Project account

#------------------------ INPUT CHECK ----------------------------
if [[ "$1" == "" || "$1" == "-h" ]]; then
   echo "
   Usage: sbatch ./run_GTDBtk_v2.5.2.bash [folder]

   folder      Path to the folder containing 16.checkm2
   " >&2
   exit 1
fi

dir=$(readlink -f "$1")
cd "$dir" || { echo "Cannot cd to $dir, aborting..." >&2; exit 1; }

if [[ ! -d 16.checkm2 ]]; then
   echo "Cannot locate the 16.checkm2 directory in $dir, aborting..." >&2
   exit 1
fi

mkdir -p 17.gtdbtk

#------------------------ ENVIRONMENT ----------------------------
# Activate your GTDB-Tk v2.5.2 conda environment from /scratch
source /pscratch/mki314_uksr/miniconda3/etc/profile.d/conda.sh
conda activate /scratch/$USER/gtdbtk_env

# Set the database path for GTDB-Tk release 226
export GTDBTK_DATA_PATH=/scratch/$USER/gtdbtk_env/share/gtdbtk-2.5.2/db

THR=48
CPU=1

#------------------------ RUNNING GTDB-Tk ------------------------
echo "==[ Starting GTDB-Tk v2.5.2: $(date) ]"

cd "$dir/16.checkm2/output/good_quality" || { echo "Missing good_quality directory, aborting..." >&2; exit 1; }

# Generate batchfile for all .fa genomes
readlink -f *.fa > list.txt
awk -F/ '{gsub(/\.fa$/, "", $NF); gsub(/\.fasta$/, "", $NF); print $NF}' list.txt > ID.txt
paste list.txt ID.txt > batchfile.txt

# Run GTDB-Tk
gtdbtk classify_wf \
  --batchfile "$dir/16.checkm2/output/good_quality/batchfile.txt" \
  --out_dir "$dir/17.gtdbtk/" \
  --extension fa \
  --cpus "$THR" \
  --pplacer_cpus "$CPU"

echo "==[ GTDB-Tk Finished: $(date) ]"
