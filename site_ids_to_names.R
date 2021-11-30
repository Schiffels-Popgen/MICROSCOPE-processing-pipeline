#!/usr/bin/env Rscript
library(sidora.core)
library(tidyverse, warn.conflicts=F)

con <- get_pandora_connection("~/Software/github/Schiffels-Popgen/MICROSCOPE-processing-pipeline/.credentials")

complete_pandora_table <- join_pandora_tables(
  get_df_list(
    c(make_complete_table_list(
      c("TAB_Site", "TAB_Raw_Data")
    )), con = con))

sites_list <- readr::read_tsv("/mnt/archgen/MICROSCOPE/poseidon_packages/Sites.txt", col_names=c("Site"), col_types='c')

results <- inner_join(complete_pandora_table, sites_list, by=c("site.Site_Id"="Site")) %>% 
    select(site.Site_Id, site.Name, site.Latitude, site.Longitude) %>% 
    mutate(site.Longitude=round(site.Longitude,5), site.Latitude=round(site.Latitude,5), site.Name=str_replace_all(site.Name, '"','')) %>%
    replace_na(list(site.Longitude="n/a", site.Latitude="n/a")) %>%
    unique()

write_tsv(results, "/mnt/archgen/MICROSCOPE/poseidon_packages/Sites_Info.txt", col_names=F)
