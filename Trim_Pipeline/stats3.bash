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

#---------------------------------------------------------

# Directory containing the .fastq files
dir1="$dir"/01.raw_reads ;

# Output file
output_file="statistics_output.txt"

# Initialize output file, write header
echo -e "File\tSequence_ID\tRead_Length\tContigs\tReads_G\tReads_C\tReads_A\tReads_T\tN50" > "$output_file"

# Iterate over each .fastq file in the directory
for file in "$dir1"/*.fastq; do
  # Check if the file exists
  if [ -f "$file" ]; then
    # Initialize counters and variables
    total_reads=0
    total_contigs=0
    reads_g=0
    reads_c=0
    reads_a=0
    reads_t=0
    lengths=()
    
    # Process each sequence in the fastq file
    while read -r line1 && read -r line2 && read -r line3 && read -r line4; do
      # line1: sequence identifier (e.g. @SEQ_ID)
      # line2: sequence (e.g. AGCT...)
      
      seq="${line2}"  # The sequence of the read
      read_length=${#seq}  # Length of the read
      
      # Add length to the list for N50 calculation
      lengths+=("$read_length")
      
      # Count reads with specific bases
      ((total_reads++))
      ((reads_g+=($(echo -n "$seq" | grep -o 'G' | wc -l))))
      ((reads_c+=($(echo -n "$seq" | grep -o 'C' | wc -l))))
      ((reads_a+=($(echo -n "$seq" | grep -o 'A' | wc -l))))
      ((reads_t+=($(echo -n "$seq" | grep -o 'T' | wc -l))))
      
      # Count contigs (sequence identifiers for contigs can be derived based on the number of records in the file)
      ((total_contigs++))
      
    done < "$file"

    # Calculate N50
    if [ ${#lengths[@]} -gt 0 ]; then
      sorted_lengths=($(for length in "${lengths[@]}"; do echo $length; done | sort -n))
      total_length=$(IFS=+; echo "$((${sorted_lengths[*]}))")
      half_length=$((total_length / 2))
      
      sum_length=0
      N50=0
      for length in "${sorted_lengths[@]}"; do
        ((sum_length+=length))
        if [ $sum_length -ge $half_length ]; then
          N50=$length
          break
        fi
      done
    else
      N50=0
    fi

    # Output the statistics for the file
    echo -e "$file\t$total_reads\t$total_contigs\t$reads_g\t$reads_c\t$reads_a\t$reads_t\t$N50" >> "$output_file"
  fi
done
