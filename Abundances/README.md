# Metagenomic Read Mapping, Coverage (TAD80), and Abundance Profiling Pipeline

This repository provides a set of scripts for performing read mapping, genome coverage profiling (TAD80), rRNA filtering, dereplication clustering, and abundance normalization across metagenome-assembled genomes (MAGs).

The workflow is designed for assembly-based metagenomic analysis and follows the steps below.

----

## Step 1 - Build MAG index
Script: ```01.index.pbs```
This script gathers all high-quality MAGs, merges them into a single FASTA with unique sequence headers, and generates a Bowtie2 index for downstream read mapping.

### Usage:
```bash
sbatch ./01.index.bash [folder]
```

### Argument
| Argument | Description                                                               |
| -------- | ------------------------------------------------------------------------- |
| `folder` | Path to the project root containing `16.checkm2/output/good_quality/*.fa` |

It then:
- Extracts the basename of each MAG (e.g., IR37_0d.2)
- Adds the basename as a prefix to each FASTA header → makes all contig IDs unique
- Writes the combined file to: `28.index/01.hq-set.fa`

Example header transformation:
```shell
contig-100_702
```
becomes
```shell
IR37_0d.2:contig-100_702
```
### Output
| File / Directory           | Description                                     |
| -------------------------- | ----------------------------------------------- |
| `28.index/01.hq-set.fa`    | Merged MAG FASTA with uniquely prefixed headers |
| `28.index/01.hq-set.*.bt2` | Bowtie2 index files generated from merged MAGs  |


----

## Step 2 – Map Reads to MAGs

Scripts: `02.map.bash`

This step submits Bowtie2 mapping jobs for all trimmed paired-end FASTA reads located in `04.trimmed_fasta/`.
Each sample must have two files ending in `_1.fa` and `_2.fa`.

### Usage 
```bash
./02.map.bash [folder] [queue] [QOS]
```
- `folder`[required]: Path to directory containing `04.trimmed_fasta/`

### Output
Bowtie2 mapping output (from `02.map.pbs`) will include:
| File                         | Description                                  | Location        |
| ---------------------------- | -------------------------------------------- | --------------- |
| `<sample>.bam`               | Sorted BAM file of reads mapped to MAG index | `29.TAD80/map/` |
| `<sample>.log`               | Bowtie2 alignment statistics                 | `29.TAD80/map/` |
| `BMAPA_<sample>-<jobID>.out` | SLURM stdout                                 | `zz.TMP/`       |
| `BMAPA_<sample>-<jobID>.err` | SLURM stderr                                 | `zz.TMP/`       |


----

## Step 3 – Calculate TAD80 Coverage

Scripts: `03.tad.bash`
This step uses the mapped BAM files from Step 2 and the MAG index from Step 1 to:
- Summarize Bowtie2 mapping statistics
- Generate a list of MAG IDs
- Submit per-sample jobs to compute coverage and TAD80 statistics for each MAG

### Inputs

- BAM files from Step 2 (`29.TAD80/map/*.bam`)
- MAG FASTA (`28.index/01.hq-set.fa`)

### Outputs

All outputs are stored under `29.TAD80/TAD80/`.

1. `02.map.tsv`
    - One row per sample
    - Contains simplified mapping summary parsed from Bowtie2 logs (`map/*.log`)
2. `03.tad.list`
    - One MAG ID per line (e.g., `IR37_0d.2`, `IR37_0d.5`, …)
    - Used as the MAG list for coverage/TAD80 calculations
3. `03.tad.pbs.jobids` 
    - Job tracking file
4. `*.tad80.tsv`
    - Per-sample TAD80 results
    - each file contains normalized coverage statistics per MAG
5. `*.bg.gz`
    - Coverage bedGraph
6. `*.sorted.bam`
    - Coordinate-sorted BAM

----

## Step 4 – Compute Normalized Abundance

Script: `04.abundance.bash`

This step converts the raw TAD80 coverage values (from Step 3) into normalized microbial abundance estimates by dividing each MAG’s TAD80 value by the sample’s MicrobeCensus genome equivalents.
The result is a sample-by-MAG abundance matrix (`04.abundance.tsv`).

### Workflow
1. Parse all MicrobeCensus outputs (`*.microbecensus.out`)
    - it generates: `14.microbe_census/MicrobeCensus_genome_equivalents.txt`
2. Extract genome_equivalents per sample
3. For each `<sample>.tad80.tsv`, normalize each MAG’s TAD80
    - ```normalized_abundance = TAD80_value / genome_equivalents```
4. Create individual normalized abundance files (`TAD80/abundance/<sample>.abundance.txt`)
    - One normalized value per line, corresponding to the MAG order in `03.tad.list`
5. Combine all results into a single multi-sample matrix (`04.abundance.tsv`)
    - Structure:

    | Bin (MAG ID) | sample1 | sample2 | sample3 | … |
    | ------------ | ------- | ------- | ------- | - |
    | MAG001       | 0.0019  | 0.0021  | 0.0013  | … |
    | MAG002       | 0.0003  | 0.0002  | 0.0001  | … |
    | MAG003       | 0.0152  | 0.0148  | 0.0164  | … |

----

## Step 5 – MAG Dereplication & Clustering

Script: `make_drep_clusters.sh`

This script extracts genome clusters from dRep’s Cdb.csv file and generates a clean dRep_clusters.csv file, where each line contains the MAG IDs belonging to one cluster.
The script automatically searches for Cdb.csv inside the standard dRep output paths.

### Usage
```bash
./make_drep_clusters.sh [folder] [cluster_level] [keep_ext]
```

### Arguments
| Argument        | Description                                                               | Default                   |
| --------------- | ------------------------------------------------------------------------- | ------------------------- |
| `folder`        | Project root folder (must contain `18.dRep/output/...`)                   | **Required**              |
| `cluster_level` | Clustering level: `secondary` (species), `primary` (strain), or `cluster` | `secondary`               |
| `keep_ext`      | Keep FASTA extensions (`.fa`, `.fna`, `.fasta`, `.gz`) in MAG IDs         | `no` (extensions removed) |

### Cluster Level Options
- `secondary` / `sec` / `species` → uses secondary_cluster column
- `primary` / `pri` / `strain` → uses primary_cluster column
- `cluster` → uses `cluster` column

### Input
The script searches for `Cdb.csv` in `18.dRep/output/dereplicate/data_tables/`

### Output
A CSV file without a header, one line per cluster:
```bash
[folder]/dRep_clusters.csv
```
Each line contains MAG IDs separated by commas (`MAG1`,`MAG4`,`MAG8`).
Extensions are removed unless `keep_ext=yes`.

Output Format Example `dRep_clusters.csv`:
```
MAG001,MAG014,MAG022
MAG003
MAG007,MAG010
```
----
## Step 6 – Consolidate Cluster-Level Abundance (ANI-spp)

Script: `consolidate-spp.rb`

This step merges MAG-level abundance (from Step 4) into cluster-level abundance based on dRep ANI clusters.

### Inputs

- `04.abundance.tsv`: Output table from `04.abundance.bash`
- `dRep_clusters.csv`: Output file from `make_drep_clusters.bash`

### Output
- `ANIspp.abundance.tsv`: Abundance table aggregated by dRep clusters (ANI species-level groups)

----
## Step 7 - Separate rRNA (SortMeRNA) (Optional)

Script: `05.sortmerna.bash`

This step submits SortMeRNA jobs for all trimmed FASTA read pairs in `04.trimmed_fasta/`.
It generates rRNA-filtered metagenomic reads for downstream analysis.

### Usage
```bash
./05.sortmerna.bash [folder] [queue] [QOS]
```

### Arguments
| Argument | Description                                              | Default           |
| -------- | -------------------------------------------------------- | ----------------- |
| `folder` | Path to project folder that contains `04.trimmed_fasta/` | **Required**      |
| `queue`  | SLURM account/partition                                  | `` |
| `QOS`    | SLURM QOS                                                | `normal`          |

### Output (per sample)
SortMeRNA results are generated by `05.sortmerna.pbs` and typically include:
| File                          | Description                             | Usage                                                    |
| ----------------------------- | --------------------------------------- | -------------------------------------------------------- |
| **`$SAMPLE_ribosomal.log`**   | SortMeRNA execution log                 | Check errors, quality control                            |
| **`$SAMPLE_ribosomal.sam`**   | SAM file containing rRNA alignments     | Mapping quality inspection (rarely used)                 |
| **`$SAMPLE_ribosomal.fa`**    | Extracted rRNA reads (16S/23S/18S etc.) | QIIME2 taxonomy, SILVA-based classification              |
| **`$SAMPLE_ribosomal.blast`** | BLAST-like hit summary                  | Reference similarity / taxonomy investigation            |
| **`$SAMPLE_nonribosomal.fa`** | Non-rRNA (cleaned) reads                | Metagenome assembly, gene profiling, downstream analysis |
