#!/bin/bash

#SBATCH --time=06:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=stats            # Job name
#SBATCH --ntasks=8                  # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e stats-%j.err             # Error file for this job.
#SBATCH -o stats-%j.out             # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: sbatch ./stats.bash [folder]

   folder      Path to the folder containing the '01.raw_reads' and '02.trimmed_reads' directories.
   
   " >&2 ;
   exit 1 ;
fi ;

dir=$(readlink -f $1) ;
cd $dir ;

for i in 2zz.stats ; do
   [[ -d $i ]] || mkdir $i
done ;

cd $dir/zz.stats ;

for i in 01.raw_reads 02.trimmed_reads ; do
   if [[ ! -d $i ]] ; then mkdir $i ; fi ;
done ;

source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh

#---------------------------------------------------------
# FastQC analysis

conda activate multiqc

echo "==[ 01.raw_reads: $(date) ]" ;
cd $dir/01.raw_reads ;

multiqc -o $dir/2zz.stats/01.raw_reads

echo "==[ 02.trimmed_reads: $(date) ]" ;
cd $dir/02.trimmed_reads ;

multiqc -o $dir/2zz.stats/02.trimmed_reads

#---------------------------------------------------------

echo "Done: $(date)." ;
