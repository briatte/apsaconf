library(tidyverse)
library(rvest)

fs::dir_create("data")

# parse (and harmonize some) session types --------------------------------

r <- fs::dir_ls("html", regexp = "types.html") %>%
  map(read_html) %>%
  map_dfr(
    ~ tibble::tibble(
      type = html_nodes(.x, xpath = "//a[contains(@href, 'type_id')]") %>%
        html_text(),
      count = html_nodes(.x, ".ui-li-count") %>%
        html_text()
    ),
    .id = "year"
  ) %>%
  mutate(year = str_c("20", str_extract(year, "\\d{2}")))

d <- r %>%
  mutate(
    # handle APSA 2021, p = in-person, v = virtual
    year = case_when(
      year == 2021 & str_detect(type, "In-Person") ~ "2021_p",
      year == 2021 & str_detect(type, "Virtual") ~ "2021_v",
      TRUE ~ year
    ),
    type = str_remove(type, "(Virtual|In-Person)\\s"),
    # remove prefix from short courses (2020)
    type = str_remove(type, "Pre-conference\\s"),
    # remove prefix from short courses (2018-2019)
    type = str_remove(type, "Wednesday\\s"),
    # harmonize full paper panel names (2015-2017)
    type = str_replace(type, "^Full Panel$", "Full Paper Panel"),
    # harmonize short courses names
    type = str_replace(type, "(.*)\\sShort Course", "Short Course \\1") %>%
      str_replace("Half Day", "Half-Day"),
    # harmonize non-TLC cafés
    type = str_replace(type, "(\\w+)\\sCafé", "Café (\\1)"),
    # shorten 'Featured Paper Panel: 30-minute Paper Presentations' (2017-2021)
    type = str_replace(type, "Featured Paper Panel.*", "Featured Paper Panel"),
    # harmonize "Short Course" (2015), "Workshop" (2018-2020) and "X / Y" (2016-2017)
    type = str_replace(type, "^(Short Course|Workshop)$", "Short Course / Workshop"),
  ) %>%
  pivot_wider(names_from = year, values_from = count) %>%
  arrange(type) %>%
  # count missing values per row
  mutate(n_na = rowSums(is.na(.)))

# subset to session types that show up on all conferences
d %>%
  # (`n_na < 2` to allow missing from either `2021_p` or `2021_v`)
  filter(n_na < 2) %>%
  select(-n_na)# %>%
  # knitr::kable()

# other session types happen more occasionally and have few panels
d %>%
  filter(n_na >= 2) %>%
  select(-n_na) %>%
  print(n = 100)

# [NOTE] from that last table:
#
# - "Paper Session" (2015)
# - "Full Submitted Panel" (2017)
# - "Created Panel" (2018-)
#
#   ... might all be the same thing, and have lots of sessions

# select session types with papers ----------------------------------------

# all of those are good candidates for inclusion:
#
# [NOTE] excluding courses and posters, as participant interactions might
#        differ much from rest; also excluding 5-minute 'lightning rounds'
r %>%
  filter(str_detect(type, "Author|Panel|Roundtable|Session|conference")) %>%
  readr::write_tsv("data/session-types-sample.tsv")

# also excluded: business meetings, cafés and receptions
r %>%
  filter(str_detect(type, "Author|Panel|Roundtable|Session|conference", negate = TRUE)) %>%
  readr::write_tsv("data/session-types-excluded.tsv")

# work-in-progress
