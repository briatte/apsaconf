library(tidyverse)
library(rvest)

fs::dir_create("data")

# counts of downloaded sessions
fs::dir_ls("html", regexp = "\\d{2}$") %>%
  map(fs::dir_ls, regexp = "session") %>%
  map_int(length)

# counts of downloaded papers
fs::dir_ls("html", regexp = "\\d{2}$") %>%
  map(fs::dir_ls, regexp = "paper") %>%
  map_int(length)

# parse sessions ----------------------------------------------------------

length(fs::dir_ls("html", regexp = "session", recurse = TRUE)) %>%
  cat("Parsing", ., "sessions...\n")

# takes a while...
d <- fs::dir_ls("html", regexp = "session\\d+", recurse = TRUE) %>%
  # sample(250) %>%
  map(read_html) %>%
  map_dfr(
    ~ tibble::tibble(
      session_title = html_node(.x, "h3") %>%
        html_text(),
      type = html_node(.x, xpath = "//strong[contains(text(), 'Session Submission Type')]/..") %>%
        html_text(),
      #
      # [NOTE] `pid` might be `people_id` __OR__ `paper_id` -- in the latter
      #        case, participant columns (`full_name` etc.) will need to be
      #        corrected by parsing the corresponding paper page
      #
      role = html_nodes(.x, xpath = "//a[contains(@href, 'people_id') or contains(@href, 'paper_id')]") %>%
        map(html_node, xpath = "preceding::h4[1]") %>%
        map_chr(html_text),
      pid = html_nodes(.x, xpath = "//a[contains(@href, 'people_id') or contains(@href, 'paper_id')]") %>%
        html_attr("href"),
      full_name = html_nodes(.x, xpath = "//a[contains(@href, 'people_id') or contains(@href, 'paper_id')]") %>%
        map(html_nodes, xpath = "p/i") %>%
        map(html_text) %>%
        map_chr(str_flatten, collapse = " "),
      first_name = html_nodes(.x, xpath = "//a[contains(@href, 'people_id') or contains(@href, 'paper_id')]/p/i[1]") %>%
        html_text(),
      affiliation = html_nodes(.x, xpath = "//a[contains(@href, 'people_id') or contains(@href, 'paper_id')]") %>%
        html_text()
    ),
    .id = "session"
  ) %>%
  mutate(
    year = str_c("20", str_extract(session, "\\d{2}")),
    session = str_extract(session, "\\d{3,}"),
    type = str_remove(type, "Session Submission Type: "),
    role = str_remove(role, "s$"),
    pid = str_extract(pid, "(paper|people)_id=\\d+"),
    # do not use (gets confused with middle names, initialled or not)
    # family_name = str_remove(full_name, first_name) %>%
    #   str_trim(),
    affiliation = str_remove(affiliation, fixed(full_name)) %>%
      str_trim() %>%
      # for some conference years, some cases in 2015 and 2016 at least
      str_remove("^,\\s+"),
    # simplify role
    role = case_when(
      role %in% "Chair" ~ "c",
      role %in% "Discussant" ~ "d",
      role %in% c("Presenter", "Individual Presentation") ~ "p",
      # recode/discard special cases (n = 1 each)
      # - "Author" (session 1520517, 2019) is also a chair
      # - "Mini-conference organizer" (session 1843632, 2021) is alone on panel
      role %in% c("Author", "Mini-Conference Organizer") ~ "e", # "else"
      TRUE ~ role
    )
  ) %>%
  select(year, session, type, everything())

# parse papers ------------------------------------------------------------

length(fs::dir_ls("html", regexp = "paper", recurse = TRUE)) %>%
  cat("Parsing", ., "papers...\n")

# also takes a while...
p <- fs::dir_ls("html", regexp = "paper\\d+", recurse = TRUE) %>%
  # sample(250) %>%
  map(read_html) %>%
  map_dfr(
    ~ tibble::tibble(
      paper_title = html_node(.x, "h3") %>%
        html_text(),
      # papers seem to have a single <blockquote>
      abstract = html_node(.x, "blockquote") %>%
        html_text(),
      role = html_nodes(.x, xpath = "//a[contains(@href, 'people_id')]") %>%
        map(html_node, xpath = "preceding::h4[1]") %>%
        map_chr(html_text),
      pid = html_nodes(.x, xpath = "//a[contains(@href, 'people_id')]") %>%
        html_attr("href"),
      full_name = html_nodes(.x, xpath = "//a[contains(@href, 'people_id')]") %>%
        map(html_nodes, xpath = "p/i") %>%
        map(html_text) %>%
        map_chr(str_flatten, collapse = " "),
      first_name = html_nodes(.x, xpath = "//a[contains(@href, 'people_id')]/p/i[1]") %>%
        html_text(),
      affiliation = html_nodes(.x, xpath = "//a[contains(@href, 'people_id')]") %>%
        html_text()
    ),
    .id = "paper"
  ) %>%
  mutate(
    year = str_c("20", str_extract(paper, "\\d{2}")),
    paper = str_extract(paper, "\\d{3,}"),
    role = str_remove(role, "s$"),
    pid = str_extract(pid, "people_id=\\d+"),
    affiliation = str_remove(affiliation, fixed(full_name)) %>%
      str_trim() %>%
      # for some conference years, some cases in 2015 and 2016 at least
      str_remove("^,\\s+"),
    # simplify role
    role = case_when(
      role %in% "Author" ~ "p",
      TRUE ~ role
    )
  ) %>%
  select(year, paper, everything())

# merge information from sessions and papers ------------------------------

d <- filter(d, str_detect(pid, "paper_id")) %>%
  # lose columns to be replaced
  select(-full_name, -first_name, -affiliation) %>%
  # move paper_id to its own column
  mutate(pid = str_remove_all(pid, "\\D")) %>%
  rename(paper = pid) %>%
  # merge to paper data
  left_join(p, by = c("year", "paper")) %>%
  # append all non-paper-presenting roles/people
  bind_rows(filter(d, str_detect(pid, "paper_id", negate = TRUE))) %>%
  arrange(year, session, pid)

# sanity check: all people identified as presenters in sessions are also
# identified as presenters (authors) in papers, or NA for chairs/discussants
stopifnot(d$role.x %in% c("p", NA_character_))
stopifnot(d$role.y %in% c("p", NA_character_))

# finalize roles and remove duplicates
d <- d %>%
  mutate(role = if_else(is.na(role), role.x, role)) %>%
  select(-role.x, -role.y) %>%
  mutate(pid = str_remove(pid, "people_id=")) %>%
  # remove two duplicates:
  # - session 1002316, presenter listed twice on same paper
  # - session 1274656, chair listed twice
  distinct()

# diagnose downloading/parsing issues -------------------------------------

# look at the very few papers with no author/presenter information
filter(d, is.na(pid)) %>%
  select(year:paper, -session_title) %>%
  arrange(year, paper)

# 2021: n = 2 paper pages just say "multiple events for single paper violation"
#       ... unsolvable, problem is also visible online
filter(d, year == 2021, is.na(pid)) %>%
  count(paper)

# remove problematic papers
d <- filter(d, !is.na(pid))


# quick data checks -------------------------------------------------------

# roles are homogeneous
table(d$role, d$year, exclude = NULL)

# some affiliations are missing
filter(d, affiliation %in% c("", "--")) %>%
  count(affiliation)

# some affiliations might need light cleaning
filter(d, str_detect(affiliation, "--")) %>%
  distinct(affiliation)

# some first names are just initials or contain some
filter(d, str_detect(first_name, "\\.")) %>%
  select(first_name, full_name) %>%
  distinct()

# on affiliations ---------------------------------------------------------

# some participants have multiple affiliations over the years
select(d, year, full_name, affiliation) %>%
  arrange(full_name) %>%
  # collapse over different roles
  distinct() %>%
  # [WARNING] assumes no homonyms -- see section below
  group_by(full_name) %>%
  mutate(n_affiliations = n_distinct(affiliation)) %>%
  filter(n_affiliations > 1)

# [NOTE] some 'different' affiliations are in fact identical, except written
#   differently (e.g. "Uni. of X", "Uni. of X, City")

# minimal data cleaning ---------------------------------------------------

# very few encoding issues
filter(d, str_detect(affiliation, "Ã")) %>%
  pull(affiliation) %>%
  unique()

# very few issues with prefixes
d %>%
  filter(
    str_detect(full_name, "(Dr|Prof|Ph\\.?D)(\\.|\\s|$)|PhD") |
      str_detect(affiliation, "(Dr|ProfPh\\.?D)(\\.|\\s|$)|PhD")
  ) %>%
  select(year, session, paper, first_name, full_name, affiliation)

# fix affiliations
d <- d %>%
  mutate(
    # fix minor encoding issues in affiliations
    affiliation = affiliation %>%
      str_replace_all("EconÃ³mica", "Económica") %>%
      str_replace_all("FundaÃ§Ã£o", "Fundação") %>%
      str_replace_all("InvestigaciÃ³n", "Investigación") %>%
      str_replace_all("JyvÃ¤skylÃ¤", "Jyväskylä") %>%
      str_replace_all("PolÃ­tica", "Política") %>%
      str_replace_all("SÃo Paulo", "São Paul") %>%
      str_replace_all("SociÃ©tÃ©", "Société") %>%
      str_replace_all("UniversitÃ¤t", "Universität") %>%
      str_replace_all("UniversitÃ©", "Université") %>%
      str_replace_all("ZÃ¼rich", "Zürich"),
    # encode missing affiliations and correct a few cases
    affiliation = case_when(
      affiliation %in% c("", "--") ~ NA_character_,
      # filter(d, full_name %in% "Federica Izzo")
      year == 2018 & full_name %in% "Federica Izzo" ~ "London School of Economics and Political Science",
      # filter(d, full_name %in% "Sparsha Saha")
      full_name %in% "Sparsha Saha" & affiliation %in% "Dr." ~ "Harvard University",
      # filter(d, str_detect(full_name, "Ackelsberg"))
      affiliation %in% "Dr. Martha A. Ackelsberg" ~ "Smith College",
      TRUE ~ affiliation
    ),
    # remove prefixes ("Prof." not actually found in the data)
    first_name = str_remove_all(first_name, "(Dr|,\\s+Ph\\.D|Prof)\\.\\s?"),
    full_name = str_remove_all(full_name, "(Dr|,\\s+Ph\\.D|Prof)\\.\\s?")
  ) %>%
  # some columns have extra white space (U.S. loves double spaces)
  # map(d, ~ sum(str_detect(.x, "^\\s|\\s$|\\s{2,}"), na.rm = TRUE))
  # str_subset(d$session_title, "^\\s|\\s$|\\s{2,}")
  # str_subset(d$paper_title, "^\\s|\\s$|\\s{2,}")
  # sample(str_subset(d$abstract, "^\\s|\\s$|\\s{2,}"), 1)
  # str_subset(d$full_name, "^\\s|\\s$|\\s{2,}")
  # str_subset(d$first_name, "^\\s|\\s$|\\s{2,}")
  # str_subset(d$affiliation, "^\\s|\\s$|\\s{2,}")
  mutate(across(where(is.character) & !c(year, session, paper, pid), str_squish))

# on homonyms -------------------------------------------------------------

# there are, in fact, some, but very few, homonyms (n = 68), and
# there are never more than 2 participants with the same name in the same year
# group_by(d, year, full_name) %>%
#   summarise(n_pids = n_distinct(pid)) %>%
#   filter(n_pids > 1) %>%
#   group_by(full_name) %>%
#   mutate(n = cur_group_id()) %>%
#   arrange(n) %>%
#   View()

# some are the same person, see e.g.

# - S. Reher (e.g. session 1655045): BA Bremen, PhD EUI, hired at Strathclyde
# filter(d, full_name %in% "Stefanie Reher") %>%
#   select(year, session, paper, pid, affiliation, role) %>%
#   arrange(year, session)

# - N. Rush Smith: seems to have created multiple accounts in 2021
# filter(d, year == 2021, full_name %in% "Nicholas Rush Smith")

# - more examples
# filter(d, full_name %in% c("Ling Chen", "Ngoc Phan", "Benjamin Miller")) %>%
#   select(full_name, year, session, paper, pid, affiliation, role) %>%
#   arrange(full_name, year, session) %>%
#   View()

# TODO: fix those manually if the number of cases stays low

# export data and counts --------------------------------------------------

# sanity checks
stopifnot(!is.na(d$year))
stopifnot(!is.na(d$session))
stopifnot(!is.na(d$type))
stopifnot(!is.na(d$session_title))
stopifnot(!is.na(d$pid))
stopifnot(!is.na(d$full_name))
stopifnot(!is.na(d$first_name))
stopifnot(!is.na(d$role))

# [NOTE] allowed NAs:
#
# - `paper`, `paper_title`, `abstract` (for chairs/discussants)
# - `affiliation`

# export everything as backup
arrange(d, year, session, role, pid) %>%
  readr::write_tsv("data/programs.tsv")

# export conference years
group_by(d, year) %>%
  summarise(
    n_sessions = n_distinct(session),
    # [WARNING] assumes no homonyms -- see section above
    n_participants = n_distinct(pid),
    n_names = n_distinct(full_name),
    n_affiliations = n_distinct(affiliation, na.rm = TRUE),
    n_papers = n_distinct(paper, na.rm = TRUE)
  ) %>%
  arrange(year) %>%
  readr::write_tsv("data/years.tsv")

print(read_tsv("data/years.tsv", col_types = "iiiiii"))
# print(colSums(read_tsv("data/years.tsv", col_types = "iiiiii")))

# export sessions
select(d, year, session, type, session_title) %>%
  group_by(year, session) %>%
  add_count(name = "n_participants") %>%
  distinct() %>%
  arrange(year, session) %>%
  readr::write_tsv("data/sessions.tsv")

# export papers
filter(d, !is.na(paper)) %>%
  select(year, session, paper, paper_title, abstract) %>%
  # some rows are repeated when the paper has multiple authors
  distinct() %>%
  arrange(year, session, paper) %>%
  readr::write_tsv("data/papers.tsv")

# export roles
# [NOTE] pid is NOT a fixed person id: it changes every year
select(d, year, session, role, pid, paper) %>%
  # not required, removed duplicated rows earlier
  # distinct() %>%
  arrange(year, session, role) %>%
  readr::write_tsv("data/roles.tsv")

# ensure that participants never change names or affiliations on a same year
p <- select(d, year, pid, full_name, first_name, affiliation) %>%
  group_by(pid) %>%
  mutate(
    n_names = n_distinct(full_name),
    n_affiliations = n_distinct(affiliation)
  ) %>%
  filter(n_names > 1 | n_affiliations > 1)

stopifnot(!nrow(p))

select(d, year, pid, full_name, first_name, affiliation) %>%
  # some participant rows repeat due to multiple roles (e.g. chair + discussant)
  distinct() %>%
  arrange(full_name, year) %>%
  readr::write_tsv("data/participants.tsv")

cat(
  "Exported",
  n_distinct(d$year), "years,",
  n_distinct(d$session), "sessions,",
  n_distinct(d$full_name), "participant names,",
  n_distinct(d$affiliation), "affiliations.\n"
)

# # number of rows in each file
# fs::dir_ls("data") %>%
#   map(readr::read_tsv, col_types = cols(), guess_max = 10^5) %>%
#   map_dfc(~ nrow(.x), .id = "id")

# work-in-progress
