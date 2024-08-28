@author: Minjae Kim (minjae.kim at uky dot edu)

@update: Aug-27-2024

# IMPORTANT

This pipeline was benchmarked from enveomic pipelines and adjusted for the HPC at University of Kentucky

# PURPOSE

Performs various trimming, quality-control analyses, and human reads filtering over raw reads.

# HELP

1. Files preparation:

   1.1. Using the conda environment on the Morgan Compute Cluster. For the setup please see this link 
   		(https://curc.readthedocs.io/en/latest/software/python.html?highlight=anaconda)
   		After setup of the conda environment, conda create/install idba-ud assembler with the environment name "trim-galore"
   
   1.2. Change the enveomics path (line #7) of the directory in run.pbs 
   
   1.3. Prepare the raw reads in FastQ format. Files must be raw, not zipped or packaged.
      Filenames must conform the format: <name>.<sis>.fastq, where <name> is the name
      of the sample, and <sis> is 1 or 2 indicating which sister read the file contains.
      Use only '1' as <sis> if you have single reads.
   
   1.4. Gather all the FastQ files into the same folder.

2. Pipeline execution:
   
   2.1. Simply execute `./RUNME.bash <dir>`, where `<dir>` is the folder containing
      the FastQ files.

3. What to expect:

   By the end of the run, you should find the following folders:
   
   3.1. *01.raw_reads*: raw FastQ files.
   
   3.2. *02.trimmed_reads*: Trimmed/tagged fastq reads and fastqc result

   3.3. *03.read_quality*: Should be empty. 

   3.4. *04.trimmed_fasta*: Trimmed reads in FastA format (both interposed and uninterposed files) 

