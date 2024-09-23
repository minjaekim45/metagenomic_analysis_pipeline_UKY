#!/bin/bash


if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: ./RUNME.bash folder queue QOS
   
   folder
   
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
if [[ ! -e 04.trimmed_fasta ]] ; then
   echo "Cannot locate the 04.trimmed_fasta directory, aborting..." >&2
   exit 1
fi ;

for i in 08.metaphlan ; do
   [[ -d $i ]] || mkdir $i
done

for i in $dir/04.trimmed_fasta/*.CoupledReads.fa ; do
   b=$(basename $i .CoupledReads.fa)
   OPTS="SAMPLE=$b,FOLDER=$dir"
   if [[ -s $dir/04.trimmed_fasta/$b.SingleReads.fa ]] ; then
      OPTS="$OPTS,FA=$dir/04.trimmed_fasta/$b.SingleReads.fa"
   else
      OPTS="$OPTS,FA=$dir/04.trimmed_fasta/$b.CoupledReads.fa"
   fi
   # Launch job
   sbatch --export="$OPTS" -J "Diversity-$b" --account=$QUEUE --partition=$QOS --error "$dir"/"Profile-$b"-%j.err -o "$dir"/"Profile-$b"-%j.out  $pac/run.pbs | grep .;
done 

echo 'Done'
