#!/bin/bash

#SBATCH --time=12:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=checkm2           # Job name
#SBATCH --ntasks=20                 # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e CheckM2-%j.err            # Error file for this job.
#SBATCH -o CheckM2-%j.out            # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: sbatch ./run_CheckM.bash [folder]

   folder      Path to the folder containing 15.metabat2   
   
   " >&2 ;
   exit 1 ;
fi ;

dir=$(readlink -f $1) ;
cd $dir

if [[ ! -e 15.metabat2 ]] ; then
   echo "Cannot locate the 15.metabat2 directory, aborting..." >&2
   exit 1
fi ;

for i in 16.checkm2; do
   [[ -d $i ]] || mkdir $i
done

#---------------------------------------------------------

enve=/project/mki314_uksr/enveomics/Scripts
DB_path=/share/examples/MCC/checkm2_database/CheckM2_database/uniref100.KO.1.dmnd
THR=20

source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh
conda activate checkm2
#checkm2=/project/mki314_uksr/Software/checkm2/bin/checkm2

#---------------------------------------------------------

mkdir $dir/16.checkm2/output

cd $dir/15.metabat2/binned

#$checkm2 predict --threads $THR -x fa --tab_table --input . --output-directory $dir/16.checkm2

checkm2 predict -t $THR -x fa --input . --output-directory $dir/16.checkm2/output --database_path $DB_path

cd $dir/16.checkm2

awk -F "\t" '{x=$12; y=$13 * 5} {if (x - y >= 50) print $0}' ./output/qs.o1.tsv > ./output/high_qual.tsv

awk -F "\t" '{x = $12 - $13 * 5} {$(NF+1)=x;}1' OFS="\t" ./output/high_qual.tsv > ./output/high_qual_w_score.tsv

awk '{print $1}' ./output/high_qual_w_score.tsv > ./output/list.txt

mkdir ./output/good_quality

mv ./output/high_qual_w_score.tsv ./output/good_quality

while IFS= read -r line; do
   cp $dir/15.metabat2/binned/"$line".fa $dir/17.checkm/output/good_quality
done < ./output/list.txt

awk '{print $0, "$b"}' > output.txt

conda deactivate

#---------------------------------------------------------
echo "Done: $(date)."
