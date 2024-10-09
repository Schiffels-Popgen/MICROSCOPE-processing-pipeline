#!/usr/bin/env bash

## Function to check that a glob matches exactly one file, which exists.
existsExactlyOne() { [[ $# -eq 1 && -f $1 ]]; }

checkFail() { local message; message=${2}; if [[ ${1} != 0 ]]; then echo -e "${Red}${message}${Normal}"; exit 1; fi }

## Defaults/Hard-codes
##   The destination directory for the poseidon packages is the same as the live directory. They are separated to aid in testing.
destination_package_dir="/mnt/archgen/MICROSCOPE/poseidon_packages_new"
live_package_dir="/mnt/archgen/MICROSCOPE/poseidon_packages"
date_str=$(date +'%Y-%m-%d')

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

mkdir -p ${live_package_dir}
update_switch="off" ## Do any packages need updating? Then update al janno files with information from pandora.
## Colours to make prompts easier to read
Yellow=$(tput sgr0)'\033[1;33m' ## Yellow normal face
Red=$(tput sgr0)'\033[1;31m' ## Red normal face
Green=$(tput sgr0)'\033[1;32m' ## Green normal face
Normal=$(tput sgr0)
processed_batches=''

for seq_batch in $(find /mnt/archgen/MICROSCOPE/eager_outputs/* -maxdepth 0 ! -path "*2021-01-27-Prague_bams"); do
    batch_name=$(basename ${seq_batch})
    ## Find the newest genotype file in the genotyping directory.
    newest_genotype_fn=$(ls -Art -1 /mnt/archgen/MICROSCOPE/eager_outputs/${batch_name}/genotyping/*geno | tail -n 1) ## Reverse order and tail to avoid broken pipe errors
    genotype_files=($(ls -1 /mnt/archgen/MICROSCOPE/eager_outputs/${batch_name}/genotyping/*geno))
    num_genotypes=${#genotype_files[@]}

    if [[ ${force} == "TRUE" || ${newest_genotype_fn} -nt ${destination_package_dir}/${batch_name}/POSEIDON.yml ]]; then
        ## Create temp directory for poseidon package creation
        package_tmpdir=$(mktemp -d /mnt/archgen/MICROSCOPE/.tmp/${batch_name}_XXXXXXXX)
        if [[ ${num_genotypes} -gt 1 ]]; then
            echo -e "${Yellow}[${batch_name}] Multiple genotype files found. Creating a package out of their union. ${Normal}"
            $(dirname $(readlink -f ${0}))/bin/collect_genotypes.py \
                --genoFn1 ${genotype_files[0]} \
                --snpFn1  ${genotype_files[0]%.geno}.snp \
                --indFn1  ${genotype_files[0]%.geno}.ind \
                --genoFn2 ${genotype_files[1]} \
                --snpFn2  ${genotype_files[1]%.geno}.snp \
                --indFn2  ${genotype_files[1]%.geno}.ind \
                --output  ${package_tmpdir}/${batch_name}
        else
            ln -s ${genotype_files[0]}           ${package_tmpdir}/${batch_name}.geno
            ln -s ${genotype_files[0]%.geno}.snp ${package_tmpdir}/${batch_name}.snp
            ln -s ${genotype_files[0]%.geno}.ind ${package_tmpdir}/${batch_name}.ind
        fi

        ## Now that the input genotype files are in the temp directory and with proper naming, run trident init.
        echo -e "${Yellow}[${batch_name}] Initialising poseidon package ${Normal}"
        trident init \
            --inFormat EIGENSTRAT \
            --snpSet 1240K \
            --genoFile ${package_tmpdir}/${batch_name}.geno \
            --snpFile  ${package_tmpdir}/${batch_name}.snp  \
            --indFile  ${package_tmpdir}/${batch_name}.ind  \
            -o ${package_tmpdir}/${batch_name}_unsorted \
            -n ${batch_name}

        checkFail $? "[${batch_name}] Package initialisation failed!"

        ## Set the population field in janno file to the Site ID
        echo -e "${Yellow}[${batch_name}] Updating janno Group_ID from Poseidon_ID ${Normal}"
        janno_f="${package_tmpdir}/${batch_name}_unsorted/${batch_name}.janno"
        head -n1 ${janno_f} >${janno_f}.2
        tail -n +2 ${janno_f} |
            awk -v OFS="\t" -F "\t" '{$3=substr($1,1,3); print $0}' >>${janno_f}.2
        mv ${janno_f}.2 ${janno_f}

        ## Pull Pandora information to the unsorted package.
        ## Now without a library preference (--keep_only) since the output contains both types.
        echo -e "${Yellow}[${batch_name}] Filling-in information from nf-core/eager results ${Normal}"
        eager_result_dir="/mnt/archgen/MICROSCOPE/eager_outputs/${batch_name}"
        ~/anaconda3/envs/MICROSCOPE/lib/R/library/eager2poseidon/exec/eager2poseidon.R \
            --input_janno ${janno_f} \
            --eager_tsv /mnt/archgen/MICROSCOPE/eager_inputs/${batch_name}.eager_input.tsv \
            --general_stats_table ${eager_result_dir}/multiqc/multiqc_data/multiqc_general_stats.txt \
            --credentials ~/Software/github/Schiffels-Popgen/MICROSCOPE-processing-pipeline/.credentials \
            --genotypePloidy haploid \
            --snp_cutoff 100 \
            -S "_ss"
        
        checkFail $? "[${batch_name}] Janno fill-in failed!"

        ## Now that the janno file is filled in, update the ind file to contain the same Sex and Group_Name as the janno file.
        echo -e "${Yellow}[${batch_name}] Mirroring janno information to indFile ${Normal}"
        ind_f="${package_tmpdir}/${batch_name}_unsorted/${batch_name}.ind"
        mv ${ind_f} ${ind_f}.old
        awk -F "\t" -v OFS="\t" '{print $1,$2,$3}' ${janno_f} | tail -n +2 >${ind_f}

        checkFail $? "[${batch_name}] Mirroring of janno information to indFile failed!"

        ## Marking identical twins/duplicate individuals in janno file is not possible with the merging of ssDNA and dsDNA data.
        ##    That is because the annotation TSVs affect the eaget input file, and marking the relationship of a dsDNA individual 
        ##    to an ssDNA individual would result in duplicated input data without merging across them.
        ##    As such, the analysts will be in charge of marking these relationships in the janno file manually, but they will now be kept with each update of the poseidon package.

        ## Validate the package for good measure.
        echo -e "${Yellow}[${batch_name}] Validating poseidon package ${Normal}"
        trident validate -d ${package_tmpdir}/${batch_name}_unsorted
        checkFail $? "[${batch_name}] Post-awk package validation failed!"

        ## Sort the individuals in the package alphabetically
        echo -e "${Yellow}[${batch_name}] Sorting poseidon package ${Normal}"
        awk '{print "<"$1">"}' ${ind_f} | sort >${package_tmpdir}/desiredOrder.txt
        trident forge \
            --outFormat EIGENSTRAT \
            -d ${package_tmpdir}/${batch_name}_unsorted \
            -o ${package_tmpdir}/${batch_name} \
            -n ${batch_name} \
            --forgeFile ${package_tmpdir}/desiredOrder.txt \
            --ordered \
            --preservePyml
        checkFail $? "[${batch_name}] Package sorting failed!"

        ## Convert to plink format
        echo -e "${Yellow}[${batch_name}] Converting poseidon package to plink format ${Normal}"
        trident genoconvert \
            -d ${package_tmpdir}/${batch_name} \
            --outFormat PLINK
        checkFail $? "[${batch_name}] Conversion to plink format failed!"

        ## Pull the live package auxiliary files in, then coalesce etc. To keep any BibTex, CHANGELOG.md or README.md files.
        ##   Pull the packageVersion of the live package (to be bumped later).
        if [[ -f ${live_package_dir}/${batch_name}/POSEIDON.yml ]]; then
            echo -e "${Yellow}[${batch_name}] Pulling live package version info ${Normal}"
            package_ver=$(grep "packageVersion" ${live_package_dir}/${batch_name}/POSEIDON.yml | cut -d':' -f2 | tr -d ' ')
            ## Packages are always created at version 0.1.0
            sed -i -e "s/packageVersion: 0.1.0/packageVersion: ${package_ver}/" ${package_tmpdir}/${batch_name}/POSEIDON.yml
        else
            ## Packages are always created at version 0.1.0
            package_ver="0.1.0"
        fi

        ##   Carry over the Changelog file if it exists.
        if [[ -f ${live_package_dir}/${batch_name}/CHANGELOG.md ]]; then
            echo -e "${Yellow}[${batch_name}] Pulling live package version info ${Normal}"
            cp ${live_package_dir}/${batch_name}/CHANGELOG.md ${package_tmpdir}/${batch_name}/CHANGELOG.md
            echo "changelogFile: CHANGELOG.md" >>${package_tmpdir}/${batch_name}/POSEIDON.yml
        fi

        # ##   Carry over the README file if it exists (not usually the case here).
        # if [[ -f ${live_package_dir}/${batch_name}/README.md ]]; then
        #     cp ${live_package_dir}/${batch_name}/README.md ${package_tmpdir}/${batch_name}/README.md
        #     echo "readmeFile: README.md" >>${package_tmpdir}/${batch_name}/POSEIDON.yml
        # fi

        # ##   Carry over the BibTex file if it exists (not usually the case here).
        # if [[ -f ${live_package_dir}/${batch_name}/${batch_name}.bib ]]; then
        #     cp ${live_package_dir}/${batch_name}/${batch_name}.bib ${package_tmpdir}/${batch_name}/${batch_name}.bib
        #     echo "bibFile: ${batch_name}.bib" >>${package_tmpdir}/${batch_name}/POSEIDON.yml
        # fi

        ## Pull information from the live janno files to the new package.
        ##    This is done to ensure that the janno file contains any information the analysts added manually to the package.
        trident jannocoalesce \
            -s ${live_package_dir}/${batch_name}/${batch_name}.janno \
            -t ${package_tmpdir}/${batch_name}/${batch_name}.janno \
            --includeColumns Alternative_IDs,Relation_To,Relation_Degree,Relation_Type,Relation_Note,Collection_ID,Country,Country_ISO,Date_Type,Date_C14_Labnr,Date_C14_Uncal_BP,Date_C14_Uncal_BP_Err,Date_BC_AD_Start,Date_BC_AD_Median,Date_BC_AD_Stop,Date_Note,MT_Haplogroup,Y_Haplogroup,Source_Tissue,Primary_Contact,Note,Keywords,Publication
        checkFail $? "[${batch_name}] Initial jannocoalesce failed!"

        trident jannocoalesce \
            -s ${live_package_dir}/${batch_name}/${batch_name}.janno \
            -t ${package_tmpdir}/${batch_name}/${batch_name}.janno \
            --force \
            --includeColumns Genetic_Sex,Group_Name
        checkFail $? "[${batch_name}] Additional jannocoalesce failed!"

        ## Validate the package to ensure the filled in janno did not change anything it shouldn't have.
        echo -e "${Yellow}[${batch_name}] Validating final poseidon package ${Normal}"
        trident validate -d ${package_tmpdir}/${batch_name}
        checkFail $? "[${batch_name}] Post-jannocoalesce package validation failed!"

        ## Finally, rectify the package, bump version, and move to the final directory.
        echo -e "${Yellow}[${batch_name}] Rectifying poseidon package ${Normal}"
        trident rectify -d ${package_tmpdir}/${batch_name} \
            --packageVersion Minor \
            --logText "${date_str} Package update" \
            --checksumAll
            # --newContributors "[Thiseas C. Lamnidis](thiseas_christos_lamnidis@eva.mpg.de);[Angela Mötsch](angela_moetsch@eva.mpg.de)"
        checkFail $? "[${batch_name}] Rectifying final package failed!"

        ## Move the package to the live directory (git backed-so ok to remove the current live directory contents).
        echo -e "${Yellow}[${batch_name}] Moving poseidon package to live directory ${Normal}"
        # rm ${live_package_dir}/${batch_name}/*
        mv ${package_tmpdir}/${batch_name} ${destination_package_dir}/${batch_name}/
        checkFail $? "[${batch_name}] Could not move package contents to live directory!"

        ## Validate again for good measure
        echo -e "${Yellow}[${batch_name}] Validating updated poseidon package ${Normal}"
        trident validate -d ${destination_package_dir}/${batch_name}
        checkFail $? "[${batch_name}] Finalised package validation failed!"

        ## Remove the temp directory
        if [[ ! -z ${package_tmpdir} ]]; then
            echo -e "${Yellow}[${batch_name}] Removing temp directory ${Normal}"
            rm -r ${package_tmpdir}/
        fi

        ## Update the processed batches list
        processed_batches="${processed_batches} ${batch_name}@${package_ver}"
        git -C ${destination_package_dir} add ${processed_batch}
        echo -e "${Green}[${batch_name}] Successfully created poseidon package ${Normal}"

    else
        echo -e "${Yellow}[${batch_name}] No new genotyping files found. Skipping package creation. ${Normal}"
    fi
done

if [[ ${processed_batches} != '' ]]; then
    ## Print out the git commands for updating the git of each package.
    echo -e "\nTo update the git repository of poseidon packages, run the following commands:"
    for processed_batch in ${processed_batches}; do
        echo "git -C ${destination_package_dir} commit -m \"${processed_batch/@/-}\""
        echo ""
    done

    ## Print out the batches that got updates for posting on Mattermost
    echo "${date_str} Poseidon package updates:"
    for processed_batch in ${processed_batches}; do
        echo " - \`${processed_batch/@/\`: }"
    done
fi