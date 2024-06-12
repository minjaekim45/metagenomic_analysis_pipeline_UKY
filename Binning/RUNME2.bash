#!/bin/bash

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: ./RUNME2.bash folder queue
   Prerequisite: Need to run Binning Pipeline. 

   folder	Path to the folder containing the 14.maxbin 
		 		  
   queue	Select a queue (if not provided, all from ncshpc203 to ncshpc207).

   This Pipeline will generates the checkM results and select only good quality MAGs (Completeness - 5 * contamination)
   Also, it will give you two clusters of genomes (ANI95 and ANI99)

   " >&2 ;
   exit 1 ;
fi ;

QUEUE=$2
if [[ "$QUEUE" == "" ]] ; then
   QUEUE="shas"
fi ;

dir=$(readlink -f $1)
pac=$(dirname $(readlink -f $0))
cwd=$(pwd)

cd $dir
if [[ ! -e 14.maxbin2 ]] ; then
   echo "Cannot locate the 14.maxbin2 directory, aborting..." >&2
   exit 1
fi ;

for i in 17.checkm ; do
   [[ -d $i ]] || mkdir $i
done

# Launch jobs

OPTS="SAMPLE=$b,FOLDER=$dir"
qsub -v "$OPTS" -N "CheckM" -R y -pe multicore 8 -q $QUEUE $pac/run2.pbs | grep .
