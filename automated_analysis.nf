#!/usr/bin/env nextflow

def helpMessage() {
  log.info"""
  =========================================
  microscope_automated_analysis.nf
  =========================================
  Usage:
  The typical command for running the pipeline on sdag is as follows:
  nextflow run automated_analysis.nf -profile eva,archgen --batch <batch_name> --outdir /mnt/archgen/MICROSCOPE/automated_analysis
  Mandatory arguments:
      -profile [str]          Institution or personal hardware config to use (e.g. standard, docker, singularity, conda, aws). Ask your system admin if unsure, or check documentation.
      --batch   [str]         The sequencing batch name to process.
      --outdir [str]          The desired directory within which all output files will be placed. One directory per sequencing batch will be created within this directory, which in turn will contain one directory per analysis.
  """.stripIndent()
}

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
println(params)
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
    tuple path(geno), path(snp), path(ind) from ch_input_for_pmmr.dump()

    output:
    file("${params.batch}.pmmr.txt")

    script:
    """
    ## Older local fixed version used for testing.
    # /r1/people/thiseas_christos_lamnidis/Software/github/TCLamnidis/pMMRCalculator/pMMRCalculator.py -i ${params.batch} -o ${params.batch}.pmmr.txt
    pmmrcalculator -i ${params.batch} -o ${params.batch}.pmmr.txt
    """
}

// process background_pca {
//     conda 'bioconda::plink'
//     publishDir "${params.outdir}/assets/background_pca"
//     memory '1GB'
//     cpus 1

//     output:
    

//     script:
//     """
//     plink 
//     """
// }