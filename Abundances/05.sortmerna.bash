#!/bin/bash
if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: ./05.sortmerna.bash [folder] [queue] [QOS]

   folder      Path to FASTQ/fastq_files 
   queue       Select a partition (if not provided, coa_mki314_uksr will be used)
   QOS         Select a quality of service (if not provided, normal will be used)

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
echo "Working in folder: $dir" ;
pac=$(dirname $(readlink -f $0)) ;
echo "Scripts located in: $pac" ;


#---------------------------------------------------------------------------------------------------------------------------------------------
cd $dir ;
mkdir -p 30.SortmeRNA ;
if [[ ! -e "30.SortmeRNA" ]] ; then
   echo "Cannot locate the 30.SortmeRNA directory, aborting..." >&2
   exit 1
fi ;

for i in "$dir"/04.trimmed_fasta/*_1.fa ; do

   base=$(basename "$i")
   SAMPLE="${base%_1.fa}"
   OPTS="SAMPLE=$SAMPLE,FOLDER=$dir"
   
   echo -ne "$SAMPLE\t"
   # Launch job
   sbatch \
      --export="$OPTS" \
      -J "SORTMERNA_$SAMPLE" \
      --account=$QUEUE --partition=$QOS \
      --error "$dir"/zz.TMP/"SortmeRNA_$SAMPLE"-%j.err -o "$dir"/zz.TMP/"SortmeRNA_$SAMPLE"-%j.out \
      $pac/05.sortmerna.pbs $SAMPLE $dir | grep .

done > "$dir/30.SortmeRNA/05.sortmerna.pbs.jobids"

