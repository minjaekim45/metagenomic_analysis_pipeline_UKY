Step 0 – (Optional) Download eggNOG Database (Parallel)

Script: download_eggnog_parallel.sh
This script downloads eggNOG database files in parallel (faster than serial download).

Usage
bash download_eggnog_parallel.sh

Output
| eggNOG database directory (your environment-specific location)|

If your EGGNOG_DB_DIR is already populated, you can skip this step.
----------------------------------------------------------------------------------------------------------------------------------------------
Step 1 – Run eggNOG-mapper for all MAGs (Slurm Array)
Scripts:
run_eggnog_array.sh (group-wise array runner) 
run_eggnog_single.sh (single MAG runner; called by the array script) 

This step runs eggNOG-mapper using Bakta proteins (.faa) as input. 

Usage
sbatch ./run_eggnog_array.sh

Inputs
Input	Description
IR37_group_list.txt	One group prefix per line; array task picks one group and runs all MAGs in that group. 
11.bakta/results/<MAG>/<MAG>.faa	Bakta protein FASTA per MAG. 

Output
File / Directory	Description
34.eggnog/<MAG>/<MAG>.eggnog.emapper.annotations	eggNOG annotation table for each MAG (main downstream input). 
----------------------------------------------------------------------------------------------------------------------------------------------
Step 2 – Define Targets (Modules / Pathways / KO sets) via a Config File
File: configs/targets_map.tsv

This pipeline avoids hard-coding pathway/module IDs inside scripts. Instead, you define targets in a tab-separated config file.

Target Config Format
module.tsv must contain:

Column	Meaning
id	Target identifier (e.g., M00567, map00680, KO:K00399 if you implement KO filtering)
subdir	Output folder name under 34.eggnog/ where filtered TSVs will be written
label (optional)	Human-friendly name for plotting/reporting

Example:

#id	subdir	label
M00567	Hydrogenotrophic	CO2_to_CH4
M00357	Acetoclastic	Acetate_to_CH4
M00356	Methanol	Methanol_to_CH4
M00563	Methylamine	Methylamines_to_CH4
M00422	AcetylCoA	AcetylCoA_pathway

Notes
If you want to analyze different pathways, you only edit module.tsv (not the scripts).
The filtering step must write files in this naming pattern: <MAG>_<id>.tsv.
----------------------------------------------------------------------------------------------------------------------------------------------
Step 3 – Filter eggNOG Annotations by Targets (Config-driven)

Scripts (generalized targets version):
run_filter_targets.sh (recommended)
filter_by_target.py

This step filters each MAG’s eggNOG annotations (*.emapper.annotations) to generate target-specific TSV files under subdirectories listed in targets_map.tsv.
What it produces
For each target (e.g., M00567) and each MAG:

Output file: 34.eggnog/<subdir>/<MAG>_<id>.tsv

This is conceptually the same as the older module-only filtering (02.run_filter_module.sh, 02.filter_by_module.py) but without a hard-coded module list.

Usage
bash run_filter_targets.sh \
  /scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/34.eggnog \
  /scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/module.tsv

Arguments
Argument	Description
base_dir	Root directory containing per-MAG eggNOG outputs (34.eggnog/<MAG>/...annotations)
targets_map.tsv	Target list config (Step 2)
Output
Location	Description
34.eggnog/<subdir>/<MAG>_<id>.tsv	Filtered gene list for that target in that MAG
----------------------------------------------------------------------------------------------------------------------------------------------
Step 4 – Summarize Target Hits per MAG (Long + Wide Tables)

Scripts (generalized targets version):

run_summarize_targets_per_MAG.sh
summarize_targets_per_MAG.py
This step scans each <subdir> and counts the number of hits per MAG per target by counting rows in each <MAG>_<id>.tsv.

Usage
bash run_summarize_targets_per_MAG.sh \
  /scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/34.eggnog \
  /scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/configs/targets_map.tsv \
  /scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/34.eggnog/IR37_targets \
  16

Arguments
Argument	Description
base_dir	34.eggnog root
targets_map.tsv	Target list config
out_prefix	Prefix for output tables (e.g., .../IR37_targets)
jobs	Threads for fast counting (I/O parallelism)
Output
File	Description
<out_prefix>_long.tsv	MAG, TargetID, n_hits (long format)
<out_prefix>_wide.tsv	MAG × TargetID matrix (wide format)
----------------------------------------------------------------------------------------------------------------------------------------------
step 5. Attach gene TPM/RPKM to module-filtered eggNOG TSVs (Slurm Array)
Scripts:

04.attach_TPM_to_module_hits.bash (Slurm array runner; module.tsv 기반으로 모듈별 병렬 실행)
04.attach_tpm_rpkm_to_module_hits.py (실제 join 수행: eggNOG module TSV + gene TPM/RPKM)

Purpose
이 step은 이미 만들어진 module-filtered eggNOG 결과물(예:
34.eggnog/Acetoclastic/IR37_0d.13_M00357.tsv)에 대해서,
해당 gene에 대응하는 TPM/RPKM 값을 붙여서 “pathway gene list + abundance” 테이블을 만든다.

핵심은 다음 2개를 **(MAG, Geneid)**로 merge하는 것:
module TSV (gene id는 보통 query 컬럼)
샘플별 gene TPM/RPKM 테이블 (35.featureCounts/normalized/<sample>.allMAG.gene_TPM_RPKM.tsv.gz)

Usage
(A) module.tsv 전체를 병렬(array)로 실행 (권장)
    module.tsv의 유효 라인 수(N) 확인:
    awk -F'\t' '$0 !~ /^#/ && NF>0{c++} END{print c}' /scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/module.tsv
    그 후 array 제출: sbatch --array=1-N /scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/Functional_annotation_Pipeline/04.attach_TPM_to_module_hits.bash --use_array

(B) 특정 module 폴더만 단일 실행
    example: Acetoclastic만 실행
    sbatch /scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/Functional_annotation_Pipeline/04.attach_TPM_to_module_hits.bash --module Acetoclastic