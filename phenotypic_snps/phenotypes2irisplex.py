#!/usr/bin/env python

import sys
import argparse

def complement_of(x):
  complementary_bases ={
    "A":"T",
    "T":"A",
    "C":"G",
    "G":"C"
  }
  
  return(complementary_bases[x.upper()])

def round_to_nearest_half(number):
  return round(number * 2) / 2

parser = argparse.ArgumentParser(usage="%(prog)s [-h] [Input]" , description="Convert the output table of infer_phenotypes.py into an HIrisPlex compatible csv.")
parser.add_argument("-m", "--min_count", type=int, default=0, help="A minimum required count of reads covering a SNP before a genotype call is made. SNPs with fewer than this many reads will be left as NA. Default is 1.")
parser.add_argument("Input", type=argparse.FileType('r'), nargs="?", help="The input Phenotype table file. When no input file is given, read from stdin.")
args = parser.parse_args()

if args.Input:
    In=args.Input
else:
    In=sys.stdin

header= [
  "sampleid",
  "rs312262906_A",
  "rs11547464_A",
  "rs885479_T",
  "rs1805008_T",
  "rs1805005_T",
  "rs1805006_A",
  "rs1805007_T",
  "rs1805009_C",
  "rs201326893_A",
  "rs2228479_A",
  "rs1110400_C",
  "rs28777_C",
  "rs16891982_C",
  "rs12821256_G",
  "rs4959270_A",
  "rs12203592_T",
  "rs1042602_T",
  "rs1800407_A",
  "rs2402130_G",
  "rs12913832_T",
  "rs2378249_C",
  "rs12896399_T",
  "rs1393350_T",
  "rs683_G"
]

## Table to convert rsTags to the column names in the output file
lookup_table = {
  x.split("_")[0] : x for x in header[1:]
}

snp_alleles = {
  x.split("_")[0] : x.split("_")[1] for x in header[1:]
}

in_header= In.readline().strip().split("\t")
sample_names = in_header[ 6::2 ] # skip the first 6 columns and then take every second column
sample_names = sample_names[:-1] # remove the last column
## Keep only the sample IDs
sample_names = [ x[0:9] for x in sample_names ]
## Clean sample names
for idx,name in enumerate(sample_names):
  if name[-3:] != "_ss":
    sample_names[idx] = name[0:6]
  else:
    continue

## Create dictionary with sample names as keys and a dictionary of the value of each snp as values
results = {}
for name in sample_names:
  results[name] = { snp : "NA" for snp in header[1:] }

for line in In:
  allele_bases=[]
  fields = line.strip().split("\t")
  rsTag = fields[3]
  ## If the SNP is not one we are interested in, skip it
  if rsTag not in snp_alleles:
    continue
  allele_bases = fields[4:6]
  ## If the expected allele is in the available ones, assume the strands are correct and take it as is
  ## CAVEAT: This will get the wrong allele in case of transversions SNPs with a strand flip.
  if snp_alleles[rsTag] in allele_bases:
    ## If the alleles are complementary, throw out a warning so I can manually check them against HIrisPlex
    ## Both snps that threw an error seemed to have the correct parity between HIrisPlex and the input file [rs16891982, rs1805009]
    # if allele_bases[1] == complement_of(allele_bases[0]):
    #   print("WARNING: The alleles for SNP {} are complementary. This might be a transversion SNP with a strand flip.".format(rsTag), file=sys.stderr)
    nudge = allele_bases.index(snp_alleles[rsTag])
  else:
    ## Otherwise, take the complement of the expected allele
    nudge = allele_bases.index(complement_of(snp_alleles[rsTag]))
  
  for sample in sample_names:
    ## The allele counts are start in column 7 (idx 6) and are two columns for each sample
    allele_1           = int(fields[ 6 + (sample_names.index(sample)*2) ] )
    allele_2           = int(fields[ 6 + (sample_names.index(sample)*2) + 1 ] )
    allele_of_interest = int(fields[ 6 + (sample_names.index(sample)*2) + nudge ] )
    ## Compute the number of allele copies as twice the allele frequency after rounding to the nearest half.
    try:
      ## Only update "calls" if more than the minimum count of reads are present
      if allele_1 + allele_2 >= args.min_count:
        results[sample][lookup_table[rsTag]] = round_to_nearest_half(allele_of_interest/sum([allele_1,allele_2])) * 2
    except ZeroDivisionError:
      ## Result is NA if the sum of the alleles is 0
      continue

## Finally, print the output into stdout
print(",".join(header), file=sys.stdout)
for sample in sorted(sample_names):
  sample_result = ""
  sample_result += sample + ","
  for snp in header[1:]:
    sample_result += str(results[sample][snp]) + ","
  ## Remove the trailing comma and print the result
  print(sample_result[:-1], file=sys.stdout)
