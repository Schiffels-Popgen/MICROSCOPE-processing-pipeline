#!/usr/bin/env bash

## Parse CLI args.
TEMP=`getopt -q -o hf --long help,force -n 'forge_pca_package.sh' -- "$@"`
eval set -- "$TEMP"

## Helptext function
function Helptext {
    echo -ne "\t Usage: $0 [-f] \n\n"
    echo -ne "This script will forge the 'microscope_pca' package, which includes a set of West Eurasian populations as well as all microscope batches for which poseidon packages exist.\n\n"
    echo -ne "options:\n"
    echo -ne "-h, --help\t\tPrint this text and exit.\n"
    echo -ne "-f, --force\t\tForce recreation of long reports for all finished eager runs.\n"
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

poseidon_dir="/mnt/archgen/MICROSCOPE/poseidon_packages"
forge_dir="/mnt/archgen/MICROSCOPE/forged_packages/"
package_dir="${forge_dir}/microscope_pca/"
we_poplist='/home/thiseas_christos_lamnidis/Software/github/Schiffels-Popgen/MICROSCOPE-processing-pipeline/plink_mds/west_eurasian_poplist.txt'
pca_dir="/mnt/archgen/MICROSCOPE/microscope_pca"
trident_path="/home/thiseas_christos_lamnidis/anaconda3/envs/MICROSCOPE/bin/trident"

## Do not remake the package if it does not need updating, unless forced to with -f.
jannos=(${poseidon_dir}/*/*.janno)
newest_janno=${jannos[0]}
## Find the newest janno file to compare package to
for idx in ${!jannos[@]}; do 
    if [[ ${idx} == 0 ]]; then
        newest_janno=${jannos[${idx}]}
    elif [[ ${jannos[${idx}]} -nt ${newest_janno} ]]; then
        newest_janno=${jannos[${idx}]}
    fi
done

if [[ ${force_remake} == "TRUE" || ${newest_janno} -nt /mnt/archgen/MICROSCOPE/forged_packages/microscope_pca/microscope_pca.bed ]]; then
    ## Remove the package if it already exists
    rm -r  /mnt/archgen/MICROSCOPE/forged_packages/microscope_pca/

    ## Create package directory and create a forgelist including all West Eurasian populations
    # mkdir -p ${package_dir}
    cat ${we_poplist} > ${forge_dir}/forgelist.txt

    for janno in ${poseidon_dir}/*/*.janno; do
        ## Add list of unique group IDs from each janno to the forgelist
        tail -n +2 ${janno} | awk -F "\t" -v OFS='\t' '{print $3}' | sort -u >> ${forge_dir}/forgelist.txt
    done

    ${trident_path} forge --forgeFile ${forge_dir}/forgelist.txt -d ${poseidon_dir} -o ${package_dir} -n microscope_pca --intersect --eigenstrat
    ${trident_path} genoconvert -d ${package_dir} --outFormat PLINK
else
    echo "No changes in any janno files since the 'microscope_pca' package was created."
    echo "Halting execution."
    exit 0
fi
