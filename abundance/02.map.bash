#!/bin/bash
if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: ./02.map.bash [folder] [queue] [QOS]

   folder       Path to the folder containing the trimmed reads. The trimmed reads must be in FastA format,
                and filenames must follow the format: <name>_<sis>.fa, where <name> is the name
                of the sample, and <sis> is 1 or 2 indicating which sister read the file contains.

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
#---------------------------------------------------------------------------------------------------------------------------------------------------------------------
cd "$dir" ;
for i in 29.TAD80 ; do
   if [[ ! -d $i ]] ; then mkdir $i ; fi ;
done ;

cd "$dir/29.TAD80"
for i in map ; do
   [[ -d "$i" ]] || mkdir "$i"
done ;


for i in $dir/04.trimmed_fasta/*_2.fa ; do
   b=$(basename $i _2.fa)
   OPTS="SAMPLE=$b,FOLDER=$dir"


  # Launch job
   sbatch --export="$OPTS" -J "BMAPA_$b" --account=$QUEUE --partition=$QOS --error "$dir"/zz.TMP/"BMAPA-$b"-%j.err -o "$dir"/zz.TMP/"BMAPA-$b"-%j.out  $pac/02.map.pbs | grep .
done ;


# Its goal is to:

# Loop through a list of trimmed reads inside the folder 04.trimmed_fasta.

# For each item in that list, submit a sbatch batch job (02.map.pbs) to the HPC scheduler.

# Pass the sample name as an environment variable ($OPTS) to the sbatch script.

