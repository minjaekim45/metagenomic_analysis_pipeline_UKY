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
> "$dir"/stats.txt

for i in $dir/01.raw_reads/*.fastq ; do
   b1=$(basename $i .fastq) ;
   line_count_1=$(wc -l "$i") ;
   echo "$b1: $line_count_1;" >> "stats.txt"
done ;

for i in $dir/02.trimmed_reads/*_val_*.fq ; do
   b2=$(basename $i .fq) ;
   line_count_2=$(wc -l "$i") ;
   echo "$b2: $line_count_2;" >> "stats.txt"
done ;

for i in $dir/02.trimmed_reads/*.filtered_*.fq ; do
   b3=$(basename $i .fq) ;
   line_count_3=$(wc -l "$i") ;
   echo "$b3: $line_count_3;" >> "stats.txt"
done ;

#---------------------------------------------------------

echo "Done: $(date)." ;
