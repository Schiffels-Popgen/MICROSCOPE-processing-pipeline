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
processed_batches=''

for seq_batch in $(find /mnt/archgen/MICROSCOPE/eager_outputs/* -maxdepth 0 ! -path "*2021-01-27-Prague_bams"); do
    batch_name=$(basename ${seq_batch})
    ## Prefer single stranded to double stranded library data for genotypes.
    if [[ (${force} == "TRUE" && -f ${seq_batch}/genotyping/pileupcaller.single.geno) || (${seq_batch}/genotyping/pileupcaller.single.geno -nt /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/POSEIDON.yml) ]]; then
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
            --genoFile /mnt/archgen/MICROSCOPE/eager_outputs/${batch_name}/genotyping/pileupcaller.single.geno \
            --snpFile /mnt/archgen/MICROSCOPE/eager_outputs/${batch_name}/genotyping/pileupcaller.single.snp \
            --indFile /mnt/archgen/MICROSCOPE/eager_outputs/${batch_name}/genotyping/pileupcaller.single.ind \
            -o /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name} \
            -n ${batch_name}

        sed -i -e ${regex} /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/POSEIDON.yml
        rename -f -e ${regex} /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/pileupcaller.*
        ## Remove trailing .txt from path names. Needed for loading the data into R with admixr.
        sed -i -e 's/.txt$//' /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/POSEIDON.yml
        rename -f -e 's/.txt$//' /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/${batch_name}*txt

        ## Also make plink format dataset (needed for READ)
        trident genoconvert -d /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name} --outFormat PLINK
        processed_batches+="${batch_name} "


    ## If no single stranded genotypes exist, use double stranded library data for genotypes instead.
    elif [[ (${force} == "TRUE" && -f ${seq_batch}/genotyping/pileupcaller.double.geno) || (${seq_batch}/genotyping/pileupcaller.double.geno -nt /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/POSEIDON.yml) ]]; then
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
            --genoFile /mnt/archgen/MICROSCOPE/eager_outputs/${batch_name}/genotyping/pileupcaller.double.geno \
            --snpFile /mnt/archgen/MICROSCOPE/eager_outputs/${batch_name}/genotyping/pileupcaller.double.snp \
            --indFile /mnt/archgen/MICROSCOPE/eager_outputs/${batch_name}/genotyping/pileupcaller.double.ind \
            -o /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name} \
            -n ${batch_name}

        sed -i -e ${regex} /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/POSEIDON.yml
        rename -f -e ${regex} /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/pileupcaller.*
        ## Remove trailing .txt from path names. Needed for loading the data into R with admixr.
        ## DEPRECATED 01/11/2022. Update of eager to v 2.4.5 means pileupcaller output no longer has txt suffix
        # sed -i -e 's/.txt$//' /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/POSEIDON.yml
        # rename -f -e 's/.txt$//' /mnt/archgen/MICROSCOPE/poseidon_packages/${batch_name}/${batch_name}*txt

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
            ss_suffix='-S _ss'
        else
            library_preference='double'
            ss_suffix=''
        fi

        ## Run eager2poseidon
        ##  Requires poseidonR from this version. Newer version clashes with something ##  remotes::install_github('poseidon-framework/poseidonR', ref='99f1e9c9954d9b7e79e796c24e90036f2576a112')
        ## TODO: Fix eager2poseidon so it keeps additional columns found in the input janno >:(

        echo "~/Software/github/sidora-tools/eager2poseidon/exec/eager2poseidon.R \
            --input_janno ${temp_janno} \
            --eager_tsv /mnt/archgen/MICROSCOPE/eager_inputs/${batch}.eager_input.tsv \
            --general_stats_table ${eager_result_dir}/multiqc/multiqc_data/multiqc_general_stats.txt \
            --credentials ~/Software/github/Schiffels-Popgen/MICROSCOPE-processing-pipeline/.credentials \
            --genotypePloidy haploid \
            --snp_cutoff 100 \
            --keep_only ${library_preference}" \
            ${ss_suffix} | tr -s " "
        
        ~/Software/github/sidora-tools/eager2poseidon/exec/eager2poseidon.R \
            --input_janno ${temp_janno} \
            --eager_tsv /mnt/archgen/MICROSCOPE/eager_inputs/${batch}.eager_input.tsv \
            --general_stats_table ${eager_result_dir}/multiqc/multiqc_data/multiqc_general_stats.txt \
            --credentials ~/Software/github/Schiffels-Popgen/MICROSCOPE-processing-pipeline/.credentials \
            --genotypePloidy haploid \
            --snp_cutoff 100 \
            --keep_only ${library_preference}\
            ${ss_suffix}
        
        ## Keep original janno just as backup.
        mv ${janno_f} ${janno_f}.old
        mv ${temp_janno} ${janno_f}

        ## If an identical twin annotation file exists for the batch, then update the Alternative_ID field of the `into_this` individual in the janno file to denote it contains data for both Pandora IDs,
        ##   and rename the population field of the merge_this individual so the data is not in the population twice.
        if [[ -f /mnt/archgen/MICROSCOPE/identical_twins_per_batch/${batch}.identical_twins.tsv ]]; then
            echo -e "${Yellow}${batch}:  Marking identical twins/duplicate individuals in janno file ${Normal}"

            ## Infer the index of the Group_Name and Alternative_ID columns in the janno file
            group_name_col=$(head -n1 ${janno_f} | tr '\t' '\n' | grep -n 'Group_Name' | cut -d':' -f1)
            alt_id_col=$(head -n1 ${janno_f} | tr '\t' '\n' | grep -n 'Alternative_IDs' | cut -d':' -f1)
            note_field_col=$(head -n1 ${janno_f} | tr '\t' '\n' | grep -wn 'Note' | cut -d':' -f1)
            relation_to_col=$(head -n1 ${janno_f} | tr '\t' '\n' | grep -wn 'Relation_To' | cut -d':' -f1)
            relation_degree_col=$(head -n1 ${janno_f} | tr '\t' '\n' | grep -wn 'Relation_Degree' | cut -d':' -f1)
            relation_note_col=$(head -n1 ${janno_f} | tr '\t' '\n' | grep -wn 'Relation_Note' | cut -d':' -f1)

            merge_these=()
            into_these=()

            while read -r merge_this into_this; do
                ## Skip header
                if [[ ${merge_this} == "merge_this" ]]; then
                    continue
                fi
                ## Create bash array with all entries in the merge_this and into_this columns
                merge_these+=("${merge_this}")
                into_these+=("${into_this}")
            done < /mnt/archgen/MICROSCOPE/identical_twins_per_batch/${batch}.identical_twins.tsv

            ## Pass the full arrays to awk and update the janno file
            ## WARNING This awk command will not pick up on triplets of identical individuals. one individual will be lost in the Janno.
            awk \
                -v group_name_col="${group_name_col}" \
                -v alt_id_col="${alt_id_col}" \
                -v merge_these="${merge_these[*]}" \
                -v into_these="${into_these[*]}" \
                -v note_field_col="${note_field_col}" \
                -v relation_to_col="${relation_to_col}" \
                -v relation_degree_col="${relation_degree_col}" \
                -v relation_note_col="${relation_note_col}" \
                -v n="${#merge_these[@]}"\
                -F "\t" \
                -v OFS="\t" \
                '
                    BEGIN{
                        split(merge_these,a," ")
                        split(into_these ,b," ")
                        for (x=1;x<=n;++x) { 
                            tsv_merge_this[a[x]]=a[x]
                            tsv_into_this[b[x]]=b[x]
                            merged_into[a[x]]=b[x]
                            merged_from[b[x]]=a[x]
                            }

                        }
                    ## With identical indivs TSV looking like this:
                    ## merge_this into this
                    ## ABC001   ABC002
                    ## 
                    ## tsv_merge_this = ["ABC001" : "ABC001" ]
                    ## tsv_into_this  = ["ABC002" : "ABC002" ]
                    ## merged_into    = ["ABC001" : "ABC002" ]
                    ## merged_from    = ["ABC002" : "ABC001" ]

                    { 
                        if ( $1 in tsv_merge_this ) { 
                            $group_name_col = $group_name_col"_data_merged_into_"merged_into[$1]
                            $relation_to_col = merged_into[$1]
                            $relation_degree_col = "identical"
                            $relation_note_col = "Identity of individuals was specified in identical_twins annotation file."
                        } else if ( $1 in tsv_into_this ) {
                            $alt_id_col = $1"_"merged_from[$1]"_merged"
                            $note_field_col = "This Poseidon_ID contains the merged data from identical individuals "$1" and "merged_from[$1]"."
                            $relation_to_col = merged_from[$1]
                            $relation_degree_col = "identical"
                            $relation_note_col = "Identity of individuals was specified in identical_twins annotation file."

                        }
                        print $0 
                    }
                ' ${janno_f} > ${janno_f}.2
            
            ## Replace origianl janno file with updated version
            mv ${janno_f}.2 ${janno_f}
        fi

        echo -e "${Yellow}${batch}:  Adding genetic sex to fam and ind files ${Normal}"
        ## Update genetic sex in .fam file based on sexes in janno file
        mv ${fam_f} ${fam_f}.old ## Keep old fam file around for testing
        ## First paste together the fam and janno files, throw away the header line, then use awk to update the sex in the fam file based on the janno file
        ## Additionally, replace the group name in the fam file ($1) with the new Group_Name in the janno file ($9)
        ## Results are saved to ${fam_f}
        (echo ""; cat ${fam_f}.old) | \
            paste - <( awk -F "\t" -v OFS="\t" '{print $1,$2,$3}' ${janno_f}) | \
            tail -n +2 | \
            awk -F "\t" -v OFS="\t" '{ 
                if ($8 == "M") {
                    $5=1
                } else if ($8 == "F") {
                    $5=2
                }; print $9, $2, $3, $4, $5, $6}' > ${fam_f}

        ## Update genetic sex and group name in .ind files
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

## Print out the batches that got updates for posting on Mattermost
if [[ ${processed_batches} != '' ]]; then
    echo "$(date -Idate) Poseidon package updates:"
fi
for processed_batch in ${processed_batches}; do
    echo " - \`${processed_batch}\`"
done
