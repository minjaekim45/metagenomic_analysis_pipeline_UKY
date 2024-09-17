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
   Usage: ./index.bash folder genome accession

   folder      Path to the folder containing the compressed genome dataset from NCBI.
               Compressed file should follow the format of 'human_GRCh38_dataset.zip',
               though you may use a more recent version.
   
   " >&2 ;
   exit 1 ;
fi ;

# Specify the directory containing your files with "_#.fastq"
dir="$1"
cd "$dir"

# Iterate over each file in the specified directory
for fname in *.fastq; do
  if [[ "$fname" == *"_"* ]]; then
    # If the file name contains an underscore
    name="${fname%\.*}"
    extension="${fname#$name}"
    newname="${name//_/.}"
    newfname="$newname""$extension"
    if [ "$fname" != "$newfname" ]; then
      echo mv "$fname" "$newfname"
      mv "$fname" "$newfname"
    fi
  else
    # If the file name does not contain an underscore
    name="${fname%\.*}"
    extension="${fname#$name}"
    newfname=${name}.1${extension}
    if [ "$fname" != "$newfname" ]; then
      echo mv "$fname" "$newfname"
      mv "$fname" "$newfname"
    fi
  fi
done
