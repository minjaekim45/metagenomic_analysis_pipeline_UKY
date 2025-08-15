#!/bin/bash

#SBATCH --time=12:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=amr              # Job name
#SBATCH --ntasks=8                  # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e /zz.out/amr-%j.err       # Error file for this job.
#SBATCH -o /zz.out/amr-%j.out       # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: sbatch ./AMRfinder.bash [folder]

   folder      Path to the folder containing the '16.checkm2' directory.
   
   " >&2 ;
   exit 1 ;
fi ;

dir=$(readlink -f $1) ;

# Change database path to yours
database=

# Source path to Conda environments
source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh

# The number of CPUs or threads
THR=8

#---------------------------------------------------------
# Run AMRfinder

echo "==[ 20.amr_finder: $(date) ]" ;
cd $dir/20.amr_finder ;

conda activate amr-finder

for i in $dir/16.checkm2/output/good_quality/*.fa ; do
amrfinder -p test_prot.fa -g test_prot.gff -n test_dna.fa -O Escherichia --plus
done ;

conda deactivate

#---------------------------------------------------------

echo "Done: $(date)." ;
