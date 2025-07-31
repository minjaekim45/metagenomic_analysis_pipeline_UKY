#!/bin/bash

#SBATCH --time=12:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=CheckM2          # Job name
#SBATCH --ntasks=20                 # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e ./zz.out/CheckM2-%j.err  # Error file for this job.
#SBATCH -o ./zz.out/CheckM2-%j.out  # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: sbatch ./CheckM.bash [folder]

   folder      Path to the folder containing the '15.metabat2' directory.   
   
   " >&2 ;
   exit 1 ;
fi ;

dir=$(readlink -f $1) ;
cd $dir ;

if [[ ! -e 15.metabat2 ]] ; then
   echo "Cannot locate the 15.metabat2 directory, aborting..." >&2
   exit 1
fi ;

for i in 16.checkm2; do
   [[ -d $i ]] || mkdir $i
done

#---------------------------------------------------------

# Change enveomics path to yours
enve=/project/mki314_uksr/enveomics/Scripts

# Source path to Conda environments
source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh

# Database path remains the same for anyone on the MCC Cluster
DB_path=/share/examples/MCC/checkm2_database/CheckM2_database/uniref100.KO.1.dmnd

# The number of CPUs or threads
THR=20

#---------------------------------------------------------
# Run CheckM2

conda activate checkm2

mkdir $dir/16.checkm2/output ;

cd $dir/15.metabat2/binned ;

checkm2 predict -t $THR -x fa --input . --output-directory $dir/16.checkm2/output --database_path $DB_path

cd $dir/16.checkm2 ;

awk -F "\t" '{x=$2; y=$3 * 5} {if (x - y >= 50) print $0}' ./output/quality_report.tsv > ./output/high_qual.tsv

awk -F "\t" '{x = $2 - $3 * 5} {$(NF+1)=x;}1' OFS="\t" ./output/high_qual.tsv > ./output/high_qual_w_score.tsv

awk '{print $1}' ./output/high_qual_w_score.tsv > ./output/list.txt

mkdir ./output/good_quality

mv ./output/high_qual_w_score.tsv ./output/good_quality

while IFS= read -r line; do
   cp $dir/15.metabat2/binned/"$line".fa $dir/16.checkm2/output/good_quality
done < ./output/list.txt

cd $dir/16.checkm2/output/good_quality ;

awk 'BEGIN{FS=OFS="\t"}{print $1,$2,$3}' high_qual_w_score.tsv > quality_info.tsv
awk 'BEGIN { FS="\t"; OFS="," } {$1=$1; print}' quality_info.tsv > quality_info.csv
awk -v header="genome,completeness,contamination" 'BEGIN { print header } { print }' "quality_info.csv" > temp.csv && mv temp.csv "quality_info.csv"

conda deactivate

#---------------------------------------------------------

echo "Done: $(date)."
