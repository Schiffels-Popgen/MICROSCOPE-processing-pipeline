#!/usr/bin/env Rscript
library(sidora.core)
library(purrr)
library(dplyr, warn.conflicts = F)
library(readr)
library(tidyr)
library(stringr)

infer_color_chem <- function(x) {
  color_chem <- NULL
    if (x=="K00233 (HiSeq4000)") {
    color_chem=4
  } else if (x %in% c("NS500382 (Rosa)","NS500559 (Tosca)" )) {
    color_chem=2
  } else if (x %in% c("MinIon 1", "MinIon 2")) {
    color_chem=NA
    warning("MinIo sequencing does not have color chemistry. Set to NA.")
  } else {
    warning("Color chemistry inference was not successful. Contact lamnidis@shh.mpg.de. Uninferred color chemistries set to Unknown.")
    color_chem="Unknown"
  }
  return(as.integer(color_chem))
}

infer_library_specs <- function(x) {
  udg_treatment <- NULL
  strandedness <- NULL
  words <- str_split(x, " " , simplify = T)
  ## ssLib
  if (words[,1] == "ssLibrary") {
    strandedness = "single"
    udg_treatment = "none"
    
  ## External
  } else if (words[,1] %in% c("Extern", "External")) {
    strandedness = "Unknown"
    udg_treatment = "Unknown"
  
  ## Modern DNA
  } else if (words[,1] == "Illumina") {
    strandedness = "double"
    udg_treatment = "none"
  
  ## dsLib
  } else if (words[,1] == "dsLibrary") {
    strandedness = "double"

    ## Non UDG
    if (words[,3] == "UDG" ) {
      udg_treatment = "none"
      
    ## Half UDG
    } else if (words[,3] == "half") {
      udg_treatment = "half"
      
    ## Full UDG
    } else if (words[,3] == "full") {
      udg_treatment = "full"
    }
    
  ## Blanks
  } else if (words[,1] == "Capture") {
      udg_treatment = "none"
      strandedness = "double"
  }
  return(c(strandedness, udg_treatment))
}

## MAIN ##
args = commandArgs(trailingOnly=TRUE)

if (is.na(args[1])) {
  write("No input file given. \n\nusage: Rscript query_pandora_for_data.R /path/to/input_seq_IDs_file.txt /path/to/pandora/.credentials [--debug].", file=stderr())
  quit(status = 1)
}

query_list_seq <- read_delim(args[1], "\n", col_names = "Sequencing", col_types = 'c')
con <- get_pandora_connection(cred_file = args[2])

df_list <- get_df_list(
  c("TAB_Organism", "TAB_Protocol", "TAB_Sequencing_Sequencer", "TAB_Site","TAB_Individual","TAB_Library", "TAB_Sequencing","TAB_Raw_Data"),
  con)

# df_list[["TAB_Site"]] <- df_list[["TAB_Site"]] %>% mutate(Site=substr(Full_Library_Id,1,3)) %>% select(Full_Site_Id,Name)

df_list[["TAB_Individual"]] <- df_list[["TAB_Individual"]] %>% mutate(Site=substr(Full_Individual_Id,1,3)) %>% select(Site,Full_Individual_Id, Organism)
df_list[["TAB_Library"]] <- df_list[["TAB_Library"]] %>% mutate(Sample_Name=substr(Full_Library_Id,1,6)) %>% select(Sample_Name, Full_Library_Id, Protocol)
df_list[["TAB_Sequencing"]] <- df_list[["TAB_Sequencing"]] %>% mutate(Lib=substr(Full_Sequencing_Id,1,12), Sequencer=df_list[["TAB_Sequencing_Sequencer"]][["Name"]][`Sequencer`]) %>% select(Lib, Full_Sequencing_Id, Sequencer)
df_list[["TAB_Raw_Data"]] <- df_list[["TAB_Raw_Data"]]  %>% mutate(Seq=substr(Full_Raw_Data_Id,1,18)) %>% select(Seq, Full_Raw_Data_Id, FastQ_Files)

results <- inner_join(df_list[["TAB_Sequencing"]], query_list_seq, by=c("Full_Sequencing_Id"="Sequencing")) %>% 
  left_join(., df_list[["TAB_Library"]], by=c("Lib"="Full_Library_Id")) %>%
  left_join(., df_list[["TAB_Individual"]], by=c("Sample_Name"="Full_Individual_Id")) %>% 
  mutate(Protocol=map_chr(`Protocol`, function(prot) {df_list[["TAB_Protocol"]] %>% filter(`Id`==prot) %>% .[["Name"]]}),
         Organism=map_chr(`Organism`, function(org) {df_list[["TAB_Organism"]] %>% filter(`Id`==org) %>% .[["Name"]]})) %>%
  left_join(., df_list[["TAB_Raw_Data"]], by=c("Full_Sequencing_Id"="Seq")) %>%
  mutate(
    num_fq=map_int(`FastQ_Files`, function(fq) {ncol(str_split(fq, " ", simplify = T))}), 
    num_r1=map(`FastQ_Files`, function(fq) {sum(grepl("_R1_",str_split(fq, " ", simplify = T)))}),
    SeqType=ifelse(num_fq == num_r1, "SE", "PE")) %>%
  select(-starts_with("num_")) %>% 
  mutate(`FastQ_Files`=map(`FastQ_Files`, function(fq) {str_replace_all(fq, " ([[:graph:]]*_R2_.{3}.fastq.gz)", paste0(";","\\1"))})) %>%
  separate_rows(`FastQ_Files`, sep=" ") %>%
  separate(`FastQ_Files`, into=c("R1", "R2"), sep=";", fill="right") %>%
   mutate(Lane=as.integer(str_replace(`R1`,"[[:graph:]]*_L([[:digit:]]{3})_R[[:graph:]]*", "\\1")), 
          Strandedness=map_chr(`Protocol`, function (.) {infer_library_specs(.)[1]}), 
          UDG_Treatment=map_chr(`Protocol`, function(.){infer_library_specs(.)[2]}), 
          Colour_Chemistry=map_int(`Sequencer`, infer_color_chem),
          BAM=NA
          ) %>%
  rename(Library_ID=Full_Sequencing_Id)

if (!is.na(args[3]) && args[3] == "--debug") {
  write_tsv(results, "Debug_table.txt")
} else {
  cat(
    format_tsv(results %>% 
              select(Sample_Name, Library_ID, Lane, Colour_Chemistry, 
                     SeqType, Organism, Strandedness, UDG_Treatment, R1, R2, BAM))
  )
}

