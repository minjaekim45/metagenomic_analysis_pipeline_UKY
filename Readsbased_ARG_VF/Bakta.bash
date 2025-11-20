#!/bin/bash

#SBATCH --time=24:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=bakta            # Job name
#SBATCH --ntasks=32                  # Number of cores for the job. Same as SBATCH -n
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e ./zz.out/bakta-%j.err     # Error file for this job.
#SBATCH -o ./zz.out/bakta-%j.out     # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: sbatch ./Bakta.bash [folder]

   folder      Path to the folder containing the '16.checkm2' directory.

   " >&2 ;
   exit 1 ;
fi ;

dir=$(readlink -f $1) ;

for i in 11.bakta ; do
   [[ -d $i ]] || mkdir $i
done

for i in 11.bakta/results ; do
   [[ -d $i ]] || mkdir $i
done

# Change database path to yours
database=/pscratch/mki314_uksr/bakta_db/database/db

# Source path to Conda environments
source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh

# The number of CPUs or threads
THR=32

#---------------------------------------------------------
# Run Bakta

echo "==[ 11.bakta: $(date) ]" ;
cd $dir/11.bakta ;

conda activate bakta

for i in $dir/16.checkm2/output/good_quality/*.fa ; do
   name=$(basename "$i" .fa)
   bakta --db $database --prefix $name --output ./results/"$name" $i
done ;

conda deactivate

#---------------------------------------------------------

echo "Done: $(date)." ;
