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

#---------------------------------------------------------

cd $dir ;

cd $dir/01.raw_reads/ ;
../sequence-stats/src/sequence-stats -s fastq > $dir/01.stats.txt

cd $dir/02.trimmed_reads/ ;
../sequence-stats/src/sequence-stats -s *_val.fq > $dir/02.trim_stats.txt

cd $dir/04.trimmed_reads/ ;
../sequence-stats/src/sequence-stats -s *_filtered.fq > $dir/02.fltd_stats.txt

cd $dir/04.trimmed_reads/ ;
../sequence-stats/src/sequence-stats -s fastq > $dir/02.tagd_stats.txt


