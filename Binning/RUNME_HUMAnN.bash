#!/bin/bash

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: ./RUNME.bash [folder] [queue] [QOS]
   
   folder      Path to the folder containing the '04.trimmed_fasta' directory, where the trimmed reads
               are stored. Filenames must follow the format: <name>.CoupledReads.fa, where <name> is the
               name of the sample.
   
   " >&2 ;
   exit 1 ;
fi ;

QUEUE=$2
if [[ "$QUEUE" == "" ]] ; then
   QUEUE="coa_mki314_uksr"
fi ;

QOS=$3
if [[ "$QOS" == "" ]] ; then
   QOS="normal"
fi ;

dir=$(readlink -f $1) ;
pac=$(dirname $(readlink -f $0)) ;
cwd=$(pwd) ;

cd $dir
if [[ ! -e 17.checkm ]] ; then
   echo "Cannot locate the 04.trimmed_fasta directory, aborting..." >&2
   exit 1
fi ;

for i in 19.HUMAnN3; do
   [[ -d $i ]] || mkdir $i
done

# Get a list of subdirectories within the main directory
checkm_dir=($(find "17.checkm" -mindepth 1 -maxdepth 1 -type d))

# Loop through each sub-directory
for subdir in "${checkm_dir[@]}"; do

   b=$(basename $subdir)
   c=$(basename $subdir/output/good_quality/*.fa .fa)
   OPTS="SAMPLE=$b,READ=$c,FOLDER=$dir"

   mkdir $dir/19.HUMAnN3/$b

   # Move into the sub-directory
   cd "$dir/17.checkm/$b" || exit

   sbatch --export="$OPTS" -J "HUMAnN-$b" --account=$QUEUE --partition=$QOS --error "$dir"/"HUMAnN-$b"-%j.err -o "$dir"/"HUMAnN-$b"-%j.out  $pac/run_HUMAnN.pbs | grep .;

done
