#!/bin/bash
#SBATCH --job-name=qiime2
#SBATCH --nodes=1
#SBATCH --ntasks=8
#SBATCH --time=12:00:00
#SBATCH --mem=16G
#SBATCH --output=qiime2.%j.out
#SBATCH --error=qiime2.%j.err
if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: ./05.sortmerna.bash [folder] [queue] [QOS]

   folder      Path to FASTQ/fastq_files 
   queue       Select a partition (if not provided, coa_mki314_uksr will be used)
   QOS         Select a quality of service (if not provided, normal will be used)

   " >&2 ;
   exit 1 ;
fi ;

mkdir -v ../result

echo $PWD 
#VARIABLES
NGS_PATH=../../fastq/$DOMAIN
OUTPUT=demux_seqs.qza

DADA_OUT=dada2_table.qza
DADA_REPSEQ=dada2_rep_seqs.qza
DADA_STATS=dada2_stats.qza

#NEED METADATA.TSV
METADATA_ARC=../../fastq/sample-metadata-arc.tsv
METADATA_BAC=../../fastq/sample-metadata-bac.tsv

#IMPORT DATA
qiime tools import \
  --type 'SampleData[PairedEndSequencesWithQuality]' \
  --input-path $NGS_PATH \
  --input-format CasavaOneEightSingleLanePerSampleDirFmt \
  --output-path $OUTPUT

#Data Visualization
qiime demux summarize\
	--i-data $OUTPUT\
	--o-visualization $VISUAL_TRIM

##http://view.qiime2.org --> to visualize $VISUAL

#Denoising with DADA2
qiime dada2 denoise-paired \
	--i-demultiplexed-seqs $OUTPUT_TRIM \
	--p-trunc-len-f 0 \
	--p-trunc-len-r 0 \
	--p-max-ee-f 2 \
	--p-max-ee-r 2 \
	--p-trunc-q 5 \
	--p-chimera-method none \
	--p-n-threads 0 \
	--o-table $DADA_OUT \
	--o-representative-sequences $DADA_REPSEQ \
	--o-denoising-stats $DADA_STATS

qiime feature-table summarize \
  --i-table $DADA_OUT \
  --o-visualization dada2_table.qzv \
  --m-sample-metadata-file $METADATA

qiime feature-table tabulate-seqs \
  --i-data $DADA_REPSEQ \
  --o-visualization dada2_rep_seqs.qzv

qiime metadata tabulate \
  --m-input-file $DADA_STATS \
  --o-visualization dada2_stats.qzv

