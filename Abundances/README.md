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
This step normalizes genome coverage by MicrobeCensus-estimated genome equivalents to estimate relative abundance.  
Inputs:  
•	29.TAD80/TAD80/*.tad80.tsv  
•	MicrobeCensus output files in 14.microbe_census/
Outputs:
•	MicrobeCensus_genome_equivalents.txt (auto-generated)
•	Individual normalized abundance files (*.abundance.txt)
•	Final combined abundance matrix: 04.abundance.tsv
Step 5 – Consolidate Genome Abundance into ANI Species Abundance
Script: 05.make_ANIspp_abundance.bash
This step groups genomes belonging to the same dRep secondary cluster and calculates abundance at the ANI species (ANIsp) level by summing the normalized abundances of all genomes within each cluster.
Inputs
•	18.dRep/output/dereplicate/data_tables/Cdb.csv
•	29.TAD80/abundance/04.abundance.tsv
Outputs
•	29.TAD80/consolidate/dRep_clusters.csv
•	29.TAD80/consolidate/04.abundance.tsv
•	29.TAD80/consolidate/ANIspp.abundance.tsv
Step 6 – Add Representative Genome and GTDB Taxonomy
Script: 06.add_representative_gtdb.bash
This step annotates each ANI species with its representative genome selected by dRep and its GTDB-Tk taxonomic classification.
Inputs
•	29.TAD80/consolidate/dRep_clusters.csv
•	29.TAD80/consolidate/ANIspp.abundance.tsv
•	18.dRep/output/dereplicate/data_tables/Wdb.csv
•	17.gtdbtk/gtdbtk.bac120.summary.tsv
Outputs
•	29.TAD80/consolidate/representative_cluster_map.tsv
•	29.TAD80/consolidate/representative_genomes.txt
•	29.TAD80/consolidate/representative_gtdb_classification.tsv
•	29.TAD80/consolidate/representative_by_ANIspp_row.tsv
•	29.TAD80/consolidate/ANIspp.abundance.with_representative.tsv

