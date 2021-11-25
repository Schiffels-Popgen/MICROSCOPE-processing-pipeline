#!/usr/bin/env bash
poseidon_dir="/mnt/archgen/MICROSCOPE/poseidon_packages"
forge_dir="/mnt/archgen/MICROSCOPE/forged_packages/"
package_dir="${forge_dir}/microscope_pca/"
we_poplist='/home/thiseas_christos_lamnidis/Software/github/Schiffels-Popgen/MICROSCOPE-processing-pipeline/plink_mds/west_eurasian_poplist.txt'
pca_dir="/mnt/archgen/MICROSCOPE/microscope_pca"

## Do not remake the package if it does not need updating
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

if [[ ${newest_janno} -nt /mnt/archgen/MICROSCOPE/forged_packages/microscope_pca/microscope_pca.bed ]]; then
    ## Remove the package if it already exists
    rm -r  /mnt/archgen/MICROSCOPE/forged_packages/microscope_pca/

    ## Create package directory and create a forgelist including all West Eurasian populations
    # mkdir -p ${package_dir}
    cat ${we_poplist} > ${forge_dir}/forgelist.txt

    for janno in ${poseidon_dir}/*/*.janno; do
        ## Add list of unique group IDs from each janno to the forgelist
        tail -n +2 ${janno} | awk -F "\t" -v OFS='\t' '{print $19}' | sort -u >> ${forge_dir}/forgelist.txt
    done

    trident forge --forgeFile ${forge_dir}/forgelist.txt -d ${poseidon_dir} -o ${package_dir} -n microscope_pca
else
    echo "No changes in any janno files since the 'microscope_pca' package was created."
    echo "Halting execution."
    exit 0
fi
