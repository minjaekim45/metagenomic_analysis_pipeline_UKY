#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=4
#SBATCH --mem=16g
#SBATCH -t 12:00:00

source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh
conda activate qiime2

echo "extract reference read"

qiime tools import \
  --type 'FeatureData[Sequence]' \
  --input-path /project/mki314_uksr/SILVA_138.1_SSURef_NR99_tax_silva_trunc.fasta \
  --output-path silva-138-ssuref-nr99-seqs.qza

# silva-138-ssuref-nr99-seqs-clean.qza → cleaned reference sequences
# silva-138-ssuref-nr99-taxonomy.qza → FeatureData[Taxonomy]
qiime rescript parse-silva-taxonomy \
  --i-sequences silva-138-ssuref-nr99-seqs.qza \
  --o-taxonomy silva-138-ssuref-nr99-taxonomy.qza \
  --o-sequences silva-138-ssuref-nr99-seqs-clean.qza

qiime rescript filter-seqs-length-by-taxon \
  --i-sequences silva-138-ssuref-nr99-seqs-clean.qza \
  --i-taxonomy silva-138-ssuref-nr99-taxonomy.qza \
  --p-labels Bacteria Archaea \
  --p-min-len 900 \
  --o-filtered-seqs silva-138-ssuref-nr99-16S-seqs.qza \
  --o-discarded-seqs silva-138-ssuref-nr99-discarded.qza

echo "complete extract reference read"
qiime rescript dereplicate \
  --i-sequences silva-138-ssuref-nr99-16S-seqs.qza \
  --i-taxa silva-138-ssuref-nr99-taxonomy.qza \
  --p-mode 'uniq' \
  --o-dereplicated-sequences silva-138-ssuref-nr99-16S-seqs-derep.qza \
  --o-dereplicated-taxa silva-138-ssuref-nr99-16S-tax-derep.qza

echo "complete dereplicate & start classifier training"

qiime feature-classifier fit-classifier-naive-bayes \
  --i-reference-reads silva-138-ssuref-nr99-16S-seqs-derep.qza \
  --i-reference-taxonomy silva-138-ssuref-nr99-16S-tax-derep.qza \
  --o-classifier silva-138-ssuref-nr99-16S-full-classifier.qza

echo "complete classifier training"