#!/bin/bash
if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: ./qiime2.sh [folder] [queue] [QOS]

   folder      Path to FASTQ/fastq_files 
   queue       Select a partition (if not provided, coa_mki314_uksr will be used)
   QOS         Select a quality of service (if not provided, normal will be used)

   " >&2 ;
   exit 1 ;
fi ;
echo "starting qiime2.sh" ;
QUEUE=$2
if [[ "$QUEUE" == "" ]] ; then
   QUEUE="coa_mki314_uksr"
fi ;

QOS=$3
if [[ "$QOS" == "" ]] ; then
   QOS="normal"
fi ;

dir=$(readlink -f $1) ;
echo "Working in folder: $dir" ;
pac=$(dirname $(readlink -f $0)) ;
echo "Scripts located in: $pac" ;
#---------------------------------------------------------------------------------------------------------------------------------------------
sbatch --account=$QUEUE --partition=$QOS \
   --error "$dir"/zz.TMP/"Qiime2"-%j.err -o "$dir"/zz.TMP/"Qiime2"-%j.out \
   $pac/qiime2.pbs \
   $dir/30.SortmeRNA/sortmerna/ \
   $dir/31.Qiime2 \
   $pac/databases/qiime2db/silva-138-99-nb-classifier.qza
