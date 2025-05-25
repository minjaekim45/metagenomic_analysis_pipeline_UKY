#!/bin/bash

#SBATCH --time=06:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=index            # Job name
#SBATCH --ntasks=4                  # Number of cores for the job. Same as SBATCH -n 1
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

genome=$2
if [[ "$genome" == "" ]] ; then
   genome="GRCh38_p14"
fi ;

accession=$3
if [[ "$accession" == "" ]] ; then
   accession="GCF_000001405.40"
fi ;

dir=$(readlink -f $1) ;
gen="${genome%_*}" ;
ome="${genome#*_}" ;

#---------------------------------------------------------
# Unzips file

source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh
conda activate ncbi_datasets

cd $dir ;
datasets download genome accession $accession --include gff3,rna,cds,protein,genome,seq-report --filename human_${gen}_dataset.zip

mkdir human_genome ;
mv human_${gen}_dataset.zip $dir/human_genome ;

cd $dir/human_genome ;
unzip human_${gen}_dataset.zip -d human_dataset

cd ./human_dataset/ncbi_dataset/data/$accession ;
cp ${accession}_${gen}.${ome}_genomic.fna $dir/human_genome/${accession}_${gen}.${ome}_genomic.fa ;

conda deactivate

#---------------------------------------------------------
# Performs indexing

#conda activate bmtagger

#cd $dir ;

#bmtool -d ./human_genome/${accession}_${gen}.${ome}_genomic.fa -o ./human_genome/$genome.bitmask -A 0 -w 18 ;
#srprism mkindex -i ./human_genome/${accession}_${gen}.${ome}_genomic.fa -o ./human_genome/$genome.srprism -M 7168 ;
#makeblastdb -in ./human_genome/${accession}_${gen}.${ome}_genomic.fa -dbtype nucl ;

#conda deactivate

#---------------------------------------------------------
# Performs indexing

#conda activate hocort

#cd $dir ;

#hocort index bowtie2 --input ./human_genome/${accession}_${gen}.${ome}_genomic.fasta --output ./human_genome/$genome ;

#conda deactivate

#---------------------------------------------------------
# Performs indexing

conda activate bowtie2

cd $dir ;

bowtie2-build --seed 133540 --threads 4 ./human_genome/${accession}_${gen}.${ome}_genomic.fa ./human_genome/GRCh38 ;

conda deactivate

#---------------------------------------------------------

echo "Done: $(date)." ;
