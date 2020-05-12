#!/usr/bin/env bash
DIR="/projects1/MICROSCOPE"

for seq_batch in ${DIR}/sequencing_batches/*; do
	fn_eager_input="${DIR}/eager_inputs/$(basename ${seq_batch} .txt).eager_input.tsv"
	if [[ ${seq_batch} -nt ${fn_eager_input} ]]; then
		echo "Now processing ${seq_batch}"
		~lamnidis/Software/Pipelining/query_pandora_for_data.R ${seq_batch} ~lamnidis/Software/Pipelining/.credentials \
			>${DIR}/eager_inputs/$(basename ${seq_batch} .txt).eager_input.tsv
	else
		echo "${seq_batch} has already been processed"
	fi
	echo ""
done
