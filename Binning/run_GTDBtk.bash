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
   Usage: sbatch ./index.bash [folder]

   folder      Path to the folder containing 17.checkm
     
   " >&2 ;
   exit 1 ;
fi ;

dir=$(readlink -f $1) ;
cd $dir

if [[ ! -e 17.checkm ]] ; then
   echo "Cannot locate the 17.checkm directory, aborting..." >&2
   exit 1
fi ;

for i in 18.gtdbtk; do
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

echo "==[ 17.checkm: $(date) ]"

cd $dir/17.checkm/output/good_quality

readlink -f *.fa > list.txt

cat list.txt |  awk '{print $NF}' FS=/ | sed -e 's/\.fasta$//' > ID.txt

paste list.txt ID.txt > batchfile.txt

singularity run --env GTDBTK_DATA_PATH=/gtdbtk_data/database -B $database --app gtdbtk240 $container gtdbtk classify_wf --batchfile $dir/17.checkm/output/good_quality/batchfile.txt --out_dir $dir/18.gtdbtk/ --mash_db ../09.mash/mash.all.msh --extension fa --cpus $THR

cd $dir/18.gtdbtk/

#----------------------------------------------------------
echo "Done: $(date)."
