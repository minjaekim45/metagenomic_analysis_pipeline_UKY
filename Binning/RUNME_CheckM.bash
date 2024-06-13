#!/bin/bash

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: ./RUNME.bash folder queue
   Note: 
   Prerequisite: Need to run Binning

   folder       Path to the folder containing the 15.metabat2 folder
   partition	select a partition (if none provided, shas will be used)
   qos			select a quality of service (if none provided, normal will be used)

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

dir=$(readlink -f $1)
pac=$(dirname $(readlink -f $0))
cwd=$(pwd)

cd $dir
if [[ ! -e 15.metabat2 ]] ; then
   echo "Cannot locate the 15.metabat2 directory, aborting..." >&2
   exit 1
fi ;

cd $dir

for i in 17.checkm; do
   [[ -d $i ]] || mkdir $i
done

# Get a list of subdirectories within the main directory
sub_directories=($(find "15.metabat2" -mindepth 1 -maxdepth 1 -type d))

# Loop through each sub-directory
for subdir in "${sub_directories[@]}"; do
    # Move into the sub-directory
        cd "15.metabat2/$subdir" || exit
    
         checkm lineage_wf -x fa --tab_table ./ /scratch/jwme229/raw_data_files/17.checkm/30


    # Check if the sub-directory exists
    if [ -d "$main_directory/$subdir" ]; then
        # Move into the sub-directory
        cd "$main_directory/$subdir" || exit

        # Execute the command
        

        # Move back to the main directory
        cd "$OLDPWD" || exit
    else
        echo "Directory '$subdir' does not exist."
    fi
done




for i in $dir/04.trimmed_fasta/*.CoupledReads.fa ; do
   b=$(basename $i .CoupledReads.fa)
   OPTS="SAMPLE=$b,FOLDER=$dir"
   if [[ -s $dir/04.trimmed_fasta/$b.SingleReads.fa ]] ; then
      OPTS="$OPTS,FA=$dir/04.trimmed_fasta/$b.SingleReads.fa"
   else
      OPTS="$OPTS,FA=$dir/04.trimmed_fasta/$b.CoupledReads.fa"
   fi
   sbatch --export="$OPTS" -J "Metabat2-$b" --account=$QUEUE --partition=$QOS --error "$dir"/"Metabat2-$b"-%j.err -o "$dir"/"Metabat2-$b"-%j.out  $pac/run.pbs | grep .;
done 