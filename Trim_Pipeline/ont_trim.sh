#!/bin/bash
#SBATCH --job-name=nanoporetrim_FSI927_without_headcrop    # Job name
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)
#SBATCH --nodes=1               # Number of cores to allocate. Same as SBATCH -N (Don't use this option for mpi jobs)
#SBATCH --ntasks=1            # Number of cores to allocate. Same as SBATCH -n
#SBATCH --mem=32g
#SBATCH -t 12:00:00              # Time limit for the job (REQUIRED)
#SBATCH -e /scratch/sag239/logs/nanoporetrim_FSI927-%j.err
#SBATCH -o /scratch/sag239/logs/nanoporetrim_FSI927-%j.out

echo "Job running on SLURM NODELIST: $SLURM_NODELIST "

#setup miniconda environment
source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh

#---------------------------------------------------------

# Check for the input FASTQ file and an output directory
if [[ "$#" -ne 2 ]]; then
    echo "Usage: $0 <input_fastq> <output_directory>"
    exit 1
fi

input_fastq=$1
output_dir=$2

# Create output directory if it doesn't exist
mkdir -p $output_dir

# Define output file names
nanofilt_fastq="${output_dir}/trimmed_reads_nanofilt.fastq"
porechop_fastq="${output_dir}/trimmed_reads_nanofilt_porechop.fastq"
hocort_fastq="${output_dir}/trimmed_reads_nanofilt_porechop_hocort.fastq"
GENOME=/scratch/rcsa230/genomes/contam
dir=/scratch/rcsa230/Nanopore_YEASTF927/

# Trim reads for quality using NanoFilt
# #blast program execution command (app name is from second column from table above)
singularity run --app nanofilt2800 /share/singularity/images/ccs/conda/amd-conda19-rocky9.sinf NanoFilt -q 10 -l 1000 $input_fastq > $nanofilt_fastq
echo "Trimming reads with NanoFilt..."

# Trim adapters using Porechop
conda activate /project/mki314_uksr/miniconda3/envs/porechop
echo "Trimming adapters with Porechop..."
porechop -i $nanofilt_fastq -o $porechop_fastq

# Filter contamination with HoCoRt
conda activate hocort
echo "Filtering contamination with hocort..."
hocort map kraken2minimap2 -m $GENOME/cat_genomes_minimap2.mmi -k $GENOME/cat_genomes_kraken2_db -i $porechop_fastq -o $hocort_fastq --filter true

conda deactivate
echo "Trimming and Filtering complete. Final reads are in $hocort_fastq."

cd $dir ;

# Create the output file and write the headers
output_file="stats.txt"
echo -e "Sample;Original;After Nanofilt;After Porechop;After Hocort" > "$dir"/stats.txt ;

# Iterate over each .fastq file in the directory
for i in $dir/*.fastq ; do
   b=$(basename $i .fastq) ;
   
   # Count the lines in the .fastq file
   fastq_lines=$(wc -l < "$i") ;

   # Count the lines in the nanofilt-trimmed .fq file
   fq_lines_nanofilt=0 ;
   fq_lines_nanofilt=$(wc -l < "$nanofilt_fastq") ;

   # Count the lines in the porechop-trimmed .fq file
   fq_lines_porechop=0 ;
   fq_lines_porechop=$(wc -l < "$porechop_fastq") ;

   # Count the lines in the host-contaminant free .fq file
   fq_lines_fil=0 ;
   fq_lines_fil=$(wc -l < "$hocort_fastq") ;

   # Append the results to stats.txt
   echo -e "$b;$fastq_lines;$fq_lines_nanofilt;$fq_lines_porechop;$fq_lines_fil" >> "$output_file" ;
done

#---------------------------------------------------------

echo "Done: $(date)." ;