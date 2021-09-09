#!/usr/bin/env bash
DIR="/mnt/archgen/MICROSCOPE"

cred_file="~thiseas_christos_lamnidis/Software/github/Schiffels-Popgen/MICROSCOPE-processing-pipeline/.credentials"

for seq_batch in ${DIR}/sequencing_batches/*; do
    fn_eager_input="${DIR}/eager_inputs/$(basename ${seq_batch} .txt).eager_input.tsv"
    if [[ ${seq_batch} -nt ${fn_eager_input} ]]; then
        echo "Now processing ${seq_batch}"
        ~thiseas_christos_lamnidis/Software/github/Schiffels-Popgen/MICROSCOPE-processing-pipeline/query_pandora_for_data.R ${seq_batch} ${cred_file} \
            >${DIR}/eager_inputs/$(basename ${seq_batch} .txt).eager_input.tsv
    else
        echo "${seq_batch} has already been processed"
    fi
    echo ""
done
