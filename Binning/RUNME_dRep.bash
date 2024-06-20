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
if [[ ! -e 17.checkm ]] ; then
   echo "Cannot locate the 17.checkm directory, aborting..." >&2
   exit 1
fi ;

cd $dir

# Get a list of subdirectories within the main directory
checkm_dir=($(find "17.checkm" -mindepth 1 -maxdepth 1 -type d))

# Loop through each sub-directory
for subdir in "${checkm_dir[@]}"; do

   b=$(basename $subdir)
   OPTS="SAMPLE=$b,FOLDER=$dir"

   # Move into the sub-directory
   cd "$dir/17.checkm/$b" || exit

   sbatch --export="$OPTS" -J "dRep-$b" --account=$QUEUE --partition=$QOS --error "$dir"/"dRep-$b"-%j.err -o "$dir"/"dRep-$b"-%j.out  $pac/run_dRep.pbs | grep .;

done
