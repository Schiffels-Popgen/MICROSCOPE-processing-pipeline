# MICROSCOPE-processing-pipeline
Code for the standard data processing pipeline for the ERC project MICROSCOPE

## Available scripts in order of operation
```
.
├── seqIds2Eager2.sh               ## Wrapper that applies query_pandora_for_data.R to each unprocessed sequencing batch
├── query_pandora_for_data.R       ## Queries PANDORA to collect sample, library and sequencing information in an TSV
├── run_Eager.sh                   ## Wrapper that runs/resumes eager for each unprocessed sequencing run
├── MICROSCOPE.config              ## Configuration file for eager runs. contains all parameters for the eager runs
├── create_preliminary_reports.sh  ## Wrapper that knits the preliminary report for each newly processed eager run
├── project_reports
│   ├── knit_preliminary_report.R  ## Finds the correct input files to knit the preliminary report for a batch
│   └── preliminary_report.Rmd     ## The preliminary report templeate file
├── make_poseidon_packages.sh      ## Makes a poseidon package per batch using info form PANDORA and the batch genotypes
└── site_ids_to_names.R            ## Queries PANDORA for site Ids and names and creates an auxilliary file
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
that contain genotypes from both ssDNA and dsDNA libraries, the **ssDNA libraries are preferred and dsDNA genotypes are ignored**.
Through under the hood calls to `site_ids_to_names.R`, Site names and IDs are pulled from PANDORA, and added to the package janno file.


