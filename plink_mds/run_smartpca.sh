#!/usr/bin/env bash

input_geno=$1
input_snp=$2
input_ind=$3
poplist=$4
cpus=$5

## Only run if the bed file has been updated
if [[ $(readlink -f ${input_geno}) -nt ${output_dir}/West_Eurasian_pca.evec ]]; then
    echo -e "genotypename: ${input_geno}" >smartpca.par
    echo -e "snpname: ${input_snp}" >>smartpca.par
    echo -e "indivname: ${input_ind}" >>smartpca.par
    echo -e "evecoutname: West_Eurasian_pca.evec" >>smartpca.par
    echo -e "evaloutname: West_Eurasian_pca.eval" >>smartpca.par
    echo -e "poplistname: ${poplist}" >>smartpca.par
    echo -e "outliermode: 2" >>smartpca.par
    echo -e "numthreads: ${cpus}" >>smartpca.par
    echo -e "lsqproject: YES" >>smartpca.par
    echo -e "autoshrink: YES" >>smartpca.par
    smartpca -p smartpca.par
else
    echo "No changes in the 'microscope_pca' package since the PCA was computed."
    echo "Halting execution"
    exit 0
fi
