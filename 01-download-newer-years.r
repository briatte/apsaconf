library(tidyverse)
library(rvest)

# loop through years 2018, 2019, 2020, 2021
for (y in 21:18) {

  cat("APSA", str_c("20", y, collapse = ""), "... ")
  fs::dir_create(str_c("html/apsa", y))

  u <- str_c("https://convention2.allacademic.com/one/apsa/apsa", y, "/index.php")

  # simulate session
  h <- rvest::session(u)

  if (y %in% 21:20) {

    cat("Setting time zone... ")

    # fill in form
    f <- html_node(h, "form") %>%
      html_form() %>%
      html_form_set("new_timezone" = "Europe/Paris")

    # submit form
    s <- session_submit(h, f)

  } else {

    s <- h

  }

  cat("Finding session types... ")

  # get single URL listing all sessions
  u <- html_nodes(s, xpath = "//a[contains(@href, 'browse_by_session')]") %>%
    html_attr("href") %>%
    unique()

  stopifnot(length(u) == 1)

  s <- session_jump_to(s, u)
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
