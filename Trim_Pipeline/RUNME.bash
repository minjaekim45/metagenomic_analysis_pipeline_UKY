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
   QUEUE="shas"
fi ;

QOS=$3
if [[ "$QOS" == "" ]] ; then
   QOS="normal"
fi ;


dir=$(readlink -f $1) ;
pac=$(dirname $(readlink -f $0)) ;
cwd=$(pwd) ;

cd $dir ;
for i in 01.raw_reads 02.trimmed_reads 03.read_quality 04.trimmed_fasta zz.TMP ; do
   if [[ ! -d $i ]] ; then mkdir $i ; fi ;
done ;

for i in $dir/*.1.fastq ; do 
   b=$(basename $i .1.fastq) ;
   OPTS="SAMPLE=$b,FOLDER=$dir"
   if [[ -e "$b.2.fastq" ]] ; then
      mv "$b".1.fastq 01.raw_reads/ ;
      mv "$b".2.fastq 01.raw_reads/ ;
   else
      mv "$b".1.fastq 01.raw_reads/ ;
   fi
   # Launch job
   sbatch --export="$OPTS" -J "Trim-$b" --partition=$QUEUE --qos=$QOS --error "$dir"/"Trim-$b"-%j.err -o "$dir"/"Trim-$b"-%j.out  $pac/run.pbs | grep .;
done ;

echo 'Done'
# Hi Greg!