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

# Create the output file and write the headers
output_file="stats.txt"
echo -e "Sample;Original;After Quality;After Hocort" > "$dir"/stats.txt ;

# Iterate over each .fastq file in the directory
for i in $dir/01.raw_reads/*.fastq ; do
   b=$(basename $i .fastq) ;
   
   # Count the lines in the .fastq file
   fastq_lines=$(wc -l < "$i") ;

   # Count the lines in the quality-trimmed .fq file
   fq_lines_val=0 ;
   fq_file_val=$dir/02.trimmed_reads/${b}_val_*.fq ;
   fq_lines_val=$(wc -l < "$fq_file_val") ;

   # Count the lines in the host-contaminant free .fq file
   fq_lines_fil=0 ;
   fq_file_fil="$dir/02.trimmed_reads/${b}_filtered.fq" ;
   fq_lines_fil=$(wc -l < "$fq_file_fil") ;

   # Append the results to stats.txt
   echo -e "$b;$fastq_lines;$fq_lines_val;$fq_lines_fil" >> "$output_file" ;
done

#---------------------------------------------------------

echo "Done: $(date)." ;
