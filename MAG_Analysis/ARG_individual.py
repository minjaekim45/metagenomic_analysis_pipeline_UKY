#!/usr/bin/env python3
import csv
import sys

file1=sys.argv[1] #.ARG
file2=sys.argv[2] #.out
file3=sys.argv[3] #.length
file4=sys.argv[4] # output1 mastertable
file5=sys.argv[5] # output2 class table for merge

ARG_dict = {} #key geneID, value: [length,,,]
Class_dict = {} # Key class (row[4]), value: [length,,,]
feature_dict = {} #key geneID, value : genelength

with open(file1) as csvfile:
    spamreader = csv.reader (csvfile, delimiter='\t')
    next(spamreader, None) # Skip the first line
    for row in spamreader:
        key = row[5]
        value = int(row[8])

        if key not in ARG_dict:
            ARG_dict[key] = [value]
        else:
            ARG_dict[key].append(int(row[8]))
    # print(ARG_dict)

with open(file2) as csvfile:
    spamreader = csv.reader (csvfile, delimiter='\t')
    for row in spamreader:
        if len(row) !=0 and row[0] == 'genome_equivalents:':
            out_value = float(row[1])
    # print(out_value)

with open(file3) as csvfile:
    spamreader = csv.reader (csvfile, delimiter='\t')
    for row in spamreader:
        # print(row)
        feature_dict[row[0]] = int(row[1])
    # print(feature_dict)

masterTable_dict = {} # key: geneID, value: normalized value

with open (file4, 'w', newline="") as f:
        file = csv.writer(f, delimiter='\t')
        file.writerow(['Gene_ID', 'No. of hit', 'SUM', 'Gene_Length', 'Genome_EquValues', 'Score'])
        for k1, v1 in ARG_dict.items():
            for k2, v2 in feature_dict.items():
                if k1 == k2:
                    file.writerow([k1, len(v1), sum(v1), v2, out_value, (sum(v1) / v2) / out_value])

                    key = k1
                    value = (sum(v1) / v2) / out_value
                    masterTable_dict[key] = value

# print(masterTable_dict)

ARG_class_dict = {} # key: fourth elements in key of masterTable_dict, value =[normalized value,,,]

for k, v in masterTable_dict.items():
    ARGclass = k.split("|")
    # print(ARGclass[3])
    key = ARGclass[3]
    value = float(v)
    if key not in ARG_class_dict:
        ARG_class_dict[key] = [value]
    else:
        ARG_class_dict[key].append(float(v))
# print(ARG_class_dict)

with open(file5, 'w', newline='') as f:
    file = csv.writer(f, delimiter='\t')
    #file.writerow(['Class', 'Score'])
    for k, v in ARG_class_dict.items():
        file.writerow([k, sum(v)])
