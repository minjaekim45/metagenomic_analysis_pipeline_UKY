#!/bin/bash

#SBATCH --time=01:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=argDB            # Job name
#SBATCH --ntasks=4                  # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e argDB-%j.err             # Error file for this job.
#SBATCH -o argDB-%j.out             # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: sbatch ./deeparg_db.bash [folder]

   folder      Path to the folder containing the raw reads. A directory named 'human
               genome' will be created to contain the dataset. Most recent dataset as
               of publishing will be used by default, unless instructed otherwise.

   " >&2 ;
   exit 1 ;
fi ;

dir=$(readlink -f $1) ;

# Source path to Conda environments
source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh

#---------------------------------------------------------
# Download DeepARG database

conda activate deeparg

deeparg download_data -o $dir/database

conda deactivate

#---------------------------------------------------------

echo "Done: $(date)." ;
