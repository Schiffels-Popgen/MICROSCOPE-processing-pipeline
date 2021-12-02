# MICROSCOPE-processing-pipeline
Code for the standard data processing pipeline for the ERC project MICROSCOPE

## Available scripts in approximate order of operation
```
.
├── seqIds2Eager2.sh               ## Wrapper that applies query_pandora_for_data.R to each unprocessed sequencing batch
├── query_pandora_for_data.R       ## Queries PANDORA to collect sample, library and sequencing information in an TSV
├── run_Eager.sh                   ## Wrapper that runs/resumes eager for each unprocessed sequencing run
├── MICROSCOPE.config              ## Configuration file for eager runs. contains all parameters for the eager runs
├── create_preliminary_reports.sh  ## Wrapper that knits the preliminary report for each newly processed eager run
├── make_poseidon_packages.sh      ## Makes a poseidon package per batch using info form PANDORA and the batch genotypes
├── site_ids_to_names.R            ## Queries PANDORA for site Ids and names and creates an auxilliary file
├── plink_mds
│   ├── west_eurasian_poplist.txt  ## List of West Eurasian populations for forging the pca package.
│   ├── forge_pca_package.sh       ## Create forge list and forge PCA poseidon package.
│   └── plink_pca.sh               ## Use plink to calculate pairwise distances between all individuals.
├── automated_analysis.nf          ## Nextflow pipeline for each analysis that needs to be ran per batch.
├── create_long_reports.sh         ## Wrapper that knits the extended preliminary report for each newly processed eager run
└── project_reports
    ├── assets
    │   └── bg_annotation.txt      ## Annotation info for west Eurasian bg PCA pops.
    ├── knit_preliminary_report.R  ## Finds the correct input files to knit the preliminary report for a batch
    ├── preliminary_report.Rmd     ## The preliminary report template file
    ├── knit_long_report.R         ## Finds the correct input files to knit the extended preliminary report for a batch
    └── long_report.Rmd            ## The extended preliminary report template file

```

## seqIds2Eager2.sh
Requires no command-line arguments. Will read sequence IDs from each file from the sequencing batch directory and
run `query_pandora_for_data.R` on any batch files that have not yet been process, or have been updated since processing.

#### query_pandora_for_data.R
```
usage: Rscript query_pandora_for_data.R /path/to/input_seq_IDs_file.txt /path/to/pandora/.credentials [-r/--rename].

Options:
	 -r/--rename	Changes all dots (.) in the Library_ID field of the output to underscores (_).
			Some tools used in nf-core/eager will strip everything after the first dot (.)
			from the name of the input file, which can cause naming conflicts in rare cases.

```
Requires the correct `.credentials` file. Option `-r` not provided by `seqIds2Eager2` at present.

## run_Eager.sh
If no output from a completed nf-core/eager run is found for a batch (i.e. a MultiQC report html), runs eager on the batch.
If a run has failed or the eager output predates the creation time of the input TSV (i.e. additional data has become
available for a batch) `run_Eager.sh` will ask the user if it should resume each run in turn. User can reply "Yes to all"
to resume all further failed runs.
```
Output directory for batch <batch_name> already exists, but lacks 'multiqc/multiqc_report.html', or that report is outdated.'
If a nextflow run for that batch did not complete successfully and was killed, I can try to resume that run from where it failed.
Would you like me to try?
            [y]es
            [n]o
            [Y]es to all
```

## create_preliminary_reports.sh
>  ⚠️ For batches that contain genotypes from both ssDNA and dsDNA libraries, the **ssDNA libraries are preferred and dsDNA genotypes
>   are ignored**!

This script will copmare all completed eager runs with all completed reports and create preliminary reports for any eager runs
that are newer than the associated preliminary report or do not have an associated preliminary report.  
Under the hood, this script finds the correct sex determination, snp coverage, and general stats output files from each batch
that requires updating and provides them to `knit_preliminary_report.R`. The `-f` option can be provided to force recreation
of all reports. This is useful in cases where the report template has been updated, so all reports need updating.
```
	 Usage: create_preliminary_reports.sh [-f] 

This script will copmare all completed eager runs with all completed reports and create preliminary reports for any runs that
	are newer than the associated preliminary report or do not have an associated preliminary report.

options:
-h, --help		Print this text and exit.
-f, --force		Force recreation of preliminary reports for all finished eager runs.
```

#### knit_preliminary_report.R
Called by `create_preliminary_reports.sh` under the hood. Knits `preliminary_report.Rmd` with the provided input files. 
```
Usage: ./project_reports/knit_preliminary_report.R -r preliminary_report.Rmd -c .credentials -o output.pdf -s snp_coverage.txt -d sexdet.txt -t stats_table.tsv -b my_batch_name


Options:
	-h, --help
		Show this help message and exit

	-r REPORT_TEMPLATE, --report_template=REPORT_TEMPLATE
		Path to the report template Rmd.

	-c CRED_FILE, --cred_file=CRED_FILE
		The pandora credentials file.

	-o OUTPUT_PDF_NAME, --output_pdf_name=OUTPUT_PDF_NAME
		The name of the output .pdf report.

	-s SNP_COVERAGE_FILE, --snp_coverage_file=SNP_COVERAGE_FILE
		The path to the eigenstrat snp coverage file.

	-d SEX_DET_FILE, --sex_det_file=SEX_DET_FILE
		The path to the sex determination output file.

	-t STATS_TABLE, --stats_table=STATS_TABLE
		The path to the multiqc general stats table file.

	-b BATCH_NAME, --batch_name=BATCH_NAME
		The name of the batch, to be capitalised and used as a subtitle for the report.
```

## make_poseidon_packages.sh
 > ⚠️ This script and its helpers are a work in progress and will eventually be replaced by a script that includes PANDORA queries for information.

Compares the creation time of the genotype dataset in the eager output and the `POSEIDON.yml` of a batch to determine which
poseidon packages need creating/updating. Those pacakges will be recreated from scratch with `trident init`. For batches
that contain genotypes from both ssDNA and dsDNA libraries, the **ssDNA libraries are preferred and dsDNA genotypes are ignored**!
Through under the hood calls to `site_ids_to_names.R`, Site names and IDs are pulled from PANDORA, and added to the package janno file.

## forge_pca_package.sh
Checks if any poseidon packages have been updated since the last forge and reforges the package to include latest genotype data from each batch.
All unique population names from all MICROSCOPE poseidon packages are appended to the populations in `west_eurasian_poplist.txt`, creating a forgelist for use with `trident forge`. The resulting package is always created in `/mnt/archgen/MICROSCOPE/forged_packages/` and is named `microscope_pca`.

## plink_pca.sh
If the `microscope_pca` package has been updated since the last run, runs `plink --indep-pairwise` on the dataset, and saves the resulting distance matrix as `/mnt/archgen/MICROSCOPE/microscope_pca/pairwise_distances.mdist{,.id}`. 

## automated_analysis.nf
> ⚠️ Wrapper still required for this. 

```
$ nextflow run microscope_automated_analysis.nf --help
N E X T F L O W  ~  version 21.04.0
Launching `microscope_automated_analysis.nf` [romantic_tuckerman] - revision: 02cb196e8b

=========================================
microscope_automated_analysis.nf
=========================================
Usage:
The typical command for running the pipeline on sdag is as follows:
nextflow run microscope_automated_analysis.nf -profile eva,archgen --batch <batch_name> --outdir /mnt/archgen/MICROSCOPE/automated_analysis
Mandatory arguments:
    -profile [str]          Institution or personal hardware config to use (e.g. standard, docker, singularity, conda, aws). Ask your system admin if unsure, or check documentation.
    --batch   [str]         The sequencing batch name to process.
    --outdir [str]          The desired directory within which all output files will be placed. One directory per sequencing batch will be created within this directory, which in turn will contain one directory per analysis.

```

Runs standardised analyses per batch. Currently only includes pMMR calculation using `bioconda::pmmrcalculator=1.1.0`

## create_long_reports.sh
>  ⚠️ For batches that contain genotypes from both ssDNA and dsDNA libraries, the **ssDNA libraries are preferred and dsDNA genotypes
>   are ignored**!

This script will copmare all completed eager runs with all completed reports and create extended preliminary reports for any eager runs
that are newer than the associated extended preliminary report or do not have an associated extended preliminary report.  
Under the hood, this script finds the correct sex determination, snp coverage, general stats output files (just like 
`create_preliminary_reports.sh`) and additionally the pMMR table for the batch, the pairwise distance matrix generated by plink, and 
the annotation file for present-day West Eurasian populations, for each batch that requires updating and provides them to 
`knit_long_report.R`. The `-f` option can be provided to force recreation of all reports. This is useful in cases where the report 
template has been updated, so all reports need updating.
```
	 Usage: create_long_reports.sh [-f] 

This script will copmare all completed eager runs with all completed reports and create long reports for any runs that
	are newer than the associated long report or do not have an associated long report.

options:
-h, --help		Print this text and exit.
-f, --force		Force recreation of long reports for all finished eager runs.
```

## knit_long_report.R
Called by `create_long_reports.sh` under the hood. Knits `long_report.Rmd` with the provided input files. 

```
Usage: ./project_reports/knit_long_report.R -r long_report.Rmd -c .credentials -o output.pdf -s snp_coverage.txt -d sexdet.txt -t stats_table.tsv -p pMMR.out.txt -j package.janno -G package.geno -S package.snp -I package.ind -b my_batch_name -a annotation.txt -D distance.mdist -i distance.mdist.id


Options:
	-h, --help
		Show this help message and exit

	-r REPORT_TEMPLATE, --report_template=REPORT_TEMPLATE
		Path to the report template Rmd.

	-c CRED_FILE, --cred_file=CRED_FILE
		The pandora credentials file.

	-o OUTPUT_PDF_NAME, --output_pdf_name=OUTPUT_PDF_NAME
		The name of the output .pdf report.

	-s SNP_COVERAGE_FILE, --snp_coverage_file=SNP_COVERAGE_FILE
		The path to the eigenstrat snp coverage file.

	-d SEX_DET_FILE, --sex_det_file=SEX_DET_FILE
		The path to the sex determination output file.

	-t STATS_TABLE, --stats_table=STATS_TABLE
		The path to the multiqc general stats table file.

	-p PMMR_RESULTS, --pmmr_results=PMMR_RESULTS
		The path to the pMMR results file.

	-j JANNO_FN, --janno_fn=JANNO_FN
		The path to the forged meta-package janno file.

	-G GENOFILE, --GenoFile=GENOFILE
		The path to the package eigenstrat .geno file.

	-S SNPFILE, --SnpFile=SNPFILE
		The path to the package eigenstrat .snp file.

	-I INDFILE, --IndFile=INDFILE
		The path to the package eigenstrat .ind file.

	-b BATCH_NAME, --batch_name=BATCH_NAME
		The name of the batch, to be capitalised and used as a subtitle for the report.

	-a BG_ANNOTATION_FILE, --bg_annotation_file=BG_ANNOTATION_FILE
		The path to the file with the annotation info for the PCA background.

	-D DISTANCE, --distance=DISTANCE
		Path of the plink pairwise distance matrix.

	-i DISTANCE_IDS, --distance_ids=DISTANCE_IDS
		Path of the Ids for the plink pairwise distance matrix.
```

> ⚠️ Currently the `-G`, `-S` and `-I` options are not used within the report, but are implemented for future use.
