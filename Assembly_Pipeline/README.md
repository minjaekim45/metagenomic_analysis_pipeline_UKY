@author: Minjae Kim (minjae.kim at uky dot edu)

@update: Aug-27-2024

# IMPORTANT

This pipeline was benchmarked from enveomic pipelines and adjusted for the HPC at University of Kentucky

# PURPOSE

Performs assembly using IDBA-UD, designed for Single-Cell Genomics and Metagenomics.

# HELP

    Prerequisites:

    1.1. Using the conda environment on the Morgan Computer Cluster. For the setup please see this link (https://curc.readthedocs.io/en/latest/software/python.html?highlight=anaconda) After setup of the conda environment, conda create/install idba-ud assembler with the environment name "idba".

    1.2. Prepare the trimmed reads (e.g., use Trim_Pipeline) in interposed FastA format. Files must be raw, not zipped or packaged. Filenames must conform the format: X.CoupledReads.fa or X.SingledReads.fa, where X is the name of the sample. Locate all the files within a folder named 04.trimmed_fasta, within your project folder. If you used trim.pbs, no further action is necessary.

    Pipeline execution:

    2.1. Simply execute ./RUNME.bash <dir> <data_type>, where <dir> is the folder containing the 04.trimmed_fasta folder, and <data_type> is a supported type of data (see help message by running ./RUNME.bash without arguments).

    What to expect:

    By the end of the run, you should find the folder 05.assembly, including the following files for each dataset:

    3.1. <dataset>: The IDBA output folder.

    3.2. <dataset>.AllContigs.fna: All contigs longer than 200bp in FastA format.

    3.3. <dataset>.LargeContigs.fna: Contigs longer than 1000bp in FastA format.
