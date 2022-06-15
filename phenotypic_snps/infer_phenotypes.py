#!/usr/bin/env python3

def complement_of(x):
  complementary_bases ={
    "A":"T",
    "T":"A",
    "C":"G",
    "G":"C"
  }
  
  return(complementary_bases[x.upper()])

import sys, argparse

parser = argparse.ArgumentParser(usage="%(prog)s [-h] [Input]" , description="Calculate allele frequency per individual from mpileup output for each position.")
parser.add_argument("-a", "--annotation", type=argparse.FileType('r'), required=True,  metavar="<SNP ANNOTATION FILE>", help="A SNP annotation file with the non-effect and effect alleles for each SNP, as well as other information. See example file 'SNPs.txt' for the desired format.")
parser.add_argument("-f", "--sample_list", type=argparse.FileType('r'), help="A list of samples/bams that were in the depth file to use for the header instead of generic names. One per line. Should be in the order of the samtools mpileup output.")
parser.add_argument("Input", type=argparse.FileType('r'), nargs="?", help="The input pileup file. When no input file is given, read from stdin.")
args = parser.parse_args()

if args.Input:
    In=args.Input
else:
    In=sys.stdin

Depth=[]
Freqs={}
C=0

effect_alleles = {}
noneffect_alleles = {}
snp_strands = {}
genes={}
rs_tags={}
effect_phenotypes={}

## Read in information from annotation file
for line in args.annotation:
  fields=line.strip().split("\t")
  # print(fields)
  Gene=fields[0]
  Chrom=fields[2]
  Pos=fields[3]
  Rs_tag=fields[4]
  Strand=fields[5]
  nonEffect=fields[6]
  Effect=fields[7]
  phenotypic_effect=fields[8]
  chr_pos="{}_{}".format(Chrom, Pos)
  # print (chr_pos, noneffect, effect)
  noneffect_alleles[chr_pos]=nonEffect
  effect_alleles[chr_pos]=Effect
  snp_strands[chr_pos]=Strand
  genes[chr_pos]=Gene
  rs_tags[chr_pos]=Rs_tag
  effect_phenotypes[chr_pos]=phenotypic_effect
# print(effect_phenotypes)

## if a sample list is provided, read sample names from that
if args.sample_list != None:
    sample_names = [line.strip() for line in args.sample_list]

for line in In:
    fields=line.strip().split("\t")
    Chrom=fields[0]
    Pos=fields[1]
    Ref=fields[2]
    chr_pos = "{}_{}".format(Chrom, Pos)
    Data=fields[3:]
    # for i in range(len(Data)):
        # if Data[i] == "":
        #     Data[i] = "±"
    NumIndivs=int(len(Data)/3)
    switch="on"
    while C==0:
        print ("Gene\tChromosome\tPosition\trs\tNon-effect allele (on + strand)\tEffect allele (on + strand)\t", end="")
        if args.sample_list != None:
          assert len(sample_names) == NumIndivs, "Number of individuals in provided sample list and mpileup are inconsistent."
          print(*sample_names, sep="\t\t", end="\t\t")
        else:
          for i in range(NumIndivs):
              print ("Sample", i, "\t\t", sep="", end="")
        
        print("Phenotypic effect", sep="", end="")
        print ("\n\t\t\t\t\t\t", end="")
        for i in range(NumIndivs):
            print ("Non-effect\tEffect\t", end="")
        print("")
        C+=1
    for i in range(NumIndivs):
        Depth=int(Data[0+(3*i)])
        Bases=Data[1+(3*i)]
        Temp=Bases.replace(".",Ref).replace(",",Ref).upper()
        if Depth == 0:
            Freqs["A"]=0#.0
            Freqs["G"]=0#.0
            Freqs["T"]=0#.0
            Freqs["C"]=0#.0
        else:
            Freqs["A"]=Temp.count("A")#/1#/Depth
            Freqs["G"]=Temp.count("G")#/1#/Depth
            Freqs["T"]=Temp.count("T")#/1#/Depth
            Freqs["C"]=Temp.count("C")#/1#/Depth
        while switch=="on":
            print (genes[chr_pos], Chrom, Pos, rs_tags[chr_pos], "", sep="\t", end="")
            if snp_strands[chr_pos] == "+":
              print(noneffect_alleles[chr_pos],effect_alleles[chr_pos], "", sep="\t", end="")
            elif snp_strands[chr_pos] == "-":
              print(complement_of(noneffect_alleles[chr_pos]),complement_of(effect_alleles[chr_pos]), "", sep="\t", end="")
            switch="off"
        ## mpileup reports the + strand alleles. If a SNP is on the + strand, then the effect/noneffect alleles are used as is. 
        ## If not, then they are complemented to get the correct counts from the pileup.
        if snp_strands[chr_pos] == "+":
          print ("{}\t{}\t".format(Freqs[noneffect_alleles[chr_pos]], Freqs[effect_alleles[chr_pos]]), sep="\t", end="")
        elif snp_strands[chr_pos] == "-":
          print ("{}\t{}\t".format(Freqs[complement_of(noneffect_alleles[chr_pos])], Freqs[complement_of(effect_alleles[chr_pos])]), sep="\t", end="")
        else:
          print("Strand not provided for SNP at position {}. Skipping SNP.".format(chr_pos), file=sys.stderr)
    print(effect_phenotypes[chr_pos])
