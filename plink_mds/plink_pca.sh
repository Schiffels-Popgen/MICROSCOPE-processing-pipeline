#!/usr/bin/env bash

input_dir="/mnt/archgen/MICROSCOPE/forged_packages/microscope_pca"
output_dir="/mnt/archgen/MICROSCOPE/microscope_pca/"
## Only run if the bed file has been updated
if [[ ${input_dir}/microscope_pca.bed -nt ${output_dir}/pairwise_distances.mdist ]]; then
    plink --bfile ${input_dir}/microscope_pca \
    --distance-matrix \
    --out ${output_dir}/pairwise_distances
else
    echo "No changes in the 'microscope_pca' package since the distance matrix was computed."
    echo "Halting execution"
    exit 0
fi
