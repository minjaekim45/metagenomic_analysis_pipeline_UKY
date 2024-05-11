@author: Minjae Kim (minjaekim45 at gmail dot com)

@update: Aug-31-2019
PURPOSE

This pipeline was designed to run metabat2 on SUMMIT HPC
HELP

    Prerequisites:

    1.1. Using the conda environment on Summit. For the setup please see this link (https://curc.readthedocs.io/en/latest/software/python.html?highlight=anaconda) After setup the conda environment, conda create/install metabat2 with the environment name "metabat2" Change the paths in the run.pbs file with yours

    1.2. Need to run Trimming Pipeline & Assembly Pipeline

    Pipeline execution:

    2.1. Simply execute ./RUNME.bash <dir>, where <dir> is the folder containing the 04.trimmed_fasta folder (see help message running ./RUNME.bash without arguments).

    What to expect:

    By the end of the run, you should find the folder 15.metabat2, including the following files for each dataset:

    3.1. <dataset>: The metabat2 output folder.

    3.2. <dataset> for bowtie2 files
