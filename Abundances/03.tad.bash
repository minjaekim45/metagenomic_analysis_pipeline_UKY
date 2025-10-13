#!/bin/bash
if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: ./03.map.bash [folder] [queue] [QOS]

   folder      Path to the folder containing merged FASTA file (01.hq-set.fna).It is in 28.index directory. 
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
pac=$(dirname $(readlink -f $0)) ;

#---------------------------------------------------------------------------------------------------------------------------------------------
cd $dir
if [[ ! -e "29.TAD80" ]] ; then
   echo "Cannot locate the 29.TAD80 directory, aborting..." >&2
   exit 1
fi ;

cd "$dir/29.TAD80"
for i in TAD80 ; do
   [[ -d "$i" ]] || mkdir "$i"
done ;

cd $dir/29.TAD80/map
tail -n 1 *.log | perl -pe 's/^==> //' | perl -pe 's/\.log <==//' \
  | perl -pe 's/%.*//' | paste - - - | perl -pe 's/\t$//' \
  > $dir/29.TAD80/TAD80/02.map.tsv

cd $dir/28.index
# Launch seq-depth estimates
grep "^>" 01.hq-set.fa | perl -pe 's/:.*//' | perl -pe 's/^>//' \
  | sort | uniq > $dir/29.TAD80/TAD80/03.tad.list

for i in $dir/29.TAD80/map/*.bam ; do
  [[ $i == *.sorted.bam ]] && continue
  b=$(basename $i .bam)
  OPTS="SAMPLE=$b,FOLDER=$dir"
  [[ -s ${b}.bg.gz ]] && continue
  echo -ne "$b\t"
  # Launch job
   sbatch --export="$OPTS" -J "TAD_$b" --account=$QUEUE --partition=$QOS --error "$dir"/zz.TMP/"TAD_$b"-%j.err -o "$dir"/zz.TMP/"TAD_$b"-%j.out  $pac/03.tad.pbs | grep .

done > "$dir/29.TAD80/TAD80/03.tad.pbs.jobids"

