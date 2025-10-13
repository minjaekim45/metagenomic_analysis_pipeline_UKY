This repository provides a set of scripts to perform metagenomic read mapping, genome coverage profiling (TAD80), and abundance normalization across metagenome-assembled genomes (MAGs).
Pipeline Steps
Step 1 – Build Read Index
Script: 01.index.pbs
It creates Bowtie2 index files for the merged MAG FASTA in 28.index/.
Input: 28.index/01.hq-set.fa
Output: Bowtie2 index files (*.bt2) in the same directory.
Step 2 – Map Reads
Scripts: 02.map.bash + 02.map.pbs
This step maps paired-end reads from 04.trimmed_fasta to the indexed MAGs.
Step 3 – Calculate TAD80 Coverage
Scripts: 03.tad.bash + 03.tad.pbs
This step computes coverage depth across MAGs and generates .tad80.tsv files.
Inputs: 
•	BAM files from Step 2 (29.TAD80/map/*.bam)
•	MAG FASTA (28.index/01.hq-set.fa)
Outputs:
•	03.tad.list (MAG IDs)
•	03.tad.pbs.jobids (job tracking file)
•	.tad80.tsv files per sample in 29.TAD80/TAD80/
Each .tad80.tsv contains normalized coverage statistics per MAG.
Step 4 – Compute Normalized Abundance
Script: 04.abundance.bash
This final step normalizes genome coverage by MicrobeCensus-estimated genome equivalents to estimate relative abundance.
Inputs:
•	29.TAD80/TAD80/*.tad80.tsv
•	MicrobeCensus output files in 14.microbe_census/
Outputs:
•	MicrobeCensus_genome_equivalents.txt (auto-generated)
•	Individual normalized abundance files (*.abundance.txt)
•	Final combined abundance matrix: 04.abundance.tsv

