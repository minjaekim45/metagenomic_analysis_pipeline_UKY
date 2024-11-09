#!/bin/bash

#SBATCH --time=06:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=merge            # Job name
#SBATCH --ntasks=4                  # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e merge-%j.err             # Error file for this job.
#SBATCH -o merge-%j.out             # Output file for this job.
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

dir=$(readlink -f $1) ;

#---------------------------------------------------------
# Merges tables

cd $dir ;

# Container path remains the same for anyone running on the MCC cluster
container=/share/singularity/images/ccs/conda/amd-conda15-rocky8.sinf

singularity run --app metaphlan410 $container merge_metaphlan_tables.py *_profile.txt > merged_abundance_table.txt

grep -E "s__|SRS" merged_abundance_table.txt \
| grep -v "t__" \
| sed "s/^.*|//g" \
| sed "s/SRS[0-9]*-//g" \
> merged_abundance_table_species.txt

