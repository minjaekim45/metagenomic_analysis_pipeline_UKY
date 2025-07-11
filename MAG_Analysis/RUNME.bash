#!/bin/bash

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: ./RUNME.bash [folder] [filtration] [queue] [QOS]

   folder     Path to the folder containing the 04.trimmed_fasta directory. The trimmed reads must be
              in interposed FastA format & separated pairs format in case you have paired-end reads,
              and filenames must follow the format: <name>.CoupledReads.fa, where <name> is the name
              of the sample & in case of paire-end reads, you also need to have <name>.1.fa and
              <name>.2.fa. If non-paired, the filenames must follow the format: <name>.SingleReads.fa.
   partition  Select a partition (If not provided, coa_mki314_uksr will be used).
   qos        Select a quality of service (If not provided, normal will be used).
   " >&2 ;
   
   exit 1 ;
fi ;

TOOL=$2
if [[ "$TOOL" == "" ]] ; then
   TOOL="standard"
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

for i in 11.bakta 12.deep_arg 13.vfdb 14.microbe_census; do
   [[ -d $i ]] || mkdir $i
done

if [[ "$TOOL" == "deeparg" ]] ; then
   # Download database
   sbatch --wait $pac/deeparg_db.bash $dir/12.deep_arg
fi ;
wait

for i in $dir/04.trimmed_fasta/*.CoupledReads.fa ; do
   b=$(basename $i .CoupledReads.fa)
   OPTS="SAMPLE=$b,FOLDER=$dir"
   if [[ -s $dir/04.trimmed_fasta/$b.SingleReads.fa ]] ; then
      OPTS="$OPTS,FA=$dir/04.trimmed_fasta/$b.SingleReads.fa"
   else
      OPTS="$OPTS,FA=$dir/04.trimmed_fasta/$b.CoupledReads.fa"
   fi
   # Launch job
   sbatch --export="$OPTS" -J "ARG_VF-$b" --account=$QUEUE --partition=$QOS --error "$dir"/"ARG_VF-$b"-%j.err -o "$dir"/"ARG_VF-$b"-%j.out  $pac/run.pbs | grep .;
done ;


#for i in $dir/16.checkm2/output/good_quality/*.fa ; do
#   b=$(basename $i .fa)
#   OPTS="SAMPLE=$b,FOLDER=$dir"
#   # Launch job
#   sbatch --export="$OPTS" -J "ARG_VF-$b" --account=$QUEUE --partition=$QOS --error "$dir"/zz.out/"$TOOL-$b"-%j.err -o "$dir"/zz.out/"$TOOL-$b"-%j.out  $pac/run_$TOOL.pbs | grep .;
#done ;
