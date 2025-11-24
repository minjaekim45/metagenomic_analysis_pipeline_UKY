#!/bin/bash

#SBATCH --time=24:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=dRep             # Job name
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=6
#SBATCH --mem=32G                    
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e ./zz.out/dRep-%j.err     # Error file for this job.
#SBATCH -o ./zz.out/dRep-%j.out     # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: sbatch ./dRep.bash [folder]

   folder      Path to the folder containing the '16.checkm2' directory.
   
   " >&2 ;
   exit 1 ;
fi ;

dir=$(readlink -f $1) ;
cd $dir ;

if [[ ! -e 16.checkm2 ]] ; then
   echo "Cannot locate the 16.checkm2 directory, aborting..." >&2
   exit 1
fi ;

for i in 18.dRep; do
   [[ -d $i ]] || mkdir $i
done

#---------------------------------------------------------
# The number of CPUs or threads
THR=6

#---------------------------------------------------------
# Compare and Dereplicate

mkdir $dir/18.dRep/output ;

cd $dir/16.checkm2/output/good_quality ;

# Run dRep compare
singularity run --app drep3500 /share/singularity/images/ccs/conda/amd-conda19-rocky9.sinf \
dRep compare $dir/18.dRep/output/compare \
-p $THR \
-g $dir/16.checkm2/output/good_quality/*.fa \
--S_algorithm fastANI

# dRep dereplicate
singularity run --app drep3500 /share/singularity/images/ccs/conda/amd-conda19-rocky9.sinf \
dRep dereplicate $dir/18.dRep/output/dereplicate \
-p $THR \
-g $dir/16.checkm2/output/good_quality/*.fa \
--genomeInfo "$dir/16.checkm2/output/good_quality/quality_info.csv" \
--completeness 0 \
--contamination 100 \

#---------------------------------------------------------

echo "Done: $(date)."