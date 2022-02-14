#!/usr/bin/env bash

## Read in -f positional argument
force='FALSE'
force_update_switch='FALSE'
if [[ $1 == "-f" ]]; then
    force="TRUE"
fi
if [[ $1 == "-u" ]]; then
    force_update_switch="TRUE"
fi

mkdir -p /mnt/archgen/MICROSCOPE/poseidon_packages
update_switch="off" ## Do any packages need updating? Then update al janno files with information from pandora.
## Colours to make prompts easier to read
Yellow=$(tput sgr0)'\033[1;33m' ## Yellow normal face
Normal=$(tput sgr0)

for seq_batch in $(find /mnt/archgen/MICROSCOPE/eager_outputs/* -maxdepth 0 ! -path "*2021-01-27-Prague_bams"); do
    batch_name=$(basename ${seq_batch})
    ## Prefer single stranded to double stranded library data for genotypes.
    if [[ (${force} == "TRUE" && -f ${seq_batch}/genotyping/pileupcaller.single.geno.txt) || (${seq_batch}/genotyping/pileupcaller.single.geno.txt -nt /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/POSEIDON.yml) ]]; then
        update_switch="on"
        echo -e "${Yellow}SSLib found for ${batch_name}${Normal}"
        ## If the directory already exists, delete it so trident doesn't complain
        if [[ -d "poseidon_packages/${batch_name}" ]]; then
            echo "Deleting existing directory poseidon_packages/${batch_name} to recreate package with new genotypes."
            rm -r /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}
        fi
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
        ## Remove trailing .txt from path names. Needed for loading the data into R with admixr.
        sed -i -e 's/.txt$//' /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/POSEIDON.yml
        rename -e 's/.txt$//' /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/${batch_name}*txt

        ## Also make plink format dataset (needed for READ)
        trident genoconvert -d /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name} --outFormat PLINK


    ## If no single stranded genotypes exist, use double stranded library data for genotypes instead.
    elif [[ (${force} == "TRUE" && -f ${seq_batch}/genotyping/pileupcaller.double.geno.txt) || (${seq_batch}/genotyping/pileupcaller.double.geno.txt -nt /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/POSEIDON.yml) ]]; then
        update_switch="on"
        echo -e "${Yellow}DSLib found for ${batch_name}${Normal}"
        ## If the directory already exists, delete it so trident doesn't complain
        if [[ -d "poseidon_packages/${batch_name}" ]]; then
            echo "Deleting existing directory poseidon_packages/${batch_name} to recreate package with new genotypes."
            rm -r /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}
        fi
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
        ## Remove trailing .txt from path names. Needed for loading the data into R with admixr.
        sed -i -e 's/.txt$//' /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/POSEIDON.yml
        rename -e 's/.txt$//' /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/${batch_name}*txt

        ## Also make plink format dataset (needed for READ)
        trident genoconvert -d /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name} --outFormat PLINK

    fi
done

if [[ ${force_update_switch} == "TRUE" || ${update_switch} == "on" ]]; then
    echo -e "${Yellow}Querying pandora for site information${Normal}"
    ## Gather all site ids
    cat /mnt/archgen/MICROSCOPE/poseidon_packages/*/*ind | cut -c1-3 >/mnt/archgen/MICROSCOPE/poseidon_packages/Sites.txt

    ## Construct list of site names, lat and lon from pandora
    Rscript /mnt/archgen/MICROSCOPE/site_ids_to_names.R

    ## Set the population field in fam file to the Site ID
    for fam_f in /mnt/archgen/MICROSCOPE/poseidon_packages/*/*fam; do
        awk -v OFS="\t" -F "\t" '{$1=substr($2,1,3); print $0}' ${fam_f} >${fam_f}.2
        mv ${fam_f} ${fam_f}.old
        mv ${fam_f}.2 ${fam_f}
    done

    ## Set the population field in ind file to the Site ID
    for ind_f in /mnt/archgen/MICROSCOPE/poseidon_packages/*/*ind; do
        awk -v OFS="\t" -F "\t" '{$3=substr($1,1,3); print $0}' ${ind_f} >${ind_f}.2
        mv ${ind_f} ${ind_f}.old
        mv ${ind_f}.2 ${ind_f}

        ## Then update the fam hashes in POSEIDON.yml
        trident update -d $(dirname ${ind_f})
    done

    echo -e "${Yellow}Updating package metadata${Normal}"
    ## Add Site_ID and Site_Name to .janno
    for janno_f in /mnt/archgen/MICROSCOPE/poseidon_packages/*/*.janno; do
        temp_janno="$(dirname ${janno_f})/temp_janno"
        head -n1 ${janno_f} > ${temp_janno}
        tail -n +2 ${janno_f} | awk -F '\t' -v OFS='\t' '{$19=substr($1,1,3); print $0}' >> ${temp_janno}

        temp_site_list="$(dirname ${janno_f})/temp_site_list"
        echo -e "ID\tSite\tLatitude\tLongitude" > ${temp_site_list}
        while read r; do grep $r /mnt/archgen/MICROSCOPE/poseidon_packages/Sites_Info.txt ; done < <(awk '{print $19}' ${temp_janno}) >>${temp_site_list}
        paste ${temp_site_list} ${temp_janno} | awk -F '\t' -v OFS='\t' '{$10=$2; $11=$3; $12=$4; print $0}' | cut -f 5- >${temp_janno}_2
        mv ${janno_f} ${janno_f}.old
        mv ${temp_janno}_2 ${janno_f}
        rm $(dirname ${janno_f})/temp_*
    done
else
    echo "No packages needed updating. Halting execution."
fi
