#!/usr/bin/env nextflow

def helpMessage() {
  log.info"""
  =========================================
  microscope_automated_analysis.nf
  =========================================
  Usage:
  The typical command for running the pipeline on sdag is as follows:
  nextflow run microscope_automated_analysis.nf -c MICROSCOPE.config -profile eva,archgen,automated_analysis --batch <batch_name> --outdir /mnt/archgen/MICROSCOPE/automated_analysis
  Mandatory arguments:
      -profile [str]          Institution or personal hardware config to use (e.g. standard, docker, singularity, conda, aws). Ask your system admin if unsure, or check documentation.
      --batch   [str]         The sequencing batch name to process.
      --outdir [str]          The desired directory within which all output files will be placed. One directory per sequencing batch will be created within this directory, which in turn will contain one directory per analysis.
      --phenotype_annotation [str] The path to the desired SNP annotation file for phenotypic analysis.
  """.stripIndent()
}

nextflow.enable.dsl=1 // Force DSL1 syntax

///////////////////////////////////////////////////////////////////////////////
/* --                SET UP CONFIGURATION VARIABLES                       -- */
///////////////////////////////////////////////////////////////////////////////

// Show help message
params.help = false
if (params.help){
    helpMessage()
    exit 0
}

// Small console separator to make it easier to read errors after launch
println ""

/////////////////////////////////////////////////////////
/* --          Create input channel                 -- */
/////////////////////////////////////////////////////////
Channel.fromPath("/mnt/archgen/MICROSCOPE/poseidon_packages/${params.batch}/*.{geno,snp,ind}")
    .toSortedList()
    .map {
        it -> 
            def geno=it[0]
            def snp=it[2]
            def ind=it[1]
        
        [geno, snp, ind]
        }
    .into { ch_input_for_pmmr; ch_input_dummy }

process pmmrCalculator {
    conda 'bioconda::pmmrcalculator=1.1.0'
    tag "${params.batch}"
    publishDir "${params.outdir}/${params.batch}/pmmr", mode: 'copy'
    memory '1GB'
    cpus 1

    input:
    tuple path(geno), path(snp), path(ind) from ch_input_for_pmmr.dump(tag:"input_pmmr")

    output:
    file "${params.batch}.pmmr.txt"

    script:
    """
    ## Older local fixed version used for testing.
    # /r1/people/thiseas_christos_lamnidis/Software/github/TCLamnidis/pMMRCalculator/pMMRCalculator.py -i ${params.batch} -o ${params.batch}.pmmr.txt
    pmmrcalculator -i ${params.batch} -o ${params.batch}.pmmr.txt
    """
}

process forge_package {
    conda 'bioconda::poseidon-trident=0.26.1'
    memory '1GB'
    cpus 1
    
    // No inputs means this will run each time. forge_pca_package.sh already knows not to run if not needed.
    
    // Dummy output to run this before attempting to run smartpca, which fails the job.
    output:
    val "dummy" into ch_dummy_for_pca_dependency_eurasia,ch_dummy_for_pca_dependency_europe

    script:
    """
    ${projectDir}/plink_mds/forge_pca_package.sh
    """
}

// Create channel with microscope PCA bed/bim/fam for PCA run
Channel.fromPath("/mnt/archgen/MICROSCOPE/forged_packages/microscope_pca/*.{geno,snp,ind}")
    .toSortedList()
    .map {
        it ->
            def geno=it[0]
            def snp=it[2]
            def ind=it[1]

        [geno, snp, ind]
        }
    .into{ ch_for_smartpca_europe; ch_for_smartpca_eurasia }

process microscope_pca_eurasia {
    conda 'bioconda::eigensoft=7.2.1'
    publishDir "/mnt/archgen/MICROSCOPE/automated_analysis/microscope_pca/", mode: 'copy'
    memory '20GB'
    cpus 4

    input:
    tuple path(geno), path(snp), path(ind) from ch_for_smartpca_eurasia.dump(tag:"input_pca_eur")
    val dummy from ch_dummy_for_pca_dependency_eurasia

    output:
    file 'West_Eurasian_pca.evec' optional true
    file 'West_Eurasian_pca.eval' optional true
    file 'West_Eurasian_pca.weights' optional true

    script:
    """
    ${projectDir}/plink_mds/run_smartpca.sh ${geno} ${snp} ${ind} ${projectDir}/plink_mds/west_eurasian_poplist.txt ${task.cpus} West_Eurasian_pca
    """
}

process microscope_pca_europe {
    conda 'bioconda::eigensoft=7.2.1'
    publishDir "/mnt/archgen/MICROSCOPE/automated_analysis/microscope_pca/", mode: 'copy'
    memory '20GB'
    cpus 4

    input:
    tuple path(geno), path(snp), path(ind) from ch_for_smartpca_europe.dump(tag:"input_pca_eur")
    val dummy from ch_dummy_for_pca_dependency_europe

    output:
    file 'Europe_only_pca.eval' optional true
    file 'Europe_only_pca.evec' optional true
    file 'Europe_only_pca.weights' optional true

    script:
    """
    ${projectDir}/plink_mds/run_smartpca.sh ${geno} ${snp} ${ind} ${projectDir}/plink_mds/europe_poplist.txt ${task.cpus} Europe_only_pca
    """
}

Channel.fromPath("/mnt/archgen/MICROSCOPE/poseidon_packages/${params.batch}/*.{bed,bim,fam}")
    .toSortedList()
    .map {
        it -> 
            def bed=it[0]
            def bim=it[2]
            def fam=it[1]
        
        [bed, bim, fam]
        }
    .into { ch_input_for_read; ch_input_dummy }

process kinship_read {
    conda 'conda-forge::python=2.7.15 conda-forge::r-base=4.0.3 bioconda::plink=1.90b6.21'
    tag "${params.batch}"
    publishDir "${params.outdir}/${params.batch}/read", mode: 'copy'
    memory '1GB'
    cpus 1

    input:
    tuple path(bed), path(bim), path(fam) from ch_input_for_read.dump(tag:"input_read")

    output:
    file "${params.batch}.read.txt"
    file "${params.batch}.read.plot.pdf"

    script:
    """
    ## Filter out non-autosomal genotypes, and samples with missingness below about 10k SNPs.
    plink --bfile ${bed.baseName} --make-bed --out ${bed.baseName}.autosomes --autosome --mind 0.9918

    ## Create map file from bim
    ## cut -f 1-4 ${bim.baseName}.autosomes.bim >${bed.baseName}.autosomes.recoded .map

    ## Transpose the plink data
    plink --bfile ${bed.baseName}.autosomes --out ${bed.baseName}.autosomes.recoded --recode  --transpose 

    ## If only one individual is left after filtering, stop execution using the ignored exit code.
    if [[ \$(wc -l ${bed.baseName}.autosomes.recoded.tfam | cut -f1 -d " ") == "1" ]]; then
        exit 11
    fi

    python /r1/people/thiseas_christos_lamnidis/Software/bitbucket/tguenther/read/READ.py ${bed.baseName}.autosomes.recoded

    mv READ_results ${params.batch}.read.txt
    mv READ_results_plot.pdf ${params.batch}.read.plot.pdf
    """
}

// Create channel with all trimmed bams. Will contain duplicates and multiple libraries etc in older batches.
ch_bams_for_phenotypes = Channel
        .fromFilePairs("//mnt/archgen/MICROSCOPE/eager_outputs/${params.batch}/trimmed_bam/*bam{,.bai}")
        //Filter out reaaaally old *.SG1.1 batches. unmerged-trimmed libs that later got merged and trimmed will still exist sadly.
        .filter {! (it[0] =~ /.*1.1.trimmed/) }
        .map{
            sample_name = it[0].minus(".trimmed")
            bam = it [1][0]
            bai = it [1][1]

            [sample_name, bam, bai]
        }
        .dump(tag:"phenotypes")

process phenotypic_analysis {
    tag "${params.batch}"
    conda "bioconda::samtools=1.14"
    publishDir "${params.outdir}/${params.batch}/phenotypes", mode: 'copy'
    memory '1GB'
    cpus 1

    input:
    // Apparently using groupTuple with an out-of-range index flips columns and rows of the channel... :shrug:
    tuple bam_name, path(bams), path(bais) from ch_bams_for_phenotypes.groupTuple(by: [4] ).dump(tag:"phenotypes_input")

    output:
    file("${params.batch}.phenotypes.txt")

    script:
    def name_list = bam_name.flatten().join(" ")
    """
    ## Create samplelist
    for name in ${name_list}; do
        echo \${name} >>samplelist.txt
    done

    ## get mpileup results
    samtools mpileup -a -Q 30 -B -q30 -l <(awk -v OFS="\t" -F "\t" '{print \$3,\$4}' ${params.phenotype_annotation} | tail -n +2) ${bams} >${params.batch}.mpileup.q30.Q30.B.txt

    ## Check phenotypes
    ${baseDir}/phenotypic_snps/infer_phenotypes.py -a${params.phenotype_annotation} -f samplelist.txt ${params.batch}.mpileup.q30.Q30.B.txt >${params.batch}.phenotypes.txt
    """
}