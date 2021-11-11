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
parser <- add_option(parser, c("-i", "--input_eager_output_directory"), type = 'character',
                     action = "store", dest = "input",
                     help = "The path to the eager output directory.")
arguments <- parse_args(parser)

opts <- arguments

print("running with Options:")
print(opts)

reportTemplate <- opts$template
if(!file.exists(reportTemplate)) {
    stop("could not find report template. Please verify the path provided.")
}

## Get batch name from eager_output directory path
subtitle <- stringr::str_split_fixed(basename(opts$input), "-", n=4)[1,4]
subtitle <- firstup(subtitle) ## Capitalise first letter

render(reportTemplate,
    params = list(
        set_subtitle = subtitle,
        eager_output_dir = opts$input,
        cred_file = opts$cred_file),
    output_file = opts$output_name,
    output_dir = dirname(opts$output_name)
)