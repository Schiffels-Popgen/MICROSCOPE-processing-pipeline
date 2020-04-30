#!/usr/bin/env Rscript
library(sidora.core)
library(dplyr)
library(readr)

args = commandArgs(trailingOnly=TRUE)

query_list_ind <- read_delim(args[1], "\n", col_names = "Individual", col_types = 'c')
sequencers <- c("1"="HiSeq", "2"="Minion", "3"="Minion", "4"="NextSeq", "5"="NextSeq")           
con <- get_pandora_connection()

df_list <- get_df_list(
  c("TAB_Site","TAB_Individual","TAB_Library", "TAB_Sequencing","TAB_Raw_Data"),
  con)

# df_list[["TAB_Site"]] <- df_list[["TAB_Site"]] %>% mutate(Site=substr(Full_Library_Id,1,3)) %>% select(Full_Site_Id,Name)

df_list[["TAB_Individual"]] <- df_list[["TAB_Individual"]] %>% mutate(Site=substr(Full_Individual_Id,1,3)) %>% select(Site,Full_Individual_Id)
df_list[["TAB_Library"]] <- df_list[["TAB_Library"]] %>% mutate(Ind=substr(Full_Library_Id,1,6))%>% select(Ind, Full_Library_Id, Protocol)
df_list[["TAB_Sequencing"]] <- df_list[["TAB_Sequencing"]] %>% mutate(Lib=substr(Full_Sequencing_Id,1,12)) %>% select(Lib, Full_Sequencing_Id, Sequencer)
df_list[["TAB_Raw_Data"]] <- df_list[["TAB_Raw_Data"]]  %>% mutate(Seq=substr(Full_Raw_Data_Id,1,18), seq_kit=ifelse(ncol(str_split(`FastQ_Files`," ", simplify=T)) == sum(grepl("_R1_", str_split(`FastQ_Files`," ", simplify=T))), "SE", "PE")) %>% select(Seq, Full_Raw_Data_Id, seq_kit, FastQ_Files)


results <- inner_join(df_list[["TAB_Individual"]], query_list_ind, by=c("Full_Individual_Id"="Individual")) %>% 
  left_join(.,df_list[["TAB_Library"]], by=c("Full_Individual_Id"="Ind")) %>% 
  left_join(.,df_list[["TAB_Sequencing"]], by=c("Full_Library_Id"="Lib")) %>% 
  left_join(.,df_list[["TAB_Raw_Data"]], by=c("Full_Sequencing_Id"="Seq"))
 
### STILL NEED TO ADD SE/PE TO FINAL TABLE


