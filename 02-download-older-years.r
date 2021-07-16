library(tidyverse)
library(rvest)

# loop through years 2015, 2016, 2017
for (y in 17:15) {

  cat("APSA", str_c("20", y, collapse = ""), "...\n")
  fs::dir_create(str_c("html/apsa", y))

  u <- str_c("https://convention2.allacademic.com/one/apsa/apsa", y, "/index.php")

  # 1. simulate session
  # 2. bounce from main program page to the one listing session (panel) types
  # (might be made silent with httr::verbose)
  s <- rvest::session(u) %>%
    session_jump_to(str_c(u, "?cmd=Prepare+Online+Program&program_focus=main")) %>%
    session_follow_link(xpath = "//a[contains(@href, 'session_type')]")

  cat("Finding session types... ")

  h <- read_html(s)

  # get URLs listing all sessions (panels) by type
  p <- tibble::tibble(
    text = html_nodes(h, xpath = "//li/a[contains(@href, 'session_type_id')]") %>%
      html_text(),
    url = html_nodes(h, xpath = "//li/a[contains(@href, 'session_type_id')]") %>%
      html_attr("href")
  )

  cat(nrow(p), "session types\n")

  # keep a backup to extract session types
  f <- fs::path("html", str_c("apsa", y, "-session-types.html"))
  if (!fs::file_exists(f)) {
    readr::write_lines(h, .)
  }

  # loop through session types ----------------------------------------------

  for (j in nrow(p):1) {

    cat("APSA", str_c("20", y, collapse = ""), p$text[ j ])

    h <- session_jump_to(s, p$url[ j ]) %>%
      read_html()

    # URLs to all sessions
    u <- tibble::tibble(
      text = html_nodes(h, xpath = "//li/a[contains(@href, 'session_id')]/p[1]/strong[1]") %>%
        html_text(),
      url = html_nodes(h, xpath = "//li/a[contains(@href, 'session_id')]") %>%
        html_attr("href"),
      file = str_extract(url, "session_id=\\d+") %>%
        str_extract("\\d+") %>%
        str_c("session", ., ".html") %>%
        fs::path("html", str_c("apsa", y), .)
    )

    cat(":", nrow(u), "session(s)\n")

    for (i in nrow(u):1) {

      # show APSA year, session number, type and title
      cat(
        "APSA", str_c("20", y, collapse = ""),
        str_pad(i, 4), str_extract(u$file[ i ], "\\d{3,}"),
        str_trunc(p$text[ j ], 25), "--", str_trunc(u$text[ i ], 40)
      )

      if (!fs::file_exists(u$file[ i ])) {

        session_jump_to(s, u$url[ i ]) %>%
          read_html() %>%
          readr::write_lines(u$file[ i ])

        # go slow
        Sys.sleep(1.5)

      }
      cat("\n")

      # find and get papers

      h <- read_html(u$file[ i ]) %>%
        html_nodes(xpath = "//li/a[contains(@href, 'paper_id')]") %>%
        html_attr("href")

      if (length(h)) {

        h <- h %>%
          as_tibble_col(column_name = "url") %>%
          mutate(
            # remove stale PHP session ID
            url = str_remove(url, "&PHPSESSID=.*"),
            file = str_extract(url, "paper_id=\\d+") %>%
              str_extract("\\d+") %>%
              str_c("paper", ., ".html") %>%
              fs::path("html", str_c("apsa", y), .)
          )

        cat("Downloading", nrow(h), "paper abstract(s)")
        for (k in nrow(h):1) {

          if (!fs::file_exists(h$file[ k ])) {

            session_jump_to(s, h$url[ k ]) %>%
              read_html() %>%
              readr::write_lines(h$file[ k ])

            # go slow
            Sys.sleep(1.5)

          }
          cat(".")

        }
        cat("\n")

      }

    }

  }

  cat("Done for year", str_c("20", y, ".", collapse = ""), "\n\n")

}

# kthxbye
