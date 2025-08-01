#!/bin/bash

#SBATCH --time=06:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=gtdbtk           # Job name
#SBATCH --ntasks=48                 # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e zz.out/GTDBtk-%j.err     # Error file for this job.
#SBATCH -o zz.out/GTDBtk-%j.out     # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: sbatch ./run_GTDBtk.bash [folder]

   folder      Path to the folder containing 16.checkm2
     
   " >&2 ;
   exit 1 ;
fi ;

dir=$(readlink -f $1) ;
cd $dir

if [[ ! -e 16.checkm2 ]] ; then
   echo "Cannot locate the 16.checkm2 directory, aborting..." >&2
   exit 1
fi ;

for i in 17.gtdbtk; do
   [[ -d $i ]] || mkdir $i
done

#---------------------------------------------------------

enve=/project/mki314_uksr/enveomics/Scripts
THR=48

source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh

# Container and database paths remain the same for anyone running on the MCC cluster
container=/share/singularity/images/ccs/conda/amd-conda15-rocky8.sinf
database=/share/examples/MCC/gtdbtk/release220:/gtdbtk_data/database

#---------------------------------------------------------
# Run GTDBtk

echo "==[ 16.checkm2: $(date) ]"

cd $dir/16.checkm2/output/good_quality

readlink -f *.fa > list.txt

cat list.txt |  awk '{print $NF}' FS=/ | sed -e 's/\.fasta$//' > ID.txt

paste list.txt ID.txt > batchfile.txt

singularity run --env GTDBTK_DATA_PATH=/gtdbtk_data/database -B $database --app gtdbtk240 $container gtdbtk classify_wf --batchfile $dir/16.checkm2/output/good_quality/batchfile.txt --out_dir $dir/17.gtdbtk/ --mash_db $dir/17.gtdbtk --extension fa --cpus $THR

cd $dir/17.gtdbtk/

#----------------------------------------------------------
echo "Done: $(date)."
