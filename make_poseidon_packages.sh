#!/usr/bin/env bash


mkdir -p /mnt/archgen/MICROSCOPE/poseidon_packages

for seq_batch in $(find /mnt/archgen/MICROSCOPE/eager_outputs/* -maxdepth 0 ! -path "*2021-01-27-Prague_bams"); do
    batch_name=$(basename ${seq_batch})
    ## Prefer single stranded to double stranded library data for genotypes.
    if [[ ${seq_batch}/genotyping/pileupcaller.single.geno.txt -nt poseidon_packages/${batch_name}/POSEIDON.yml ]]; then
        echo "SSLib found for ${batch_name}"
        regex="s/pileupcaller.single/${batch_name}/"
        # echo $(basename $seq_batch)
        trident init \
            --inFormat EIGENSTRAT \
            --snpSet 1240K \
            --genoFile /mnt/archgen/MICROSCOPE/eager_outputs/${batch_name}/genotyping/pileupcaller.single.geno.txt \
            --snpFile /mnt/archgen/MICROSCOPE/eager_outputs/${batch_name}/genotyping/pileupcaller.single.snp.txt \
            --indFile /mnt/archgen/MICROSCOPE/eager_outputs/${batch_name}/genotyping/pileupcaller.single.ind.txt \
            -o /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name} \
            -n ${batch_name}

        sed -i -e ${regex} /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/POSEIDON.yml
        rename -e ${regex} /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/pileupcaller.*.txt


    ## If no single stranded genotypes exist, use double stranded library data for genotypes instead.
    elif [[ ${seq_batch}/genotyping/pileupcaller.double.geno.txt -nt poseidon_packages/${batch_name}/POSEIDON.yml ]]; then
        echo "DSLib found for ${batch_name}"
        regex="s/pileupcaller.double/${batch_name}/"
        # echo $(basename $seq_batch)
        trident init \
            --inFormat EIGENSTRAT \
            --snpSet 1240K \
            --genoFile /mnt/archgen/MICROSCOPE/eager_outputs/${batch_name}/genotyping/pileupcaller.double.geno.txt \
            --snpFile /mnt/archgen/MICROSCOPE/eager_outputs/${batch_name}/genotyping/pileupcaller.double.snp.txt \
            --indFile /mnt/archgen/MICROSCOPE/eager_outputs/${batch_name}/genotyping/pileupcaller.double.ind.txt \
            -o /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name} \
            -n ${batch_name}

        sed -i -e ${regex} /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/POSEIDON.yml
        rename -e ${regex} /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/pileupcaller.*.txt
    fi
done

