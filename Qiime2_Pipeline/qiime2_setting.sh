#!/bin/bash
source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh

wget https://raw.githubusercontent.com/qiime2/environment-files/master/latest/staging/qiime2-latest-py38-linux-conda.yml
conda env create -n qiime2 --file qiime2-latest-py38-linux-conda.yml
rm qiime2-latest-py38-linux-conda.yml

conda activate qiime2

wget -P /scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/databases/qiime2db https://data.qiime2.org/2024.2/common/silva-138-99-nb-classifier.qza