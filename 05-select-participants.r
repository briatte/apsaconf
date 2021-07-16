library(tidyverse)

# select sessions ---------------------------------------------------------

s <- read_tsv("data/session-types-sample.tsv", col_types = "ici") %>%
  select(-count) %>%
  left_join(
    read_tsv("data/sessions.tsv", col_types = "iccci"),
    by = c("year", "type")
  ) %>%
  # add participant roles
  left_join(
    read_tsv("data/roles.tsv", col_types = "iccc"),
    by = c("year", "session")
  ) %>%
  # add participant information
  left_join(
    read_tsv("data/participants.tsv", col_types = "icccc"),
    by = c("year", "pid")
  )
