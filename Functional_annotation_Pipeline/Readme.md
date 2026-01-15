# Functional Annotation Pipeline (eggNOG + KEGG Modules)

This folder provides scripts for annotating MAG proteins with eggNOG-mapper,
extracting KEGG module hits (methanogenesis-focused), and summarizing module
presence with optional abundance integration.

The workflow is organized into the steps below and follows the same structure as
other pipeline READMEs in this repository.

----

## Step 1 – Download eggNOG database

Script: `download_eggnog_parallel.sh`

This script downloads and unpacks the eggNOG database into:
`/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/databases/eggnog_db`.

### Usage
```bash
bash download_eggnog_parallel.sh
```

### Output
The database directory should contain:
- `eggnog.db`
- `eggnog.taxa/`
- `eggnog_proteins.dmnd`

----

## Step 2 – Generate MAG lists (optional helpers)

Scripts:
- `make_IR37_mag_list.sh`
- `make_IR37_group_list.sh`

These scripts create MAG lists based on Bakta results in:
`/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/11.bakta/results`.

### Usage
```bash
bash make_IR37_mag_list.sh
bash make_IR37_group_list.sh
```

### Inputs
- Bakta results: `11.bakta/results/`

### Output
| File | Description |
| ---- | ----------- |
| `IR37_mag_list.txt` | Full MAG IDs (e.g., `IR37_0d.2`) |
| `IR37_group_list.txt` | Group prefixes (e.g., `IR37_0d`) |

----

## Step 3 – Run eggNOG-mapper

Scripts:
- `run_eggnog_single.sh`
- `run_eggnog_array.sh`

This step uses Bakta protein FASTA files (`*.faa`) and writes outputs under:
`/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/34.eggnog`.

### Usage
Single MAG:
```bash
bash run_eggnog_single.sh IR37_18-5d.120
```

SLURM array:
```bash
sbatch run_eggnog_array.sh
```

### Inputs
- Bakta protein FASTA files: `11.bakta/results/*/*.faa`

### Output
Each MAG directory under `34.eggnog/` contains:
- `<MAG>.eggnog.emapper.annotations`
- `<MAG>.eggnog.*` (other eggNOG outputs)

----

## Step 4 – Filter KEGG modules

Scripts:
- `run_filter_module.sh`
- `filter_by_module.py`

This step filters eggNOG annotations for KEGG modules (methanogenesis-related)
and writes module-specific TSVs into module subdirectories (e.g.,
`Hydrogenotrophic/`, `Acetoclastic/`).

### Usage
```bash
bash run_filter_module.sh
```

### Inputs
- eggNOG annotations: `34.eggnog/<MAG>/<MAG>.eggnog.emapper.annotations`

### Output
Module TSVs are written to subdirectories (e.g., `Hydrogenotrophic/`) under the
current working folder.

| Directory | Example file |
| --------- | ------------ |
| `Hydrogenotrophic/` | `IR37_0d.6_M00567.tsv` |
| `Acetoclastic/` | `IR37_0d.6_M00357.tsv` |
| `Methanol/` | `IR37_0d.6_M00356.tsv` |
| `Methylamine/` | `IR37_0d.6_M00563.tsv` |
| `AcetylCoA/` | `IR37_0d.6_M00422.tsv` |

----

## Step 5 – Summarize modules per MAG

Scripts:
- `run_summarize_modules_per_MAG.sh`
- `summarize_modules_per_MAG.py`

### Usage
```bash
bash run_summarize_modules_per_MAG.sh
```

### Inputs
- Module TSVs generated in Step 4

### Output
| File | Description |
| ---- | ----------- |
| `IR37_modules_long.tsv` | Long table (MAG, Module, n_genes) |
| `IR37_modules_wide.tsv` | Wide table (MAG × Module gene counts) |

----

## Step 6 – Summarize modules with abundance

Scripts:
- `build_module_abundance_summary.sh`
- `summarize_modules_with_abundance.py`

This step merges module presence with the abundance matrix from TAD80:
`/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/29.TAD80/TAD80/abundance/04.abundance.tsv`.

### Usage
```bash
bash build_module_abundance_summary.sh
```

### Inputs
- Module summary from Step 5 (`IR37_modules_long.tsv`)
- TAD80 abundance matrix (`29.TAD80/TAD80/abundance/04.abundance.tsv`)

### Output
| File | Description |
| ---- | ----------- |
| `IR37_modules_MAG_summary.tsv` | MAG, Module, n_genes + abundance columns |
| `IR37_modules_sample_potential.tsv` | Module potential per sample |

----

## Step 7 – Extract methane pathway (map00680)

Script: `extract_map00680_all.sh`

This step extracts rows annotated with `map00680` (methane metabolism) from each
MAG’s eggNOG annotation file.

### Usage
```bash
bash extract_map00680_all.sh
```

### Inputs
- eggNOG annotations: `34.eggnog/<MAG>/<MAG>.eggnog.emapper.annotations`

### Output
| File | Description |
| ---- | ----------- |
| `<MAG>_map00680.tsv` | Annotation rows containing `map00680` |
