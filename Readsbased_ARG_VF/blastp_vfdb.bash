#!/bin/bash

#SBATCH --time=24:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=blstp            # Job name
#SBATCH --ntasks=32                 # Number of cores for the job. Same as SBATCH -n
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e ./zz.out/blstp-%j.err    # Error file for this job.
#SBATCH -o ./zz.out/blstp-%j.out    # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: sbatch ./blastp_vfdb.bash [folder]

   folder      Path to the folder containing the '21.blastp_vfdb' directory.

   " >&2 ;
   exit 1 ;
fi ;

dir=$(readlink -f $1) ;
