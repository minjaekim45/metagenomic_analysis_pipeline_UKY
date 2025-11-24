#!/bin/bash

#SBATCH --time=12:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=bakta            # Job name
#SBATCH --ntasks=32                 # Number of cores for the job. Same as SBATCH -n
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e ./zz.out/bakta-%j.err    # Error file for this job.
#SBATCH -o ./zz.out/bakta-%j.out    # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: sbatch ./AMRfinder.bash [folder]

   folder      Path to the folder containing the '16.checkm2' directory.

   " >&2 ;
   exit 1 ;
fi ;

dir=$(readlink -f $1) ;

for i in 20.amr_finder ; do
   [[ -d $i ]] || mkdir $i
done

for i in 20.amr_finder/results ; do
   [[ -d $i ]] || mkdir $i
done

# Source path to Conda environments
source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh

# The number of CPUs or threads
THR=32

#---------------------------------------------------------
# Run AMRfinder

echo "==[ 20.amr_finder: $(date) ]" ;
cd $dir/20.amr_finder ;

conda activate amr-finder

for i in $dir/16.checkm2/output/good_quality/*.fa ; do
   name=$(basename "$i" .fa)
   amrfinder -p $dir/11.bakta/results/$name/$name.faa -g $dir/11.bakta/results/$name/$name.gff3 \
   | -n $dir/11.bakta/results/$name/$name.fna --plus --annotation_format bakta --name $name
done ;

conda deactivate

#---------------------------------------------------------

echo "Done: $(date)." ;
