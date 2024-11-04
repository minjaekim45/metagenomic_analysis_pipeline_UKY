# metagenomic_analysis_pipeline_UKY

      1 - Raw sequencing data processed by Trim Galore to control quality.
      2 - Raw sequencing data processed by Nonpareil to calculate abundance-weighted average coverage and alpha diversity.
      3 - Taxonomic annotation performed using short reads with Kraken2 and Kaiju.
      4 - Whole-community pairwise distances (β-diversity) computed using MASH.
      5 - Metagenome assembled genomes (MAGs) will be assembled.
      6 - The Genome Taxonomy Database and associated taxonomic classification toolkit (GTDBtk) will determine the most plausible taxonomic classification and novelty rank of MAG sets.
      7 - Conduct a comparative analysis using a variety of publicly available hospital environment metagenomic datasets.
      8 - Pathway analysis and statistical tests will identify differentially abundant microbial pathways using HUMAnN3.
      9 - Mobile elements in contigs will be identified by BacAnt.
