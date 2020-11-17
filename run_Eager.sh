#!/usr/bin/env bash

eager_version='2.2.1' #7971d89e54

microscope_config='/projects1/MICROSCOPE/MICROSCOPE.config'

## Set profiles based on cluster.
if [[ $(hostname) =~ ^mpi- ]]; then
	nextflow_profiles="shh,sdag"
elif [[ $(hostname) =~ ^cdag ]]; then
	nextflow_profiles="shh,cdag"
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
            -r  \
            -profile ${nextflow_profiles} \
            -c ${microscope_config} \
            --input ${eager_input} \
            --email ${USER}@shh.mpg.de \
            --outdir ${eager_output_dir} \
            -w ${eager_output_dir}/work \
            #-name ${run_name}"

            nextflow run nf-core/eager \
                -r ${eager_version} \
                -profile ${nextflow_profiles} \
                -c ${microscope_config} \
                --input ${eager_input} \
                --email ${USER}@shh.mpg.de \
                --outdir ${eager_output_dir} \
                -w ${eager_output_dir}/work \
                #-name ${run_name}

    ## If the directory exists but lacks a MultiQC ask to attempt to resume execution. Helpful if a run failed.
    elif [[ ! -f ${eager_output_dir}/multiqc/multiqc_report.html ]]; then
        unset user_reply
        echo -e "${Yellow}Output directory for batch ${Red}$(basename ${eager_output_dir})${Yellow} already exists, but lacks 'MultiQC/multiqc_report.html'.'$(tput sgr0)" ## '$(tput sgr0) returns to normal printing after the line is done
        echo "If a nextflow run for that batch did not complete successfully and was killed, I can try to resume that run from where it failed."
        echo "Would you like me to try? [y/n]"
        read user_reply
        ## Ensure user reply is in expected format. Only "y" or "n" allowed.
        while ! [[ "${user_reply}" =~ ^(y|n)$ ]]; do
            echo "Unrecognised input. [y/n]"
            read user_reply
        done
        if [[ ${user_reply} == "y" ]]; then
            echo "nextflow run nf-core/eager \
                -r ${eager_version} \
                -profile shh,sdag \
                -c ${microscope_config} \
                --input ${eager_input} \
                --email ${USER}@shh.mpg.de \
                --outdir ${eager_output_dir} \
                -w ${eager_output_dir}/work \
                #-name ${run_name} \
                -resume"
            
            nextflow run nf-core/eager \
                -r ${eager_version} \
                -profile shh,sdag \
                -c ${microscope_config} \
                --input ${eager_input} \
                --email ${USER}@shh.mpg.de \
                --outdir ${eager_output_dir} \
                -w ${eager_output_dir}/work \
                #-name ${run_name} \
                -resume
        else
            echo "OK! ${eager_input} was skipped"
        fi
    fi
done

