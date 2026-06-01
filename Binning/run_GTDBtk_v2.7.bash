#!/bin/bash

#SBATCH --time=1-00:00:00
#SBATCH --job-name=gtdbtk
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=180G
#SBATCH --partition=normal
#SBATCH -e /zz.out/GTDBtk-%j.err
#SBATCH -o /zz.out/GTDBtk-%j.out
#SBATCH --account=coa_mki314_uksr

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: sbatch ./run_GTDBtk_v2.7.bash [folder]

   folder      Path to the folder containing 16.checkm2
   " >&2
   exit 1
fi

dir=$(readlink -f $1)
cd $dir

if [[ ! -e 16.checkm2 ]] ; then
   echo "Cannot locate the 16.checkm2 directory, aborting..." >&2
   exit 1
fi

mkdir -p 17.gtdbtk
mkdir -p zz.out

#---------------------------------------------------------
# GTDB-Tk v2.7.0 paths from MCC IT

IMAGE=/share/singularity/images/ccs/GTDB-Tk/2.7.0/mcc-gtdbtk-2.7.0-rocky9.sinf
REFDATA=/share/singularity/data/gtdbtk/release232

GENOME_DIR=$dir/16.checkm2/output/good_quality
OUT_DIR=$dir/17.gtdbtk
EXT=fa

# Keep user's local Python packages out of the container
export SINGULARITYENV_PYTHONNOUSERSITE=1

# Temporary directory
TMPDIR_RUN=$dir/17.gtdbtk/tmp_${SLURM_JOB_ID}
mkdir -p ${TMPDIR_RUN}

#---------------------------------------------------------
# Run GTDB-Tk

echo "==[ GTDB-Tk started: $(date) ]"
echo "Genome directory: ${GENOME_DIR}"
echo "Output directory: ${OUT_DIR}"
echo "Extension: ${EXT}"

singularity exec \
    --bind ${REFDATA}:/refdata \
    ${IMAGE} \
    gtdbtk classify_wf \
        --genome_dir ${GENOME_DIR} \
        --out_dir ${OUT_DIR} \
        --extension ${EXT} \
        --cpus ${SLURM_CPUS_PER_TASK} \
        --tmpdir ${TMPDIR_RUN}

rm -rf ${TMPDIR_RUN}


echo "Done: $(date)."
        
