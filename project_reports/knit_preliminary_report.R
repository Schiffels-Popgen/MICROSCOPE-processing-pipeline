#!/usr/bin/env Rscript

library(rmarkdown)
library(optparse)
library(stringr)

firstup <- function(x) {
  substr(x, 1, 1) <- toupper(substr(x, 1, 1))
  x
}

## Parse arguments ----------------------------
parser <- OptionParser(usage = "%prog -r preliminary_report.Rmd -c .credentials ")
parser <- add_option(parser, c("-r", "--report_template"), type = 'character', 
                     action = "store", dest = "template", 
                     help = "Path to the report template Rmd.")
parser <- add_option(parser, c("-c", "--cred_file"), type = 'character',
                     action = "store", dest = "cred_file", 
                     help = "The pandora credentials file.")
parser <- add_option(parser, c("-o", "--output_pdf_name"), type = 'character',
                     action = "store", dest = "output_name", 
                     help = "The name of the output .pdf report.")
parser <- add_option(parser, c("-s", "--snp_coverage_file"), type = 'character',
                     action = "store", dest = "snp_coverage_file",
                     help = "The path to the eigenstrat snp coverage file.")
parser <- add_option(parser, c("-d", "--sex_det_file"), type = 'character',
                     action = "store", dest = "sex_det_file",
                     help = "The path to the sex determination output file.")
parser <- add_option(parser, c("-t", "--stats_table"), type = 'character',
                     action = "store", dest = "stats_table",
                     help = "The path to the multiqc general stats table file.")
parser <- add_option(parser, c("-b", "--batch_name"), type = 'character',
                     action = "store", dest = "batch_name",
                     help = "The name of the batch, to be capitalised and used as a subtitle for the report.")
arguments <- parse_args(parser)

opts <- arguments

print("running with Options:")
print(opts)

reportTemplate <- opts$template
if(!file.exists(reportTemplate)) {
    stop("could not find report template. Please verify the path provided.")
}

## Capitalise first letter of batch name to use as a subtitle
subtitle <- firstup(opts$batch_name)

render(reportTemplate,
    params = list(
        set_subtitle = subtitle,
        # eager_output_dir = opts$input,
        snp_coverage_file = opts$snp_coverage_file,
        sex_det_file = opts$sex_det_file,
        stats_table = opts$stats_table,
        cred_file = opts$cred_file),
    output_file = opts$output_name,
    output_dir = dirname(opts$output_name)
)