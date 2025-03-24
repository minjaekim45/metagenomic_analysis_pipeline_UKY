#!/bin/bash

#SBATCH --time=06:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=index            # Job name
#SBATCH --ntasks=16                  # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e index-%j.err             # Error file for this job.
#SBATCH -o index-%j.out             # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: sbatch ./index.bash [folder] [genome] [accession]

   folder      Path to the folder containing the compressed genome dataset from NCBI.
               Compressed file should follow the format of 'human_GRCh38_dataset.zip',
               though you may use a more recent version.
   
   genome      Name of the genome assembly. Defaults to 'GRCh38_p14' to represent the
               most recent human genome dataset.
   
   accession   NCBI accession number. Defaults to 'GCF_000001405.40' to represent the
               most recent human genome dataset.
   
   " >&2 ;
   exit 1 ;
fi ;

dir=$(readlink -f $1) ;
cd $dir

if [[ ! -e 15.metabat2 ]] ; then
   echo "Cannot locate the 15.metabat2 directory, aborting..." >&2
   exit 1
fi ;

for i in 17.checkm; do
   [[ -d $i ]] || mkdir $i
done

#---------------------------------------------------------

enve=/project/mki314_uksr/enveomics/Scripts
THR=16

source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh
conda activate CheckM

#---------------------------------------------------------

mkdir $dir/17.checkm/output

cd $dir/15.metabat2/binned

checkm lineage_wf -t $THR -x fa --tab_table -f $dir/17.checkm/output/qs.o1.tsv ./ $dir/17.checkm

cd $dir/17.checkm

awk -F "\t" '{x=$12; y=$13 * 5} {if (x - y >= 50) print $0}' ./output/qs.o1.tsv > ./output/high_qual.tsv

awk -F "\t" '{x = $12 - $13 * 5} {$(NF+1)=x;}1' OFS="\t" ./output/high_qual.tsv > ./output/high_qual_w_score.tsv

awk '{print $1}' ./output/high_qual_w_score.tsv > ./output/list.txt

mkdir ./output/good_quality

mv ./output/high_qual_w_score.tsv ./output/good_quality

while IFS= read -r line; do
   cp $dir/15.metabat2/binned/"$line".fa $dir/17.checkm/output/good_quality
done < ./output/list.txt

awk '{print $0, "$b"}' > output.txt

#---------------------------------------------------------

conda deactivate
echo "Done: $(date)."
