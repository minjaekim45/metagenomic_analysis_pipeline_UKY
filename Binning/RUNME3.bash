#!/bin/bash

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: ./RUNME3.bash folder queue
   Prerequisite: Need to run Binning Pipeline. 

   folder	Path to the folder containing the 14.maxbin 
		 		  
   queue	Select a queue (if not provided, all from ncshpc203 to ncshpc207).

   This Pipeline will generates the 

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
   echo "Cannot locate the 14.maxbin directory, aborting..." >&2
   exit 1
fi ;

cd $dir
if [[ ! -e 17.checkm ]] ; then
   echo "Cannot locate the 17.checkm directory, aborting..." >&2
   exit 1
fi ;

# Launch jobs

OPTS="SAMPLE=$b,FOLDER=$dir"
qsub -v "$OPTS" -N "GTDBTK" -R y -pe multicore 60 -q $QUEUE $pac/run3.pbs | grep .
