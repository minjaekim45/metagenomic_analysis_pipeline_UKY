@author: Minjae Kim (minjaekim45 at gmail dot com)

@update: AUG-31-2022
IMPORTANT

There are many options for each task (e.g., mash, nonpareil, etc.). Try to see the references and help message for each tool before running this pipeline to make sure you are running all tools properly.
PURPOSE

Performs nonpareil and mash distance calculation for estimating alpha- and beta-diversity.
HELP

    Files preparation:

    1.1. Using the conda environment on Summit. For the setup please see this link (https://curc.readthedocs.io/en/latest/software/python.html?highlight=anaconda) After setup the conda environment, conda create/install nonpareil with the environment name "nonpareil"

    1.1. change the paths of the directory for enveomics and mash in run.pbs

    1.2. Prepare the trimmed reads (e.g., use Trim_Pipeline) in both interposed and uninterposed FastA format. Files must be raw, not zipped or packaged. Filenames must conform the format: .CoupledReads.fa or .SingledReads.fa, where is the name of the sample. For the uninterposed reads, _1.fa Locate all the files within a folder named 04.trimmed_fasta, within your project folder. If you used Trim_Pipeline, no further action is necessary.

    Pipeline execution:

    2.1. Simply execute ./RUNME.bash <dir>, where
    is the folder containing the 04.trimmed_fasta folder.

    What to expect:

    By the end of the run, you should find the following folders:

    3.1. *06.nonpareil: you will have three files .npa .npc .npl .npo for each sample.

    3.2. *07.mash: you will have .msh for each sample

    What to do next:

    After all of your runs are done, you need to run mash.pbs (Before running it you need to change the directory with yours on line 8 and 9.

    Final distance matrix will be in Mash_dist.txt
