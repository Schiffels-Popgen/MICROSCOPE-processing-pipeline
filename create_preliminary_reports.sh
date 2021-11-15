#!/usr/bin/env bash

## Parse CLI args.
TEMP=`getopt -q -o hf --long help,force -n 'create_preliminary_reports.sh' -- "$@"`
eval set -- "$TEMP"

## Helptext function
function Helptext {
    echo -ne "\t Usage: create_preliminary_reports.sh [-f] \n\n"
    echo -ne "This script will copmare all completed eager runs with all completed reports and create preliminary reports for any runs that\n\tare newer than the associated preliminary report or do not have an associated preliminary report.\n\n"
    echo -ne "options:\n"
    echo -ne "-h, --help\t\tPrint this text and exit.\n"
    echo -ne "-f, --force\t\tForce recreation of preliminary reports for all finished eager runs.\n"
}

force_remake="FALSE"

while true ; do
    case "$1" in
        -f|--force) force_remake="TRUE"; shift 1;;
        -h|--help) Helptext; exit 0 ;;
        --) break;;
        *) echo -e "Invalid option provided.\n"; Helptext; exit 1;; ## Should never trigger since $TEMP has had invalid options removed. Good to have for dev
    esac
done

report_knitter="/home/thiseas_christos_lamnidis/Software/github/Schiffels-Popgen/MICROSCOPE-processing-pipeline/project_reports/knit_preliminary_report.R"
report_template="/r1/people/thiseas_christos_lamnidis/Software/github/Schiffels-Popgen/MICROSCOPE-processing-pipeline/project_reports/preliminary_report.Rmd"
cred_file="~/Software/github/Schiffels-Popgen/MICROSCOPE-processing-pipeline/.eva_credentials"
preliminary_report_dir="/mnt/archgen/MICROSCOPE/reports"

## Get list of completed runs (MQC report exists)
eager_out_dir="/mnt/archgen/MICROSCOPE/eager_outputs"
finished_runs=($(find ${eager_out_dir}/*/multiqc -name 'multiqc_report.html'))

## Create array of expected report names with the same index/order as the finished runs.
for run in ${finished_runs[@]}; do
    batch_Id=$(echo ${run} | rev | cut -f 3 -d '/' | rev)
    batch_name=$(echo ${batch_Id} | rev | cut -f 1 -d '-' |rev)
    expected_outputs+=("${preliminary_report_dir}/${batch_Id}/${batch_name}_preliminary_report.pdf")
done

## DEBUG
# echo ${#finished_runs[@]}
# echo ${#expected_outputs[@]}

## If multiqc is newer than the report, or the report does not exist, generate the report.
for idx in ${!finished_runs[@]}; do
    batch_Id=$(echo ${finished_runs[${idx}]} | rev | cut -f 3 -d '/' | rev)
    batch_name=$(echo ${batch_Id} | rev | cut -f1 -d "-" | rev)
    if [[ ${force_remake} == "TRUE" || ${finished_runs[${idx}]} -nt ${expected_outputs[${idx}]} ]]; then
        ## Infer filepaths for snp_coverage, sex det results and general stats table
        ##  When multiple snp coverage files exist (ssDNA + dsDNA) they get sorted alphabetically.
        ##  Take the last by index to prefer ssDNA when multiple files exist (Same as poseidon package creation).
        snp_fns=($(find ${eager_out_dir}/${batch_Id}/genotyping/ -name '*_eigenstrat_coverage.txt' ))
        snp_coverage_file="${snp_fns[-1]}"
        ## Sexdet output has stable path
        sex_det_file="${eager_out_dir}/${batch_Id}/sex_determination/SexDet.txt"
        ## General stats table has stable path
        stats_table="$(dirname ${finished_runs[${idx}]})/multiqc_data/multiqc_general_stats.txt"
        echo "Creating preliminary report for ${batch_Id} -> ${expected_outputs[${idx}]}"
        ${report_knitter} \
            --report_template ${report_template} \
            --snp_coverage_file ${snp_coverage_file} \
            --sex_det_file ${sex_det_file} \
            --stats_table ${stats_table} \
            --batch_name ${batch_name} \
            --cred_file ${cred_file} \
            --output_pdf_name ${expected_outputs[${idx}]}
    fi
done
