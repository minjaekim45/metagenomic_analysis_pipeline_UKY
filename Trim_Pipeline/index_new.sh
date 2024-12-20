#!/bin/bash

#SBATCH --time=12:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=index_new            # Job name
#SBATCH --ntasks=1                 # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --mem=32g
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e index-%j.err             # Error file for this job.
#SBATCH -o index-%j.out             # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)

dir=/scratch/rcsa230/genomes/contam
kraken2=/scratch/rcsa230/Illumina_YESTF927/06.kraken/FSI927_k2_report.txt
min=0.001 #min percent

source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh
# conda activate ncbi_datasets

cd $dir

# # Process kraken2 entries where classification is S, S1, or S2 and percent coverage is > min
# while IFS=$'\t' read -r col1 col2 col3 col4 col5 col6; do
#     if [[ ($col4 == "S" || $col4 == "S1" || $col4 == "S2") && $(echo "$col1 > 0" | bc) -eq 1 ]]; then
#         search_term=$(echo "$col6" | xargs)
#         dataset_zip="${search_term}_refseq_dataset.zip"
#         dataset_dir="${search_term}_refseq_dataset"
        
#         # Check if the dataset directory already exists
#         if [[ -d "$dataset_dir" ]]; then
#             echo "Dataset directory for $search_term already exists."
#         else
#             # Check if the dataset is already downloaded
#             if [[ -f "$dataset_zip" ]]; then
#                 echo "Unzipping dataset for $search_term"
#                 unzip "$dataset_zip" -d "$dataset_dir"
#             else
#                 echo "Searching and downloading reference genome for: $search_term"
#                 datasets download genome taxon "$search_term" --reference --filename "$dataset_zip"
#                 unzip "$dataset_zip" -d "$dataset_dir"
#             fi
#         fi
        
#         # Move .fna files and clean up
#         echo "Looking for .fna files in $dataset_dir/ncbi_dataset/data/"
#         for accession_dir in "$dataset_dir/ncbi_dataset/data/"*; do
#             if [[ -d "$accession_dir" ]]; then
#                 echo "Checking directory $accession_dir"
#                 for fna_file in "$accession_dir"/*.fna; do
#                     echo "Checking file $fna_file"
#                     if [[ -f "$fna_file" ]]; then
#                         mv "$fna_file" "$dir"
#                         echo "Moved $fna_file to $dir"
#                     else
#                         echo "No .fna file found in $accession_dir"
#                     fi
#                 done
#             fi
#         done
        
#         # Remove the dataset directory and zip file
#         rm -rf "$dataset_dir"
#         rm -f "$dataset_zip"
#         echo "Deleted $dataset_dir and $dataset_zip"
#     fi
# done < "$kraken2"

# Deactivate the Conda environment
# conda deactivate

#---------------------------------------------------------

# Iterate over each .fna file in $dir to output_file and store concatenated genome names in concatenated_genomes
# cat *.fna > cat_genomes.fa
# echo "Concatenated genomes"

#---------------------------------------------------------
# Index the combined contaminating organisms reference genome file
conda activate hocort
#For Illumina short reads
#hocort index bowtie2 --input ./cat_genomes.fa --output ./cat_genomes ;
#For nanopore long reads Kraken2Minimap2 
hocort index kraken2 --input ./cat_genomes.fa --output ./cat_genomes_kraken2_db --threads 1 
#hocort index minimap2 --input ./cat_genomes.fa --output ./cat_genomes_minimap2.mmi
conda deactivate