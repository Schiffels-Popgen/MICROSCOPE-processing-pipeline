#!/usr/bin/env Rscript

library(rmarkdown)
library(optparse)
library(stringr)

make_title <- function(x) {
  x <- str_replace_all(x, "_"," ") ## Convert underscores to spaces
  x <- str_to_title(x) ## Uppercase the first letter of each word. lowercase the rest
  x
}

## Parse arguments ----------------------------
parser <- OptionParser(usage = "%prog -r long_report.Rmd -c .credentials -o output.pdf -s snp_coverage.txt -d sexdet.txt -t stats_table.tsv -p pMMR.out.txt -j package.janno -G package.geno -S package.snp -I package.ind -b my_batch_name -a annotation.txt -D distance.mdist -i distance.mdist.id")
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
parser <- add_option(parser, c("-p", "--pmmr_results"), type = 'character',
                    action = "store", dest = "pmmr_fn",
                    help = "The path to the pMMR results file.")
parser <- add_option(parser, c("-T", "--read_txt"), type = 'character',
                    action = "store", dest = "read_txt",
                    help = "The path to the READ results file.")
parser <- add_option(parser, c("-P", "--read_pdf"), type = 'character',
                    action = "store", dest = "read_pdf",
                    help = "The path to the READ output pdf.")
parser <- add_option(parser, c("-j", "--janno_fn"), type = 'character',
                    action = "store", dest = "janno_fn",
                    help = "The path to the forged meta-package janno file.")
parser <- add_option(parser, c("-G", "--GenoFile"), type = 'character',
                    action = "store", dest = "geno_fn",
                    help = "The path to the package eigenstrat .geno file.")
parser <- add_option(parser, c("-S", "--SnpFile"), type = 'character',
                    action = "store", dest = "snp_fn",
                    help = "The path to the package eigenstrat .snp file.")
parser <- add_option(parser, c("-I", "--IndFile"), type = 'character',
                    action = "store", dest = "ind_fn",
                    help = "The path to the package eigenstrat .ind file.")
parser <- add_option(parser, c("-b", "--batch_name"), type = 'character',
                    action = "store", dest = "batch_name",
                    help = "The name of the batch, to be capitalised and used as a subtitle for the report.")
parser <- add_option(parser, c("-a", "--bg_annotation_file"), type = 'character',
                    action = "store", dest = "bg_annotation_fn",
                    help = "The path to the file with the annotation info for the PCA background.")
parser <- add_option(parser, c("-W", "--we_evec_fn"), type = 'character',
                    action = "store", dest = "we_evec_fn",
                    help = "Path to the West Eurasian PCA eigenvector file.")
parser <- add_option(parser, c("-w", "--we_eval_fn"), type = 'character',
                    action = "store", dest = "we_eval_fn",
                    help = "Path to the West Eurasian PCA eigenvalue file.")
parser <- add_option(parser, c("-E", "--eu_evec_fn"), type = 'character',
                    action = "store", dest = "eu_evec_fn",
                    help = "Path to the European PCA eigenvector file.")
parser <- add_option(parser, c("-e", "--eu_eval_fn"), type = 'character',
                    action = "store", dest = "eu_eval_fn",
                    help = "Path to the European PCA eigenvalue file.")
parser <- add_option(parser, c("-D", "--report_date"), type = 'character',
                    action = "store", dest = "report_date",
                    help = "The date of the report generation.")
parser <- add_option(parser, c("-L", "--logo_file"), type = 'character',
                    action = "store", dest = "logo_file",
                    help = "Path to the project logo.")
arguments <- parse_args(parser)

opts <- arguments

print("running with Options:")
print(opts)

reportTemplate <- opts$template
if(!file.exists(reportTemplate)) {
    stop("could not find report template. Please verify the path provided.")
}

## Capitalise first letter of batch name to use as a subtitle
subtitle <- make_title(opts$batch_name)

render(reportTemplate,
    params = list(
        set_subtitle = subtitle,
        snp_coverage_file = opts$snp_coverage_file,
        sex_det_file = opts$sex_det_file,
        stats_table = opts$stats_table,
        cred_file = opts$cred_file,
        poseidon_geno = opts$geno_fn,
        poseidon_snp = opts$snp_fn,
        poseidon_ind = opts$ind_fn,
        poseidon_janno = opts$janno_fn,
        read_results_fn = opts$read_txt,
        read_plot_fn = opts$read_pdf,
        pmmr_results_fn = opts$pmmr_fn,
        pca_bg_annotation = opts$bg_annotation_fn,
        we_eval_fn = opts$we_eval_fn,
        we_evec_fn = opts$we_evec_fn,
        eu_eval_fn = opts$eu_eval_fn,
        eu_evec_fn = opts$eu_evec_fn,
        report_date = opts$report_date,
        logo_file = opts$logo_file
        ),
    output_file = opts$output_name,
    output_dir = dirname(opts$output_name)
)
