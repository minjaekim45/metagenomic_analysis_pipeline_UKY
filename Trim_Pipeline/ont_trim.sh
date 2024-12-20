#!/bin/bash
#SBATCH --job-name=nanoporetrim_FSI927    # Job name
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)
#SBATCH --nodes=1               # Number of cores to allocate. Same as SBATCH -N (Don't use this option for mpi jobs)
#SBATCH --ntasks=1            # Number of cores to allocate. Same as SBATCH -n
#SBATCH -t 12:00:00              # Time limit for the job (REQUIRED)
#SBATCH -e nanoporetrim_FSI927-%j.err
#SBATCH -o nanoporetrim_FSI927-%j.out

echo "Job running on SLURM NODELIST: $SLURM_NODELIST "

#setup miniconda environment
source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh

#---------------------------------------------------------

# Check for the input FASTQ file and an output directory
if [[ "$#" -ne 2 ]]; then
    echo "Usage: $0 <input_fastq> <output_directory>"
    exit 1
fi

# Assign input arguments to variables
#input fastq: /scratch/rcsa230/Nanopore_YEASTF927/YeastF927_nanopore.fastq
##output_dir: 

input_fastq=$1
output_dir=$2

# Create output directory if it doesn't exist
mkdir -p $output_dir

# Define output file names
nanofilt_fastq="${output_dir}/trimmed_reads_nanofilt.fastq"
porechop_fastq="${output_dir}/trimmed_reads_nanofilt_porechop.fastq"
hocort_fastq="${output_dir}/trimmed_reads_nanofilt_porechop_hocort.fastq"
GENOME=/scratch/rcsa230/genomes/contam

# # Step 1: Trim reads for quality using NanoFilt
# #blast program execution command (app name is from second column from table above)
# singularity run --app nanofilt2800 /share/singularity/images/ccs/conda/amd-conda19-rocky9.sinf NanoFilt -q 20 -l 500 --headcrop 10 $input_fastq > $nanofilt_fastq
# echo "Trimming reads with NanoFilt..."

# # Step 2: Trim adapters using Porechop
# conda activate /project/mki314_uksr/miniconda3/envs/porechop
# echo "Trimming adapters with Porechop..."
# porechop -i $nanofilt_fastq -o $porechop_fastq

#Step 3: Filter contamination with HoCoRt
conda activate hocort
echo "Filtering contamination with hocort..."
hocort map kraken2minimap2 -m $GENOME/cat_genomes_minimap2.mmi -k $GENOME/cat_genomes_kraken2_db -i $porechop_fastq -o $hocort_fastq --filter true
# Deactivate Conda environment
conda deactivate
echo "Trimming and Filtering complete. Final reads are in $hocort_fastq."