#!/bin/bash
#SBATCH --time=12:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=04.adundance_MAGs   # Job name
#SBATCH --ntasks=4                  # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e 04.abundance_MAGs-%j.err             # Error file for this job.
#SBATCH -o 04.abundance_MAGs-%j.out             # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: sbatch ./04.abundance.bash [folder]

   folder      Path to the folder containing *.tad80.tsv. They should be in 29.TAD80/TAD80/ directory.

   " >&2 ;
   exit 1 ;
fi ;
dir=$(readlink -f $1) ;
cd $dir
for i in abundance ; do
   [[ -d $i ]] || mkdir $i
done

#----------------------------------------------------------------------------------------------------------------------------------------------------------
cd ../14.microbe_census

{
  printf "sample\tgenome_equivalents\n"
  for i in *.microbecensus.out; do
    b=$(basename "$i" .microbecensus.out)
    ge=$(
      awk -F':' '/^genome_equivalents:/ {
        val=$2
        gsub(/^[ \t]+/, "", val)      # trim leading spaces/tabs
        gsub(/[ \t\r]+$/, "", val)    # trim trailing spaces/tabs/CR
        print val
        exit
      }' "$i"
    )
    printf "%s\t%s\n" "$b" "$ge"
  done
} > MicrobeCensus_genome_equivalents.txt

# In next line, chenage the path to your MicrobeCensus_genome_equivalents.txt
ge="/scratch/sag239/BHG.metagenome/14.microbe_census/MicrobeCensus_genome_equivalents.txt"
#-----------------------------------------------------------------------------------------------------------------------------------------------------------

cd $dir/abundance

for i in $dir/TAD80/*.tad80.tsv ; do
  ds=$(basename $i .tad80.tsv)
  norm=$(grep "^$ds\s" $ge | cut -f 2)
  awk '{print $2/'$norm'}' $i > ${ds}.abundance.txt
done ;
cd $dir/TAD80
echo -e "Bin\t$(ls *.tad80.tsv \
  | perl -pe 's/\.tad80\.tsv$//' \
  | tr '\n' '\t' \
  | perl -pe 's/\t$//')" > "$dir/abundance/04.abundance.tsv"
cd $dir/abundance   
paste $dir/TAD80/03.tad.list $(ls *.abundance.txt) >> 04.abundance.tsv
