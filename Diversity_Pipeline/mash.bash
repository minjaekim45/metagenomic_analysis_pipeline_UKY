#!/bin/bash

#SBATCH --time=12:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=mash             # Job name
#SBATCH --ntasks=4                  # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e mash-%j.err              # Error file for this job.
#SBATCH -o mash-%j.out              # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: ./mash.bash <folder>

   folder      Path to the folder containing the '07.mash' directory.
   
   " >&2 ;
   exit 1 ;
fi ;

dir=$(readlink -f $1) ;

#---------------------------------------------------------

# Change enveomics and mash paths to yours 
enve=/project/mki314_uksr/enveomics/Scripts
mash=/project/mki314_uksr/Software/mash-Linux64-v2.3/mash

# The number of CPUs or threads
THR=4

#---------------------------------------------------------
# Create distance matrix

cd $dir/07.mash ;

readlink -f *.msh > mash_list.txt ;

echo "List created"

"$mash" paste mash.all -l mash_list.txt ;

echo "Ready to make distance matrix"

"$mash" dist -t mash.all.msh mash.all.msh > Mash_dist.txt ;

#---------------------------------------------------------

echo "Done"