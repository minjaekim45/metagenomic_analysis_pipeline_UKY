# Scripts

## Step 1 KO-based MAG screening

`scripts/step1_screen_candidates_by_kos.py` performs a first-pass screen of MAGs
by matching KOs in eggNOG emapper annotations to a gene-set TSV. For each
metabolism, it computes step coverage per MAG and labels a MAG as a candidate
if it passes both step coverage and required-gene presence thresholds.

Inputs:
- Gene-set TSV with columns `Metabolism`, `Step`, and `KEGG_ko`.
- eggNOG emapper annotation files under `FASTQ/fastq_files/34.eggnog`.

Outputs (default `FASTQ/fastq_files/36.functionalprofiling`):
- `candidate_mags_{metabolism}.txt`
- `mag_step_coverage_summary.tsv`

Criteria (Step 1):
- A MAG covers a step if it contains at least one KO belonging to that step.
- For each metabolism:
  - `total_steps` = number of steps defined in the gene-set TSV.
  - `required_steps` = ceil(`total_steps` * `threshold`).
  - `total_required_genes` = number of unique required KOs for that metabolism.
  - `present_required_genes` = number of those required KOs present in the MAG.
  - `gene_presence_fraction` = `present_required_genes / total_required_genes`.
  - A MAG is a candidate only if all of the following are true:
    - `covered_steps >= 1`
    - `covered_steps >= required_steps`
    - `gene_presence_fraction > gene_presence_threshold` (default: `0.5`)

Example:
```bash
python3 scripts/step1_screen_candidates_by_kos.py \
  --gene_set_tsv scripts/gene_sets_step1.tsv \
  --eggnog_root FASTQ/fastq_files/34.eggnog \
  --outdir FASTQ/fastq_files/36.functionalprofiling \
  --metabolisms Propionate,Butyrate,Acetate \
  --threshold 0.75 \
  --gene_presence_threshold 0.5
```

Per-metabolism thresholds (override `--threshold`):
```bash
python3 scripts/step1_screen_candidates_by_kos.py \
  --gene_set_tsv scripts/gene_sets_step1.tsv \
  --eggnog_root FASTQ/fastq_files/34.eggnog \
  --outdir FASTQ/fastq_files/36.functionalprofiling \
  --metabolisms Propionate,Butyrate,Acetate \
  --thresholds Acetate=0.75,Butyrate=1.0,Propionate=1.0 \
  --gene_presence_threshold 0.5
```

## Step 2 KO evidence extraction (Bakta + eggNOG)

`scripts/step1_extract_bakta_evidence.py` generates per-MAG evidence CSVs for
candidate MAGs by combining eggNOG KO hits with Bakta GFF3 product/PFAM and
protein lengths.

Example:
```bash
python3 scripts/step1_extract_bakta_evidence.py \
  --gene_set_tsv scripts/gene_sets_step1.tsv \
  --candidate_dir FASTQ/fastq_files/36.functionalprofiling \
  --eggnog_root FASTQ/fastq_files/34.eggnog \
  --bakta_root FASTQ/fastq_files/11.bakta/results \
  --out_root FASTQ/fastq_files/36.functionalprofiling \
  --metabolisms propionate,butyrate,acetate
```

## Step 3 Pfam validation (hmmscan)

`scripts/step3_pfam_validation.py` validates candidate marker genes using Pfam
hmmscan on a subset of proteins per MAG, then writes gene- and MAG-level
validation summaries.

Example:
```bash
python3 scripts/step3_pfam_validation.py \
  --pfam_hmm /path/to/Pfam-A.hmm \
  --functional_dir FASTQ/fastq_files/36.functionalprofiling \
  --bakta_root FASTQ/fastq_files/11.bakta/results \
  --metabolisms propionate,butyrate,acetate \
  --cpu 8 \
  --threshold 0.75 \
  --evalue_pass 1e-5 \
  --cov_pass 0.60 \
  --cov_hold 0.40
```

Criteria used in outputs:
- Gene-level labels in `pfam_validation_gene_level.tsv`:
  - PASS: any Pfam domain hit has i-Evalue <= `evalue_pass` and HMM coverage >= `cov_pass`
  - HOLD: any Pfam domain hit has i-Evalue <= `evalue_pass` and `cov_hold` <= HMM coverage < `cov_pass`
  - FAIL: no Pfam domain hit meets i-Evalue <= `evalue_pass` (or only hits with HMM coverage < `cov_hold`)
  - NO_PFAM: no Pfam hits for the query
- MAG-level labels in `pfam_validation_mag_level.tsv`:
  - CONFIRMED: `steps_with_pass` >= ceil(`steps_total` * `threshold`)
  - PUTATIVE: `steps_with_hold_or_pass` >= ceil(`steps_total` * `threshold`) but `steps_with_pass` below threshold
  - NOT_SUPPORTED: otherwise

## Step 4 BLASTp review for HOLD/FAIL

`scripts/step4_blastp_hold_fail.py` runs BLASTp only for genes labeled HOLD/FAIL
in `pfam_validation_gene_level.tsv` and produces a summarized table for review.

Query selection:
- Only rows with label `HOLD` or `FAIL`
- Unique queries by (MAG_ID, query), with merged `step` and `KEGG_ko` values

Hit quality labels in `blastp_hold_fail_summary.tsv`:
- GOOD: `qcovs` >= `min_qcov` * 100 and `pident` >= `min_pident`
- WEAK: hit exists but fails GOOD thresholds
- NO_HIT: no BLAST record for the query

Example:
```bash
python3 scripts/step4_blastp_hold_fail.py \
  --pfam_gene_tsv FASTQ/fastq_files/36.functionalprofiling/pfam_validation_gene_level.tsv \
  --bakta_root FASTQ/fastq_files/11.bakta/results \
  --outdir FASTQ/fastq_files/37.blastp_hold_fail \
  --db /path/to/blast_db_prefix \
  --cpu 8 \
  --max_target_seqs 10 \
  --evalue 1e-5 \
  --min_qcov 0.70 \
  --min_pident 50
```

## Step 5 SOB abundance table + plots

`scripts/step5_sob_abundance.py` creates `SOB_TAD80.csv` by filtering ANI clades
using Step 1 criteria and merging with TAD80 abundance. It also generates stacked
bar plots by metabolism and a combined SAOB/SPOB/SBOB plot.

Step 5 filtering criteria:
- `covered_steps >= 1`
- `covered_steps >= required_steps` (where `required_steps = ceil(total_steps * threshold)`)
- `gene_presence_fraction > gene_presence_threshold` (default `0.5`)

Arguments:
- `--tad_xlsx` path to `TAD80_abundance_by_taxonomy.xlsx`
- `--tad_csv` output CSV converted from the first sheet
- `--ani_summary` ANI clade summary TSV
- `--gene_set_tsv` gene set TSV to compute total steps
- `--out_csv` output `SOB_TAD80.csv`
- `--threshold` default step coverage threshold
- `--thresholds` per-metabolism thresholds (e.g., `acetate=0.75,propionate=1,butyrate=1`)
- `--gene_presence_threshold` required-gene presence fraction threshold (default `0.5`)
- `--plot_dir` output directory for plots
- `--plot_label` column to use as plot label (defaults to `Label`; groups and sums if different)

Example:
```bash
python3 scripts/step5_sob_abundance.py \
  --tad_xlsx FASTQ/fastq_files/29.TAD80/TAD80_abundance_by_taxonomy.xlsx \
  --tad_csv FASTQ/fastq_files/29.TAD80/TAD80.csv \
  --ani_summary FASTQ/fastq_files/36.functionalprofiling/ani_clade_summary.tsv \
  --gene_set_tsv scripts/gene_sets_step1.tsv \
  --out_csv FASTQ/fastq_files/29.TAD80/SOB_TAD80.csv \
  --thresholds acetate=0.75,propionate=1,butyrate=1 \
  --gene_presence_threshold 0.5 \
  --plot_dir FASTQ/fastq_files/29.TAD80/plots \
  --plot_label Label
```
