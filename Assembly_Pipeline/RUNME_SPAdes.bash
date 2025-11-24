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
   queue	select a queue (if no provided, all ncshpc2* will be used)

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
if [[ ! -e 04.trimmed_fasta ]] ; then
   echo "Cannot locate the 04.trimmed_fasta directory, aborting..." >&2
   exit 1
fi
for i in 05.assembly ; do
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
   sbatch --export="$OPTS" -J "SPADES-$b" --account=$QUEUE --partition=$QOS --error "$dir"/"SPADES-$b"-%j.err -o "$dir"/"SPADES-$b"-%j.out  $pac/run_SPAdes.pbs | grep .;
done ;

echo 'Done'
