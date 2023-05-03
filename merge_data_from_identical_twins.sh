#!/usr/bin/env bash

## This script is ran on the eager input TSV of a batch only if an identical twins annotation file exists for the batch.
## It duplicates the rows of the individual in the merge_this column, and replaces the individual ID with the one in the into_this column.
## To avoid file name collisions, it also creates symlinks for the R1/R2 columns of the merge_this individual, and points to those symlinks in the R1/R2 of the duplicated rows.
## Usage: 
##    merge_data_from_identical_twins.sh <input_eager_tsv> <identical_twins_tsv>

DIR="/mnt/archgen/MICROSCOPE"
input_eager_tsv=$(readlink -f "${1}")
identical_twins_tsv=$(readlink -f "${2}")
temp_tsv="${DIR}/.tmp/tsvs/$(basename ${input_eager_tsv}).tmp"
symlink_dir="$(dirname ${identical_twins_tsv})/symlinks/$(basename -s .identical_twins.tsv ${identical_twins_tsv})"

## Copy the input eager TSV to a temporary file
cp ${input_eager_tsv} ${temp_tsv}

## Read through the identical twins annotation file and create symbolic links for the R1/R2 columns of the merge_this individual, then
## duplicate the rows of the individual in the merge_this column, and replace the individual ID with the one in the into_this column, and the R1/R2 columns with the symlinks created above.
while read -r merge_this into_this; do
  if [[ ${merge_this} == 'merge_this' ]]; then
    ## Ignore the header line
    continue
  fi

  ## Read and unpack the lines of the input tsv that correspond to the merge_this individuals (with or without the'_ss' suffix)
  while IFS=$'\t' read -r sample_name library_id lane colour_chemistry seqtype organism strandedness udg_treatment r1 r2 bam ; do
    
    data_target_ind="${into_this}"
    
    ## If data is single-stranded, then the sample name will be suffixed with '_ss', and the target individual ID should be suffixed with '_ss' as well.
    if [[ ${sample_name} != ${merge_this} ]] && [[ ${sample_name} == ${merge_this}_ss ]]; then
      data_target_ind="${into_this}_ss"
    fi

    ## DEBUG
    # for field in sample_name library_id lane colour_chemistry seqtype organism strandedness udg_treatment r1 r2 bam; do
    #   echo -e "${field}:\t${!field}"
    # done  
    # continue

    ## Create symlinks for the R1/R2/BAM columns of the merge_this individual
    mkdir -p ${symlink_dir}
    for field in r1 r2 bam; do
      if [[ ${!field} == 'NA' ]]; then
        eval "new_${field}='NA'"
      else
        target="${symlink_dir}/${data_target_ind}_$(basename ${!field})"
        eval "new_${field}=${target}"
        ln -s ${!field} ${target}
      fi
    done

    ## Duplicate the rows of the individual in the merge_this column, and replace the individual ID with the one in the into_this column, and the R1/R2 columns with the symlinks created above.
    echo -e "${data_target_ind}\t${library_id}\t${lane}\t${colour_chemistry}\t${seqtype}\t${organism}\t${strandedness}\t${udg_treatment}\t${new_r1}\t${new_r2}\t${new_bam}" >> ${temp_tsv}

  done < <(awk -v merge_this="${merge_this}" 'BEGIN{OFS=IFS="\t"} $1 == merge_this || $1 == merge_this"_ss"' ${input_eager_tsv})
  
done < ${identical_twins_tsv}

## Finally, make a backup of the input eager TSV and then replace it with the temporary file
cp ${input_eager_tsv} ${input_eager_tsv}.bak
## Only replace file if backup was successful
if [[ $? -eq 0 ]]; then
  mv ${temp_tsv} ${input_eager_tsv}
fi
