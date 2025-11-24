#!/bin/bash
#SBATCH --time=03:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=IR37_assemble      # Job name
#SBATCH --ntasks=1                  # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e slurm-%j.err             # Error file for this job.
#SBATCH -o slurm-%j.out             # Output file for this job.
#SBATCH -A coa_mki314_uksr     # Project allocation account name (REQUIRED)

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

for i in 05.assembly ; do
   [[ -d $i ]] || mkdir $i
done

# --------------------- Collect sample names ---------------------
# Build a unique set of sample basenames from both SingleReads and CoupledReads.
declare -A SAMPLES
shopt -s nullglob

for f in 04.trimmed_fasta/*.CoupledReads.fa 04.trimmed_fasta/*.SingleReads.fa; do
  base="$(basename "$f")"
  # Strip .CoupledReads.fa or .SingleReads.fa
  b="${base%.CoupledReads.fa}"
  b="${b%.SingleReads.fa}"
  SAMPLES["$b"]=1
done

shopt -u nullglob

# --------------------- Submit per-sample if not done ---------------------
for b in "${!SAMPLES[@]}"; do
  outdir="$dir/05.assembly/$b"
  final="$outdir/$b.LargeContigs.fna"

  # Skip if final product already exists (non-empty)
  if [[ -s "$final" ]]; then
    echo "[SKIP] $b (exists: $final)"
    continue
  fi

  # Make sample output dir
  mkdir -p "$outdir"

  # Decide inputs: prefer SingleReads as FA if present; add Coupled as FA_RL2 when available.
  single="$dir/04.trimmed_fasta/$b.SingleReads.fa"
  paired="$dir/04.trimmed_fasta/$b.CoupledReads.fa"

  OPTS="SAMPLE=$b,FOLDER=$dir,TYPE=$TYPE"
  if [[ -s "$single" ]]; then
    OPTS="$OPTS,FA=$single"
    [[ -s "$paired" ]] && OPTS="$OPTS,FA_RL2=$paired"
  else
    # Fall back to paired if single not present
    if [[ -s "$paired" ]]; then
      OPTS="$OPTS,FA=$paired"
    else
      echo "[WARN] No input FASTA for $b (missing $single and $paired). Skipping." >&2
      continue
    fi
  fi

  # Submit job: partition + qos (adjust --account to your cluster if required)
  sbatch \
    --export="$OPTS" \
    -J "idba-$b" \
    --account="$QUEUE" \
    --partition="$QOS" \
    --error "$dir/zz.out/idba-$b-%j.err" \
    --output "$dir/zz.out/idba-$b-%j.out" \
    "$cwd/run.pbs" | grep .
done

echo "Done: $(date)."
