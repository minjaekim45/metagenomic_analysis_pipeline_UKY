#!/bin/bash

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: ./RUNME.bash folder filtration queue QOS

   folder	Path to the folder containing the raw reads. The raw reads must be in FastQ format,
   		and filenames must follow the format: <name>.<sis>.fastq, where <name> is the name
		of the sample, and <sis> is 1 or 2 indicating which sister read the file contains.
		Use only '1' as <sis> if you have single reads.
   filtration	Method of contamination removal. Use 'fast' if you are removing general contamination,
   		use 'human' if you need to remove human sequences as well. (if not provided, fast
     		will be used)
   partition	Select a partition (if not provided, coa_mki314_uksr will be used)
   qos		Select a quality of service (if not provided, normal will be used)
   
   " >&2 ;
   exit 1 ;
fi ;

con=$2
if [[ "$con" == "" ]] ; then
   con="fast"
fi ;

QUEUE=$3
if [[ "$QUEUE" == "" ]] ; then
   QUEUE="coa_mki314_uksr"
fi ;

QOS=$4
if [[ "$QOS" == "" ]] ; then
   QOS="normal"
fi ;

dir=$(readlink -f $1) ;
pac=$(dirname $(readlink -f $0)) ;
cwd=$(pwd) ;

#---------------------------------------------------------

cd $dir ;
for i in 01.raw_reads 02.trimmed_reads 03.read_quality 04.trimmed_fasta trim_output zz.TMP ; do
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
   sbatch --export="$OPTS" -J "Trim-$b" --account=$QUEUE --partition=$QOS --error "$dir"/trim_output/"Trim-$b"-%j.err -o "$dir"/trim_output/"Trim-$b"-%j.out  $pac/run_$con.pbs | grep .;
done ;

echo 'Done'
