#!/bin/bash

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: ./RUNME.bash folder queue

   folder	Path to the folder containing the 04.trimmed_fasta folder. The
		trimmed reads must be in interposed FastA format, and filenames
		must follow the format: <name>.CoupledReads.fa, where <name> is
		the name of the sample. If non-paired, the filenames must follow
		the format: <name>.SingleReads.fa. If both suffixes are found
		for the same <name> prefix, they are both used.
   partition	select a partition (if no provided, smem will be used)
   qos			select a quality of service (if no provided, normal will be used)
   
   Nonpareil: alignment option will be used. Otherwise, default.
   Mash: k-mer size will be 25. (Mash's default is 21).
         sketch size will be 100000. (Mash's default is 1000).
   Please see the references for these two methods before you run this pipeline.
   To change any options for nonpareil and mash, please modify your commands in run.pbs.

   " >&2 ;
   exit 1 ;
fi ;

QUEUE=$2
if [[ "$QUEUE" == "" ]] ; then
   QUEUE="smem"
fi ;

QOS=$3
if [[ "$QOS" == "" ]] ; then
   QOS="normal"
fi ;

dir=$(readlink -f $1)
pac=$(dirname $(readlink -f $0))
cwd=$(pwd)

cd $dir
if [[ ! -e 04.trimmed_fasta ]] ; then
   echo "Cannot locate the 04.trimmed_fasta directory, aborting..." >&2
   exit 1
fi ;

for i in 06.nonpareil 07.mash ; do
   [[ -d $i ]] || mkdir $i
done

for i in $dir/04.trimmed_fasta/*.SingleReads.fa ; do
   b=$(basename $i .SingleReads.fa)
   touch $dir/04.trimmed_fasta/$b.CoupledReads.fa
done

# Launch jobs

for i in $dir/04.trimmed_fasta/*.CoupledReads.fa ; do
   b=$(basename $i .CoupledReads.fa)
   OPTS="SAMPLE=$b,FOLDER=$dir"
   if [[ -s $dir/04.trimmed_fasta/$b.SingleReads.fa ]] ; then
      OPTS="$OPTS,FA=$dir/04.trimmed_fasta/$b.SingleReads.fa"
   else
      OPTS="$OPTS,FA=$dir/04.trimmed_fasta/$b.CoupledReads.fa"
   fi
   # Launch job
   sbatch --export="$OPTS" -J "Diversity-$b" --partition=$QUEUE --qos=$QOS --error "$dir"/"Diversity-$b"-%j.err -o "$dir"/"Diversity-$b"-%j.out  $pac/run.pbs | grep .;
done 
