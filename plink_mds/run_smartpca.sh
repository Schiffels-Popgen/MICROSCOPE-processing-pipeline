#!/usr/bin/env bash

input_geno=$1
input_snp=$2
input_ind=$3
poplist=$4
cpus=$5
out_prefix=$6

output_dir='/mnt/archgen/MICROSCOPE/automated_analysis/microscope_pca'

## Only run if the bed file has been updated
if [[ $(readlink -f ${input_geno}) -nt ${output_dir}/${out_prefix}.evec ]]; then
    echo -e "genotypename: ${input_geno}" >smartpca.par
    echo -e "snpname: ${input_snp}" >>smartpca.par
    echo -e "indivname: ${input_ind}" >>smartpca.par
    echo -e "evecoutname: ${out_prefix}.evec" >>smartpca.par
    echo -e "evaloutname: ${out_prefix}.eval" >>smartpca.par
    echo -e "poplistname: ${poplist}" >>smartpca.par
    echo -e "outliermode: 2" >>smartpca.par
    echo -e "numthreads: ${cpus}" >>smartpca.par
    echo -e "lsqproject: YES" >>smartpca.par
    echo -e "snpweightoutname: ${out_prefix}.weights" >>smartpca.par
    # echo -e "autoshrink: YES" >>smartpca.par
    smartpca -p smartpca.par
else
    echo "No changes in the 'microscope_pca' package since the PCA was computed."
    echo "Halting execution"
    exit 0
fi
