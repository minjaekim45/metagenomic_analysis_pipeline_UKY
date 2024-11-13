#!/bin/bash

#SBATCH --time=06:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=stats            # Job name
#SBATCH --ntasks=4                  # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e stats-%j.err             # Error file for this job.
#SBATCH -o stats-%j.out             # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: sbatch ./stats.bash [folder]

   folder      Path to the folder containing the 'trim_output' directory.
   
   " >&2 ;
   exit 1 ;
fi ;

dir=$(readlink -f $1) ;

#---------------------------------------------------------
# Pull statistics from .err files

cd $dir ;
output_file="statistics.txt"

for i in $dir/trim_output/*.err ; do 
   sed -n "73,82p" "$i" >> "$output_file"
   sed -n "301,310p" "$i" >> "$output_file"
   sed -n "545,562p" "$i" >> "$output_file"
   echo -n "," >> "$output_file"
done ;

echo "Done: $(date)."


