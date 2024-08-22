#!/bin/bash


if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: ./RUNME.bash folder queue QOS

   folder	Path to the folder containing the raw reads. The raw reads must be in FastQ format,
   		and filenames must follow the format: <name>.<sis>.fastq, where <name> is the name
		of the sample, and <sis> is 1 or 2 indicating which sister read the file contains.
		Use only '1' as <sis> if you have single reads.
   partition	select a partition (if no provided, shas will be used)
   qos			select a quality of service (if no provided, normal will be used)
   
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







