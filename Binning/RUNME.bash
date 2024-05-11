#!/bin/bash

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: ./RUNME.bash folder queue
   Note: In this pipeline, we will use all of your metagenomes to create abundance profiles for each assembly. 
         However, this approach might not be proper for certain metagenome datasets you have.
         BEFORE RUNNING THIS, please think carefully and modify this pipeline as it needed.
         Also, we will use only metabat2 but you can manually add other binning methods and use dasTool to combine/dereplicate them.
   Prerequisite: Need to run Trimming Pipeline & Assembly Pipeline

   folder	Path to the folder containing the 04.trimmed_fasta folder. The
		trimmed reads must be in interposed FastA format & separated pairs format in case you have paired-end reads
                , and filenames must follow the format: <name>.CoupledReads.fa, where <name> is
		the name of the sample & in case of paired-end reads, you also need to have 
                <name>.1.fa and <name>.2.fa. If non-paired, the filenames must follow
		the format: <name>.SingleReads.fa.  
   partition	select a partition (if no provided, shas will be used)
   qos			select a quality of service (if no provided, normal will be used)

   To change any other options for maxbin and add more binning methods, please modify your commands in run.pbs

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

dir=$(readlink -f $1)
pac=$(dirname $(readlink -f $0))
cwd=$(pwd)

cd $dir
if [[ ! -e 04.trimmed_fasta ]] ; then
   echo "Cannot locate the 04.trimmed_fasta directory, aborting..." >&2
   exit 1
fi ;

cd $dir
if [[ ! -e 05.assembly ]] ; then
   echo "Run Assembly Pipeline first, aborting..." >&2
   exit 1
fi ;

cd $dir

# Add this to add more binning methods (followings are example lines)
for i in 15.metabat2; do
   [[ -d $i ]] || mkdir $i
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
   sbatch --export="$OPTS" -J "Metabat2-$b" --partition=$QUEUE --qos=$QOS --error "$dir"/"Metabat2-$b"-%j.err -o "$dir"/"Metabat2-$b"-%j.out  $pac/run.pbs | grep .;
done 
