How to run ruby consolidate-spp.rb:  
ruby consolidate-spp.rb ./04.abundance.tsv ./ dRep_clusters.csv > ./ANIspp.abundance.tsv  
Put  input files in one folder.   
input files are: 04.abundance.tsv (abundance table from 04.abaundance.bash) and list of clusters from dRep (dRep_clusters.csv: each line or raw of this file contain MAGs ID belonging to one cluster).  
Keep in mind that list of clusters should not contain header. It is a csv file only has one column, each raw of this column contain MAGs ID belong to one cluster. MAGs ID in each must be separated with “,” and there should be no space between them.   
2.	Put consolidate-spp.rb script in that folder.    
3.	Make it executable : chmod +x consolidate-spp.rb.  
4.	source /project/mki314_uksr/miniconda3/etc/profile.d/conda.sh  
5.	conda activate ruby   
6.	finally run this command:  
ruby consolidate-spp.rb ./04.abundance.tsv ./ dRep_clusters.csv > ./ANIspp.abundance.tsv  
