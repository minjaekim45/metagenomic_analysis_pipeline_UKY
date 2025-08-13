#!/bin/bash

#SBATCH --time=12:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=bakta            # Job name
#SBATCH --ntasks=8                  # Number of cores for the job. Same as SBATCH -n
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e /zz.out/bakta-%j.err     # Error file for this job.
#SBATCH -o /zz.out/bakta-%j.out     # Output file for this job.
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

# Change enveomics path to yours
enve=/project/mki314_uksr/enveomics/Scripts

# Source path to Conda environments
source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh

# The number of CPUs or threads
THR=8

#---------------------------------------------------------
# Build Bakta Database

echo "==[ 11.bakta: $(date) ]" ;
cd $dir/11.bakta ;

conda activate bakta

echo "Done: $(date)." ;
bakta_db download --output ./database --type full
echo "Done: $(date)." ;
wait
echo "Done: $(date)." ;

#---------------------------------------------------------
# Run Bakta

for i in $dir/16.checkm2/output/good_quality/*.fa ; do
mkdir ./results/"$i"
bakta --db ./database --output ./results/"$i" --threads $THR $i
done ;

conda deactivate

#---------------------------------------------------------

echo "Done: $(date)." ;
