#!/bin/bash

# Directory containing the .fastq files
directory="./"  # You can specify the directory path if needed

# Output file
output_file="statistics_output.txt"

# Initialize output file, write header
echo -e "File\tSequence_ID\tRead_Length\tContigs\tReads_G\tReads_C\tReads_A\tReads_T\tN50" > "$output_file"

# Iterate over each .fastq file in the directory
for file in "$directory"/*.fastq; do
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
