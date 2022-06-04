#!/usr/bin/env bash

## Parse CLI args.
TEMP=`getopt -q -o hd --long help,dry-run -n 'run_Automated_Analysis.sh' -- "$@"`
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

microscope_config='/mnt/archgen/MICROSCOPE/MICROSCOPE.config'
tower_config='/r1/people/thiseas_christos_lamnidis/Software/github/Schiffels-Popgen/MICROSCOPE-processing-pipeline/.nextflow_tower_automated_analysis'
script_path='/r1/people/thiseas_christos_lamnidis/Software/github/Schiffels-Popgen/MICROSCOPE-processing-pipeline/microscope_automated_analysis.nf'

## If a tower workspace id is provided in .nextflow_tower, use it, else print a warning and continue
if [[ -f ${tower_config} ]]; then
    # echo "Loaded tower config."
    source ${tower_config}
else
    echo "No nextflow tower config file found. Run information will not be posted to any nextflow tower workspace."
fi

## Set profiles based on cluster.
if [[ $(hostname) =~ ^mpi- ]]; then
  nextflow_profiles="shh,singularity,automated_analysis"
elif [[ $(hostname) =~ ^cdag ]]; then
  nextflow_profiles="cdag,shh,automated_analysis"
elif [[ $(hostname) =~ ^bio ]]; then
  nextflow_profiles="eva,archgen,automated_analysis"
fi

## Set colour and face for colour printing
Red='\033[1;31m'$(tput bold) ## Red bold face
Yellow=$(tput sgr0)'\033[1;33m' ## Yellow normal face

for poseidon_input in /mnt/archgen/MICROSCOPE/poseidon_packages/*[!remote]; do
    batch_name=$(basename ${poseidon_input})
    ## Set output directory name from poseidon input name
    automated_analysis_output_dir="/mnt/archgen/MICROSCOPE/automated_analysis/"
    ## Run name is batch name with dashes replaced with underscores
    # run_name=$(basename ${eager_output_dir//-/_}) ## Eager only allows run names with 1 underscore which makes giving informative run names difficult.

    ## If the poseidon input is newer than the output directory or the output directory doesnt exist, then eager is run on the input
    if [[ ${poseidon_input} -nt ${automated_analysis_output_dir}/${batch_name} ]]; then
        if [[ ${dry_run} == "TRUE" ]]; then
            echo "${batch_name} needs processing."
            continue
        fi
        # echo "${eager_input}:    Input is newer"
        echo "Running automated analysis on ${batch_name}:"
        echo "nextflow run ${script_path} \
            -profile ${nextflow_profiles} \
            -c ${microscope_config} \
            --batch ${batch_name} \
            --email ${USER}@eva.mpg.de \
            --outdir ${automated_analysis_output_dir} \
            -w ${automated_analysis_output_dir}/${batch_name}/work \
            -dsl1 \
            -with-tower -ansi-log false"

        touch -c ${automated_analysis_output_dir}/${batch_name} ## Refresh the creation date of the output directory to reflect the start of the new run, but do not create a file if it doesnt exist.
            
            nextflow run ${script_path} \
            -profile ${nextflow_profiles} \
            -c ${microscope_config} \
            --batch ${batch_name} \
            --email ${USER}@eva.mpg.de \
            --outdir ${automated_analysis_output_dir} \
            -w ${automated_analysis_output_dir}/${batch_name}/work \
            -dsl1 \
            -with-tower -ansi-log false
            
    ## If the pipeline output is older than the directory, or doesnt exist yet, try to resume execution. Helpful for runs that failed.
    elif [[ ${automated_analysis_output_dir}/${batch_name} -nt ${automated_analysis_output_dir}/${batch_name}/read/${batch_name}.read.plot.pdf  || ${automated_analysis_output_dir}/${batch_name} -nt ${automated_analysis_output_dir}/${batch_name}/read/${batch_name}.read.txt || ${automated_analysis_output_dir}/${batch_name} -nt ${automated_analysis_output_dir}/${batch_name}/pmmr/${batch_name}.pmmr.txt ]]; then
        if [[ ${dry_run} == "TRUE" ]]; then
            echo "${batch_name} needs reprocessing."
            continue
        fi
        if [[ ${user_reply} != "Y" ]]; then 
            unset user_reply
            echo -e "${Yellow}Output directory for batch ${Red}${batch_name}${Yellow} already exists, but some of the output files are outdated.$(tput sgr0)" ## '$(tput sgr0) returns to normal printing after the line is done
            echo "If a nextflow run for that batch did not complete successfully and was killed, I can try to resume that run from where it failed."
            echo """Would you like me to try?
            [y]es
            [n]o
            [Y]es to all"""
            read user_reply
        fi
        ## Ensure user reply is in expected format. Only "y" or "n" allowed.
        while ! [[ "${user_reply}" =~ ^(y|n|Y)$ ]]; do
            echo "Unrecognised input. [y/n/Y]"
            read user_reply
        done
        if [[ ${user_reply} =~ ^(y|Y)$ ]]; then
            echo "nextflow run ${script_path} \
                -profile ${nextflow_profiles} \
                -c ${microscope_config} \
                --batch ${batch_name} \
                --email ${USER}@eva.mpg.de \
                --outdir ${automated_analysis_output_dir} \
                -w ${automated_analysis_output_dir}/${batch_name}/work \
                -dsl1 \
                -with-tower -ansi-log false \
                -resume"
            
            nextflow run ${script_path} \
                -profile ${nextflow_profiles} \
                -c ${microscope_config} \
                --batch ${batch_name} \
                --email ${USER}@eva.mpg.de \
                --outdir ${automated_analysis_output_dir} \
                -w ${automated_analysis_output_dir}/${batch_name}/work \
                -dsl1 \
                -with-tower -ansi-log false \
                -resume
        else
            echo "OK! ${batch_name} was skipped"
        fi
    fi
done

