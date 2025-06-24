#!/bin/bash

if [[ "$1" == "" || "$1" == "-h" || "$2" == "" ]] ; then
   echo "
   Usage: ./RUNME.bash [folder] [data_type] [queue] [QOS]

   folder      Path to the folder containing the '04.trimmed_fasta' directory, where the trimmed reads
               are stored. Trimmed reads must be in interposed FastA format. Filenames must follow the
	       format: <name>.CoupledReads.fa, where <name> is the name of the sample. If non-paired,
	       the filenames must follow the format: <name>.SingleReads.fa. If both suffixes are found
	       for the same <name> prefix, they are both used.
   data_type   Type of datasets in the project. Options include: mg (for metagenomes), scg (for single-cell
               genomes), g (for traditional genomes), or t (for transcriptomes).
   partition   Select a partition (if not provided, coa_mki314_uksr will be used)
   qos         Select a quality of service (if not provided, normal will be used)
   
   " >&2 ;
   exit 1 ;
fi ;

TYPE=$2
if [[ "$TYPE" != "g" && "$TYPE" != "mg" && "$TYPE" != "scg" && "$TYPE" != "t" ]] ; then
   echo "Unsupported data type: $TYPE." >&2 ;
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

dir=$(readlink -f $1)
pac=$(dirname $(readlink -f $0))
cwd=$(pwd)

#---------------------------------------------------------

cd $dir
if [[ ! -e 04.trimmed_fasta ]] ; then
   echo "Cannot locate the 04.trimmed_fasta directory, aborting..." >&2
   exit 1
fi

for i in 10.assembly ; do
   [[ -d $i ]] || mkdir $i
done

for i in $dir/04.trimmed_fasta/*.SingleReads.fa ; do
   b=$(basename $i .SingleReads.fa)
   touch $dir/04.trimmed_fasta/$b.CoupledReads.fa
done

for i in $dir/04.trimmed_fasta/*.CoupledReads.fa ; do
   b=$(basename $i .CoupledReads.fa)
   [[ -d $dir/10.assembly/$b ]] && continue
   mkdir $dir/10.assembly/$b
   OPTS="SAMPLE=$b,FOLDER=$dir,TYPE=$TYPE"
   if [[ -s $dir/04.trimmed_fasta/$b.SingleReads.fa ]] ; then
      OPTS="$OPTS,FA=$dir/04.trimmed_fasta/$b.SingleReads.fa"
      [[ -s $dir/04.trimmed_fasta/$b.CoupledReads.fa ]] \
	 && OPTS="$OPTS,FA_RL2=$dir/04.trimmed_fasta/$b.CoupledReads.fa"
   else
      OPTS="$OPTS,FA=$dir/04.trimmed_fasta/$b.CoupledReads.fa"
   fi
   sbatch --export="$OPTS" -J "idba-$b" --account=$QUEUE --partition=$QOS --error "$dir"/zz.out/"idba-$b"-%j.err -o "$dir"/zz.out/"idba-$b"-%j.out  $pac/run.pbs | grep .;
done ;

#---------------------------------------------------------

echo "Done: $(date)." ;
