library(tidyverse)

# data collection ---------------------------------------------------------

# run slow scripts only if missing master data
if (!fs::file_exists("data/programs.tsv")) {

  # downloads
  source("01-download-newer-years.r")
  source("02-download-older-years.r")

  # parsing and exports
  source("03-parse-sessions.r")

}

d <- readr::read_tsv("data/programs.tsv", col_types = "iccccccccccc")

# sample selection --------------------------------------------------------

# select session types
source("04-select-session-types.r")

# select papers and participants
source("05-select-participants.r")
