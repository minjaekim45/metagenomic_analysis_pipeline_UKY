#!/bin/bash

#SBATCH --time=06:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=index            # Job name
#SBATCH --ntasks=4                  # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e index-%j.err             # Error file for this job.
#SBATCH -o index-%j.out             # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: ./index.bash folder file_name index_name

   folder       Path to the folder containing the compressed genome dataset from NCBI
   
   file_name    Name of the compressed file. Must be a .zip file.

   index_name   Desired name for the index you are creating. Defaults to GRCh38_p14 to
                represent the most recent human genome dataset.
   
   " >&2 ;
   exit 1 ;
fi ;

FILE=$2
if [[ "$FILE" == "" ]] ; then
   FILE="human_GRCh38_dataset.zip"
fi ;

IND=$3
if [[ "$IND" == "" ]] ; then
   IND="GRCh38_p14"
fi ;

dir=$(readlink -f $1) ;

#---------------------------------------------------------

source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh

conda activate ncbi_datasets

cd $dir ;
mkdir human_genome ;
mv $FILE $dir/human_genome ;

cd human_genome ;
unzip $dir -d human_dataset
datasets rehydrate --directory human_dataset/

conda deactivate

#---------------------------------------------------------

conda activate hocort

cd ./human_dataset/ncbi_dataset/data/GCF_000001405.40 ;
cp GCF_000001405.40_GRCh38.p14_genomic.fna $dir/human_genome/GCF_000001405.40_GRCh38.p14_genomic.fasta ;

cd $dir

hocort index bowtie2 --input ./human_genome/GCF_000001405.40_GRCh38.p14_genomic.fasta --output ./human_genome/GRCh38_p14 ;

conda deactivate

