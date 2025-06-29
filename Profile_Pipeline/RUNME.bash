#!/bin/bash

if [[ "$1" == "" || "$1" == "-h" || "$2" == "" ]] ; then
   echo "
   Usage: ./RUNME.bash [folder] [tool] [queue] [QOS]
   
   folder      Path to the folder containing the '04.trimmed_fasta' directory, where the trimmed reads
               are stored. Filenames must follow the format: <name>.CoupledReads.fa, where <name> is the
               name of the sample.
   tool        Name of the taxonomic classification tool that you want to use. Options are 'metaphlan4',
               'kraken2', or 'kaiju'.
   partition   Select a partition (if not provided, coa_mki314_uksr will be used)
   qos         Select a quality of service (if not provided, normal will be used)
   
   " >&2 ;
   exit 1 ;
fi ;

TOOL=$2
if [[ "$TOOL" != "metaphlan4" && "$TYPE" != "kraken2" && "$TYPE" != "kaiju" ]] ; then
   echo "Unsupported taxonomy tool." >&2 ;
   exit 1;
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

cd $dir
if [[ ! -e 04.trimmed_fasta ]] ; then
   echo "Cannot locate the 04.trimmed_fasta directory, aborting..." >&2
   exit 1
fi ;

if [[ "$TOOL" == "metaphlan4" ]] ; then
   for i in 05.metaphlan4 ; do
      [[ -d $i ]] || mkdir $i
   done ;
elif [[ "$TOOL" == "kraken2" ]] ; then
   for i in 06.kraken2 ; do
      [[ -d $i ]] || mkdir $i
   done ;
elif [[ "$TOOL" == "kaiju" ]] ; then
   for i in 07.kaiju ; do
      [[ -d $i ]] || mkdir $i
   done ;
fi ;

for i in $dir/04.trimmed_fasta/*.CoupledReads.fa ; do
   b=$(basename $i .CoupledReads.fa)
   OPTS="SAMPLE=$b,FOLDER=$dir"
   if [[ -s $dir/04.trimmed_fasta/$b.SingleReads.fa ]] ; then
      OPTS="$OPTS,FA=$dir/04.trimmed_fasta/$b.SingleReads.fa"
   else
      OPTS="$OPTS,FA=$dir/04.trimmed_fasta/$b.CoupledReads.fa"
   fi
   # Launch job
   sbatch --export="$OPTS" -J "Profile-$b" --account=$QUEUE --partition=$QOS --error "$dir"/zz.out/"Profile-$TOOL-$b"-%j.err -o "$dir"/zz.out/"Profile-$TOOL-$b"-%j.out  $pac/run_$TOOL.pbs | grep .;
done 

#---------------------------------------------------------

echo "Done: $(date)." ;
