#!/bin/bash

#SBATCH --time=06:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=index            # Job name
#SBATCH --ntasks=4                  # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e index-%j.err             # Error file for this job.
#SBATCH -o index-%j.out             # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)

dir=/scratch/jwme229/kori_project

for i in $dir/15.metabat2/* ; do
  if [[ -d $i ]] ; then
    cp $dir/15.metabat2/$i/* $dir/15.metabat2/binned/
  fi
done
