#!/bin/bash

#SBATCH --time=06:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=kr_db            # Job name
#SBATCH --ntasks=4                  # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e kr_db-%j.err             # Error file for this job.
#SBATCH -o kr_db-%j.out             # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: sbatch ./kraken_db.bash [folder]

   folder      Path to the folder containing the '04.trimmed_fasta' directory.
   
   " >&2 ;
   exit 1 ;
fi ;

dir=$(readlink -f $1) ;

#---------------------------------------------------------

# Container path remains the same for anyone running on the MCC cluster
container=/share/singularity/images/ccs/conda/amd-conda18-rocky8.sinf

#---------------------------------------------------------
# Build database

cd $dir ;

singularity run --app kraken22132 $container kraken2-build --standard --threads 24 --db $dir/database

#---------------------------------------------------------

echo "Done: $(date)." ;
