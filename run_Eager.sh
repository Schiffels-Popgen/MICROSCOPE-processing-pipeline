#!/usr/bin/env bash

# eager_version='2.2.1' #7971d89e54
eager_version='2.3.5' ## Changed on 05/07/2021

microscope_config='/projects1/MICROSCOPE/MICROSCOPE.config'

## Set profiles based on cluster.
if [[ $(hostname) =~ ^mpi- ]]; then
	nextflow_profiles="shh,singularity,microscope"
elif [[ $(hostname) =~ ^cdag ]]; then
	nextflow_profiles="cdag,shh"
fi

## Set colour and face for colour printing
Red='\033[1;31m'$(tput bold) ## Red bold face
Yellow=$(tput sgr0)'\033[1;33m' ## Yellow normal face

for eager_input in /projects1/MICROSCOPE/eager_inputs/*.eager_input.tsv; do
    ## Set output directory name from eager input name
    eager_output_dir="/projects1/MICROSCOPE/eager_outputs/$(basename ${eager_input} .eager_input.tsv)"
    ## Run name is batch name with dashes replaced with underscores
    # run_name=$(basename ${eager_output_dir//-/_}) ## Eager only allows run names with 1 underscore which makes giving informative run names difficult.
    ## If the eager input is newer than the output directory or the output directory doesnt exist, then eager is run on the input
    if [[ ${eager_input} -nt ${eager_output_dir} ]]; then
        # echo "${eager_input}:    Input is newer"
        echo "Running eager on ${eager_input}:"
        echo "nextflow run nf-core/eager \
            -r ${eager_version} \
            -profile ${nextflow_profiles} \
            -c ${microscope_config} \
            --input ${eager_input} \
            --email ${USER}@shh.mpg.de \
            --outdir ${eager_output_dir} \
            -w ${eager_output_dir}/work \
            -with-tower"

        touch -c ${eager_output_dir} ## Refresh the creation date of the output directory to reflect the start of the new run, but do not create a file if it doesnt exist.
            
            nextflow run nf-core/eager \
                -r ${eager_version} \
                -profile ${nextflow_profiles} \
                -c ${microscope_config} \
                --input ${eager_input} \
                --email ${USER}@shh.mpg.de \
                --outdir ${eager_output_dir} \
                -w ${eager_output_dir}/work \
                -with-tower
            
    ## If the MultiQC report is older than the directory, or doesnt exist yet, try to resume execution. Helpful for runs that failed.
    elif [[ ${eager_output_dir} -nt ${eager_output_dir}/multiqc/multiqc_report.html ]]; then
        if [[ ${user_reply} != "Y" ]]; then 
            unset user_reply
            echo -e "${Yellow}Output directory for batch ${Red}$(basename ${eager_output_dir})${Yellow} already exists, but lacks 'multiqc/multiqc_report.html', or that report is outdated.'$(tput sgr0)" ## '$(tput sgr0) returns to normal printing after the line is done
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
            echo "nextflow run nf-core/eager \
                -r ${eager_version} \
                -profile ${nextflow_profiles} \
                -c ${microscope_config} \
                --input ${eager_input} \
                --email ${USER}@shh.mpg.de \
                --outdir ${eager_output_dir} \
                -w ${eager_output_dir}/work \
                -with-tower \
                -resume"
            
            nextflow run nf-core/eager \
                -r ${eager_version} \
                -profile ${nextflow_profiles} \
                -c ${microscope_config} \
                --input ${eager_input} \
                --email ${USER}@shh.mpg.de \
                --outdir ${eager_output_dir} \
                -w ${eager_output_dir}/work \
                -with-tower \
                -resume
        else
            echo "OK! ${eager_input} was skipped"
        fi
    fi
done

