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
if [[ ! -e 14.maxbin2 ]] ; then
   echo "Cannot locate the 14.maxbin directory, aborting..." >&2
   exit 1
fi ;

cd $dir
if [[ ! -e 17.checkm ]] ; then
   echo "Cannot locate the 17.checkm directory, aborting..." >&2
   exit 1
fi ;

cd $dir

# Get a list of subdirectories within the main directory
sub_directories=($(find "15.metabat2" -mindepth 1 -maxdepth 1 -type d))

# Loop through each sub-directory
for subdir in "${sub_directories[@]}"; do

   b=$(basename $subdir)
   OPTS="SAMPLE=$b,FOLDER=$dir"
   
   mkdir $dir/17.checkm/$b
   
   # Move into the sub-directory
   cd "$dir/15.metabat2/$b" || exit
   
   sbatch --export="$OPTS" -J "CheckM-$b" --account=$QUEUE --partition=$QOS --error "$dir"/"CheckM-$b"-%j.err -o "$dir"/"CheckM-$b"-%j.out  $pac/run_CheckM.pbs | grep .;

done




# Launch jobs

OPTS="SAMPLE=$b,FOLDER=$dir"
qsub -v "$OPTS" -N "GTDBTK" -R y -pe multicore 60 -q $QUEUE $pac/run3.pbs | grep .
