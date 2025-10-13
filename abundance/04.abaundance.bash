#!/bin/bash
#SBATCH --time=12:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=04.adundance   # Job name
#SBATCH --ntasks=4                  # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e /scratch/sag239/BHG.metagenome/zz.TMP/04.abundance-%j.err             # Error file for this job.
#SBATCH -o /scratch/sag239/BHG.metagenome/zz.TMP/04.abundance-%j.out             # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: sbatch ./04.abundance.bash [folder]

   folder      Path to the folder containing *.tad80.tsv. 

   " >&2 ;
   exit 1 ;
fi ;
dir=$(readlink -f $1) ;
cd $dir/29.TAD80/
for i in abundance ; do
   [[ -d $i ]] || mkdir $i
done
# WB=$HOME/shared3/projects/WaterBodies
AGS=$dir/14.microbe_census/MicrobeCensus_average_genome_size.txt

[[ -e 04.abundance.tsv ]] && rm 04.abundance.tsv

cd $dir/29.TAD80/abundance
for i in $dir/29.TAD80/TAD80/*.tad80.tsv ; do
  ds=$(basename $i .tad80.tsv)
  norm=$(grep "^$ds\s" $AGS | cut -f 2)
  awk '{print $1/'$norm'}' $i > ${ds}.abundance.txt
done
cd $dir/29.TAD80/TAD80
echo -e "Bin\t$(ls *.tad80.tsv | perl -pe 's/\.tad80\.tsv$//' | tr "\n" "\t" \
  | perl -pe 's/\t$//')" > $dir/29.TAD80/abundance/04.abundance.tsv
cd $dir/29.TAD80/abundance   
paste $dir/TAD80/TAD80/03.tad.list $(ls *.abundance.txt) >> 04.abundance.tsv
