#!/bin/bash
#SBATCH --time=12:00:00             # Time limit for the job (REQUIRED).
#SBATCH --job-name=04.adundance_MAGs   # Job name
#SBATCH --ntasks=4                  # Number of cores for the job. Same as SBATCH -n 1
#SBATCH --partition=normal          # Partition/queue to run the job in. (REQUIRED)
#SBATCH -e /scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/zz.TMP/04.abundance_MAGs-%j.err             # Error file for this job.
#SBATCH -o /scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/zz.TMP/04.abundance_MAGs-%j.out             # Output file for this job.
#SBATCH --account=coa_mki314_uksr   # Project allocation account name (REQUIRED)

if [[ "$1" == "" || "$1" == "-h" ]] ; then
   echo "
   Usage: sbatch ./04.abundance.bash [folder]

   folder      Path to the folder containing *.tad80.tsv. It should be in 29.TAD80/TAD80/ directory.

   " >&2 ;
   exit 1 ;
fi ;
dir=$(readlink -f $1) ;
cd $dir
for i in abundance ; do
   [[ -d $i ]] || mkdir $i
done

#----------------------------------------------------------------------------------------------------------------------------------------------------------
cd /scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/14.microbe_census

{
  printf "sample\tgenome_equivalents\n"
  for i in *.microbecensus.out; do
    b=$(basename "$i" .microbecensus.out)
    ge=$(
      awk -F':' '/^genome_equivalents:/ {
        val=$2
        gsub(/^[ \t]+/, "", val)      # trim leading spaces/tabs
        gsub(/[ \t\r]+$/, "", val)    # trim trailing spaces/tabs/CR
        print val
        exit
      }' "$i"
    )
    printf "%s\t%s\n" "$b" "$ge"
  done
} > MicrobeCensus_genome_equivalents.txt

# In next line, chenage the path to your MicrobeCensus_genome_equivalents.txt
ge="/scratch/sch496/sj/metagenomic_analysis_pipeline_UKY/FASTQ/fastq_files/14.microbe_census/MicrobeCensus_genome_equivalents.txt"
#-----------------------------------------------------------------------------------------------------------------------------------------------------------

cd "$dir/abundance"

shopt -s nullglob
files=()

for i in "$dir"/*.tad80.tsv ; do
  ds=$(basename "$i" .tad80.tsv)

  # genome_equivalents 추출: 1열 정확 일치로 매칭
  norm=$(awk -v ds="$ds" 'NR==1{next} $1==ds {print $2; exit}' "$ge" | tr -d '\r')

  if [[ -z "${norm:-}" ]]; then
    echo "WARN: genome_equivalents not found for sample '$ds' — skip" >&2
    continue
  fi

  out="${ds}.abundance.txt"
  # 두 번째 열을 norm으로 나눠서 '한 줄 한 값'만 출력
  awk -v norm="$norm" '{printf "%.10g\n", $2 / norm}' "$i" > "$out"

  # 빈 파일이면 제외
  [[ -s "$out" ]] && files+=("$out")
done

# 실제 생성된 abundance 파일들로 헤더를 만든다 (열 수 항상 일치)
{
  printf "Bin"
  for f in "${files[@]}"; do
    ds=${f%.abundance.txt}
    printf "\t%s" "$ds"
  done
  printf "\n"
} > 04.abundance.tsv

# 본문: 03.tad.list + 생성된 abundance 열들
paste "$dir/03.tad.list" "${files[@]}" >> 04.abundance.tsv

# 검증: 모든 행의 필드 수가 헤더와 같은지
awk -F'\t' 'NR==1{c=NF; next} NF!=c{print "line",NR,"has",NF,"(expected",c")"}' 04.abundance.tsv | head
