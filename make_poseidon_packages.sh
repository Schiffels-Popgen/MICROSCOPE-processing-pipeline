#!/usr/bin/env bash

## Function to check that a glob matches exactly one file, which exists.
existsExactlyOne() { [[ $# -eq 1 && -f $1 ]]; }

## Read in -f positional argument
force='FALSE'
force_update_switch='FALSE'
if [[ $1 == "-f" ]]; then
    force="TRUE"
fi
if [[ $1 == "-u" ]]; then
    force_update_switch="TRUE"
    shift
    update_batches="$*" ## Update jannos for all batches given after flag.
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
        update_batches+="${batch_name} " ## add batch to janno update list
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
        rename -f -e ${regex} /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/pileupcaller.*.txt
        ## Remove trailing .txt from path names. Needed for loading the data into R with admixr.
        sed -i -e 's/.txt$//' /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/POSEIDON.yml
        rename -f -e 's/.txt$//' /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/${batch_name}*txt

        ## Also make plink format dataset (needed for READ)
        trident genoconvert -d /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name} --outFormat PLINK


    ## If no single stranded genotypes exist, use double stranded library data for genotypes instead.
    elif [[ (${force} == "TRUE" && -f ${seq_batch}/genotyping/pileupcaller.double.geno.txt) || (${seq_batch}/genotyping/pileupcaller.double.geno.txt -nt /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/POSEIDON.yml) ]]; then
        update_switch="on"
        update_batches+="${batch_name} " ## add batch to janno update list
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
        rename -f -e ${regex} /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/pileupcaller.*.txt
        ## Remove trailing .txt from path names. Needed for loading the data into R with admixr.
        sed -i -e 's/.txt$//' /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/POSEIDON.yml
        rename -f -e 's/.txt$//' /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/${batch_name}*txt

        ## Also make plink format dataset (needed for READ)
        trident genoconvert -d /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name} --outFormat PLINK

    fi
done

if [[ ${force_update_switch} == "TRUE" || ${update_switch} == "on" ]]; then

    for batch in ${update_batches}; do
        ## Set the population field in fam file to the Site ID
        echo -e "${Yellow}${batch}:  Setting Population name in .fam and .ind files to Pandora Site_Id.${Normal}"
        fam_f="/mnt/archgen/MICROSCOPE/poseidon_packages/${batch}/${batch}.fam"
        awk -v OFS="\t" -F "\t" '{$1=substr($2,1,3); print $0}' ${fam_f} >${fam_f}.2
        # mv ${fam_f} ${fam_f}.old
        mv ${fam_f}.2 ${fam_f}


        ## Set the population field in ind file to the Site ID
        ind_f="/mnt/archgen/MICROSCOPE/poseidon_packages/${batch}/${batch}.ind"
        awk -v OFS="\t" -F "\t" '{$3=substr($1,1,3); print $0}' ${ind_f} >${ind_f}.2
        # mv ${ind_f} ${ind_f}.old
        mv ${ind_f}.2 ${ind_f}

        ## Add Site_ID and Site_Name to .janno
        echo -e "${Yellow}${batch}:  Updating package metadata using eager2poseidon${Normal}"
        janno_f="/mnt/archgen/MICROSCOPE/poseidon_packages/${batch}/${batch}.janno"
        ## Make Group_Name of janno be the Site_ID from pandora, to match fam and ind files.
        temp_janno="$(dirname ${janno_f})/temp_janno.janno"
        head -n1 ${janno_f} > ${temp_janno}
        ## Group_Name is column 3 in poseidon 2.5.0 packages made with trident 0.26.1 +. Used to be column 19 in the past.
        tail -n +2 ${janno_f} | awk -F '\t' -v OFS='\t' '{$3=substr($1,1,3); print $0}' >> ${temp_janno}

        eager_result_dir="/mnt/archgen/MICROSCOPE/eager_outputs/${batch}"
        ## Keep only ssDNA data when ssDNA data is available
        ## If one and only one file matching *single*geno* exists in the genotyping dir of the eager output for the batch, then prefer single stranded data.
        if existsExactlyOne ${eager_result_dir}/genotyping/*single*geno*; then
            library_preference='single'
        else
            library_preference='double'
        fi

        ## Run eager2poseidon
        echo "~/Software/github/sidora-tools/eager2poseidon/exec/eager2poseidon.R \
            --input_janno ${temp_janno} \
            --eager_tsv /mnt/archgen/MICROSCOPE/eager_inputs/${batch}.eager_input.tsv \
            --general_stats_table ${eager_result_dir}/multiqc/multiqc_data/multiqc_general_stats.txt \
            --credentials ~/Software/github/Schiffels-Popgen/MICROSCOPE-processing-pipeline/.credentials \
            --genotypePloidy haploid \
            --snp_cutoff 100 \
            --keep_only ${library_preference}" | tr -s " "
        
        ~/Software/github/sidora-tools/eager2poseidon/exec/eager2poseidon.R \
            --input_janno ${temp_janno} \
            --eager_tsv /mnt/archgen/MICROSCOPE/eager_inputs/${batch}.eager_input.tsv \
            --general_stats_table ${eager_result_dir}/multiqc/multiqc_data/multiqc_general_stats.txt \
            --credentials ~/Software/github/Schiffels-Popgen/MICROSCOPE-processing-pipeline/.credentials \
            --genotypePloidy haploid \
            --snp_cutoff 100 \
            --keep_only ${library_preference}
        
        ## Keep original janno just as backup.
        mv ${janno_f} ${janno_f}.old
        mv ${temp_janno} ${janno_f}

        echo -e "${Yellow}${batch}:  Adding genetic sex to fam and ind files ${Normal}"
        ## Update genetic sex in .fam file based on sexes in janno file
        mv ${fam_f} ${fam_f}.old ## Keep old fam file around for testing
        ## First paste together the fam and janno files, throw away the header line, then use awk to update the sex in the fam file based on the janno file
        ## Results are saved to ${fam_f}
        (echo ""; cat ${fam_f}.old) | \
            paste - <( awk -F "\t" -v OFS="\t" '{print $1,$2,$3}' ${janno_f}) | \
            tail -n +2 | \
            awk -F "\t" -v OFS="\t" '{ 
                if ($8 == "M") {
                    $5=1
                } else if ($8 == "F") {
                    $5=2
                }; print $1, $2, $3, $4, $5, $6}' > ${fam_f}

        ## Update genetic sex in .ind files
        mv ${ind_f} ${ind_f}.old
        awk -F "\t" -v OFS="\t" '{print $1,$2,$3}' ${janno_f} | tail -n +2 >${ind_f}

        echo -e "${Yellow}${batch}:  Updating POSEIDON.yml hashes ${Normal}"
        ## Then update the hashes in POSEIDON.yml
        trident update -d $(dirname ${ind_f})

        echo -e "${Yellow}${batch}:  Package '${batch}' processed.${Normal}"
    done
else
    echo "No packages needed updating. Halting execution."
fi
