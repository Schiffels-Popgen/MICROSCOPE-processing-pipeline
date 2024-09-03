#!/usr/bin/env bash

## Parse CLI args.
TEMP=`getopt -q -o hd --long help,dry-run -n 'run_Eager.sh' -- "$@"`
eval set -- "$TEMP"

## Helptext function
function Helptext {
    echo -ne "\t Usage: $0 [-d] \n\n"
    echo -ne "Compares the timestamp of the eager input tsv and MultiQC report for a sequencing batch and runs eager if necessary.\n\n"
    echo -ne "options:\n"
    echo -ne "-h, --help\t\tPrint this text and exit.\n"
    echo -ne "-d, --dry-run\t\tOnly print the names of batches that need re-processing. Do not initiate any runs.\n"
}

## Read cli arguments
while true ; do
    case "$1" in
        -d|--dry-run) dry_run="TRUE"; shift 1;;
        -h|--help) Helptext; exit 0 ;;
        --) break;;
        *) echo -e "Invalid option provided.\n"; Helptext; exit 1;; ## Should never trigger since $TEMP has had invalid options removed. Good to have for dev
    esac
done

# eager_version='2.2.1' #7971d89e54
# eager_version='2.3.5' ## Changed on 05/07/2021
# eager_version='2.4.2' ## Changed 01/02/2022. Fixes resource requirement of bedtools coverage.
eager_version='2.4.5' ## Changed 16/08/2022. Fixes endorspy resume issues

microscope_config='/mnt/archgen/MICROSCOPE/MICROSCOPE.config'
barcode_info_fn='/mnt/archgen/MICROSCOPE/batches_with_adapters.tsv'
tower_config='/mnt/archgen/MICROSCOPE/.nextflow_tower'

## If a tower workspace id is provided in .nextflow_tower, use it, else print a warning and continue
if [[ -f ${tower_config} ]]; then
    source ${tower_config}
else
    echo "No nextflow tower config file found. Run information will not be posted to any nextflow tower workspace."
fi

## Set profiles based on cluster.
if [[ $(hostname) =~ ^mpi- ]]; then
    nextflow_profiles="shh,singularity,microscope"
elif [[ $(hostname) =~ ^cdag ]]; then
    nextflow_profiles="cdag,shh,microscope"
elif [[ $(hostname) =~ ^bio ]]; then
    nextflow_profiles="eva,archgen,medium_data,microscope"
fi

## Set colour and face for colour printing
Red='\033[1;31m'$(tput bold) ## Red bold face
Yellow=$(tput sgr0)'\033[1;33m' ## Yellow normal face

for eager_input in /mnt/archgen/MICROSCOPE/eager_inputs/*.eager_input.tsv; do
    ## Go to a stable directory to start working on the run.
    ## This is here to ensure that we cd back to the main directory even when 'continue' breaks the loop execution.
    cd /mnt/archgen/MICROSCOPE

    batch_name=$(basename ${eager_input} .eager_input.tsv)
    ## Set output directory name from eager input name
    eager_output_dir="/mnt/archgen/MICROSCOPE/eager_outputs/${batch_name}"
    ## Run name is batch name with dashes replaced with underscores
    # run_name=$(basename ${eager_output_dir//-/_}) ## Eager only allows run names with 1 underscore which makes giving informative run names difficult.

    ## Check if batch has barcodes and their lengths.
    ##    barcode_rem will be the trim parameter calls for eager if needed, else ''.
    barcode_rem=$( (grep ${batch_name} ${barcode_info_fn} | awk '{print "--run_post_ar_trimming --post_ar_trim_front",$2,"--post_ar_trim_tail",$3}') || echo '' )

    ## To make resuming easier and more stable, cd into the output directory to run the command, then back out.
    cd ${eager_output_dir}

    ## If the eager input is newer than the output directory or the output directory doesnt exist, then eager is run on the input
    if [[ ${eager_input} -nt ${eager_output_dir} ]]; then
        if [[ ${dry_run} == "TRUE" ]]; then
            echo "${batch_name} needs reprocessing."
            continue
        fi
        # echo "${eager_input}:    Input is newer"
        echo "Running eager on ${eager_input}:"
        echo "cd ${eager_output_dir}; nextflow run nf-core/eager \
            -r ${eager_version} \
            -profile ${nextflow_profiles} \
            -c ${microscope_config} \
            --input ${eager_input} \
            --email ${USER}@eva.mpg.de \
            --outdir ${eager_output_dir} \
            -w ${eager_output_dir}/work \
            -dsl1 \
            ${barcode_rem} -with-tower -ansi-log false"

        touch -c ${eager_output_dir} ## Refresh the creation date of the output directory to reflect the start of the new run, but do not create a file if it doesnt exist.
        
        nextflow run nf-core/eager \
            -r ${eager_version} \
            -profile ${nextflow_profiles} \
            -c ${microscope_config} \
            --input ${eager_input} \
            --email ${USER}@eva.mpg.de \
            --outdir ${eager_output_dir} \
            -w ${eager_output_dir}/work \
            -dsl1 \
            ${barcode_rem} -with-tower -ansi-log false
        
    ## If the MultiQC report is older than the directory, or doesnt exist yet, try to resume execution. Helpful for runs that failed.
    elif [[ ${eager_output_dir} -nt ${eager_output_dir}/multiqc/multiqc_report.html ]]; then
        if [[ ${dry_run} == "TRUE" ]]; then
            echo "${batch_name} needs reprocessing."
            continue
        fi
        if [[ ${user_reply} =~ ^(Y|N)$ ]]; then 
            unset user_reply
            echo -e "${Yellow}Output directory for batch ${Red}$(basename ${eager_output_dir})${Yellow} already exists, but lacks 'multiqc/multiqc_report.html', or that report is outdated.$(tput sgr0)" ## '$(tput sgr0) returns to normal printing after the line is done
            echo "If a nextflow run for that batch did not complete successfully and was killed, I can try to resume that run from where it failed."
            echo """Would you like me to try?
            [y]es
            [n]o
            [Y]es to all
            [N]o to all"""
            read user_reply
        fi
        ## Ensure user reply is in expected format. Only "y" or "n" allowed.
        while ! [[ "${user_reply}" =~ ^(y|n|Y|N)$ ]]; do
            echo "Unrecognised input. [y/n/Y/N]"
            read user_reply
        done
        if [[ ${user_reply} =~ ^(y|Y)$ ]]; then
            echo "cd ${eager_output_dir}; nextflow run nf-core/eager \
                -r ${eager_version} \
                -profile ${nextflow_profiles} \
                -c ${microscope_config} \
                --input ${eager_input} \
                --email ${USER}@eva.mpg.de \
                --outdir ${eager_output_dir} \
                -w ${eager_output_dir}/work \
                -dsl1 \
                ${barcode_rem} -with-tower -ansi-log false \
                -resume"
            
            nextflow run nf-core/eager \
                -r ${eager_version} \
                -profile ${nextflow_profiles} \
                -c ${microscope_config} \
                --input ${eager_input} \
                --email ${USER}@eva.mpg.de \
                --outdir ${eager_output_dir} \
                -w ${eager_output_dir}/work \
                -dsl1 \
                ${barcode_rem} -with-tower -ansi-log false \
                -resume
        else
            echo "OK! ${eager_input} was skipped"
        fi

    fi
done

