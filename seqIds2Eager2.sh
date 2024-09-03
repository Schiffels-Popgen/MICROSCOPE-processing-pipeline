#!/usr/bin/env bash
DIR="/mnt/archgen/MICROSCOPE"

cred_file="~thiseas_christos_lamnidis/Software/github/Schiffels-Popgen/MICROSCOPE-processing-pipeline/.credentials"

for seq_batch in ${DIR}/sequencing_batches/*; do
    fn_eager_input="${DIR}/eager_inputs/$(basename ${seq_batch} .txt).eager_input.tsv"
    fn_identical_twins="${DIR}/identical_twins_per_batch/$(basename ${seq_batch} .txt).identical_twins.tsv"
    if [[ ${seq_batch} -nt ${fn_eager_input} ]]; then
        echo "Now processing ${seq_batch}"
        /mnt/archgen/tools/pandora2eager/0.6.0/pandora2eager.sh --add_ss_suffix ${seq_batch} ${cred_file} \
            >${DIR}/eager_inputs/$(basename ${seq_batch} .txt).eager_input.tsv
        
        ## If an identical twins annotation file exists for the batch, then mark identical individuals in the eager input file
        if [[ -f ${fn_identical_twins} ]]; then
            echo -e "Marking identical twins/duplicate individuals in ${seq_batch}.\n\tBackup of original TSV will be saved as: '${fn_eager_input}.bak'"
            ~thiseas_christos_lamnidis/Software/github/Schiffels-Popgen/MICROSCOPE-processing-pipeline/merge_data_from_identical_twins.sh ${fn_eager_input} ${fn_identical_twins}
        fi
    elif [[ -f ${fn_identical_twins} ]] && [[ ${fn_identical_twins} -nt ${fn_eager_input} ]]; then
        ## This clause is to be used for updating batches that did not receive more data in the meantime, but got an identical twins annotation file after processing once.
        echo -e "Marking identical twins/duplicate individuals in EXISTING TSV for ${seq_batch}.\n\tBackup of original TSV will be saved as: '${fn_eager_input}.bak'"
        ~thiseas_christos_lamnidis/Software/github/Schiffels-Popgen/MICROSCOPE-processing-pipeline/merge_data_from_identical_twins.sh ${fn_eager_input} ${fn_identical_twins}
    else
        echo "${seq_batch} has already been processed"
    fi
    echo ""
done
