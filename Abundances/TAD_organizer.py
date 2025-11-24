#!bin/bash 
# functions
import pandas as pd
import os
import sys

# Set the working directory to the current script's directory
os.chdir(os.path.dirname(os.path.abspath(sys.argv[0])))

#input files
abundance_path = 'TAD80/abundance/ANIspp.abundance.tsv'
MAG_path = '../dRep_clusters.csv'
taxonomy_path = '../17.gtdbtk/gtdbtk.all.summary.tsv'

abundance = pd.read_csv(abundance_path, sep = '\t')
MAG_single = pd.read_fwf(MAG_path, header=None, names=["MAG_info"], widths=[10_000])
taxonomy = pd.read_csv(taxonomy_path, sep = '\t')

abundance = abundance.copy()
abundance["MAG_info"] = MAG_single["MAG_info"].reindex(range(len(abundance))).reset_index(drop=True).str.split(',')

# match taxonomy with genome id
taxonomy_subset = taxonomy[["user_genome", "classification", "closest_genome_reference"]]
taxonomy_subset["user_genome"] = taxonomy_subset["user_genome"].apply(lambda x: x.split('.fa')[0])

def taxonomy_matching(x):
    classification = taxonomy_subset[taxonomy_subset["user_genome"].isin(x)].classification.unique().tolist()
    if len(classification) > 1:
        classification = [max(classification, key = len)]
    closest_genome_reference = taxonomy_subset[taxonomy_subset["user_genome"].isin(x)].closest_genome_reference.unique().tolist()
    if len(closest_genome_reference) > 1:
        closest_genome_reference = [a for a in closest_genome_reference if not pd.isna(a)]
    return classification[0], closest_genome_reference[0]

abundance["classification"] = abundance["MAG_info"].apply(lambda x: taxonomy_matching(x)[0])
abundance["closest_genome_reference"] = abundance["MAG_info"].apply(lambda x: taxonomy_matching(x)[1])

# taxonomy classification
col_names = ['Domain', 'Phylum', 'Class', 'Order', 'Family', 'Genus', 'Species']
abundance[col_names] = pd.DataFrame(abundance["classification"].apply(lambda x: x.split(";")).tolist(), index=abundance.index)
for col in col_names:
    abundance[col] = abundance[col].apply(lambda x: x.split("__")[-1])
column_order = ['classification', 'Domain', 'Phylum', 'Class', 'Order', 'Family', 'Genus', 'Species', 'closest_genome_reference', 'Clade', 
                'IR37_0d', 'IR37_6-5d', 'IR37_11-5d', 'IR37_13-5d', 'IR37_18-5d', 'IR37_20d', 'IR37_58d', 'IR37_120d']
abundance_sorted = abundance[column_order]

# grouping by taxonomy levels
def make_file(df, filename):
    df.to_excel(excel_writer=filename, sheet_name = "TAD80", index = False)
    for col in col_names:
        data = df.groupby(df[col]).sum(numeric_only=True)
        with pd.ExcelWriter(filename, mode = 'a', engine = 'openpyxl') as writer:
            data.to_excel(writer, sheet_name = col)

filename = "TAD80_abundance_by_taxonomy_dereplicate.xlsx"
make_file(abundance_sorted, filename)

# separating BAC & ARC files
BAC_filename = "TAD80_BAC_abundance_by_taxonomy_dereplicate.xlsx"
ARC_filename = "TAD80_ARC_abundance_by_taxonomy_dereplicate.xlsx"
abundance_BAC = abundance_sorted[abundance_sorted["Domain"] == "Bacteria"]
abundance_ARC = abundance_sorted[abundance_sorted["Domain"] == "Archaea"]
make_file(abundance_BAC, BAC_filename)
make_file(abundance_ARC, ARC_filename)


