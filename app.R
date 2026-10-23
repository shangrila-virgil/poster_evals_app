# Poster scoring Shiny app — conference voting

library(shiny)
library(bslib)
library(shinyjs)
library(DT)

source("config.R", local = TRUE)

# posters csv
read_posters <- function(path) {
  header <- readLines(path, n = 1L, encoding = "UTF-8", warn = FALSE)
  header <- sub("^\ufeff", "", header)
  sep <- if (grepl(";", header, fixed = TRUE) && !grepl(",", header, fixed = TRUE)) ";" else ","
  df <- utils::read.delim(
    path,
    sep = sep,
    stringsAsFactors = FALSE,
    fileEncoding = "UTF-8",
    check.names = FALSE,
    quote = "\"",
    comment.char = ""
  )
  names(df) <- trimws(sub("^\ufeff", "", names(df)))
  df[] <- lapply(df, function(x) if (is.character(x)) trimws(x) else x)
  df
}

posters <- read_posters("posters.csv")
need <- c("id", "short_title", "author")
if (!all(need %in% names(posters))) {
  stop(
    "posters.csv must have columns id, short_title, author. Found: ",
    paste(names(posters), collapse = ", ")
  )
}
posters$id <- toupper(trimws(posters$id))

# Flip to TRUE to reopen scoring.
VOTES_OPEN <- FALSE

dir.create(dirname(VOTES_PATH), showWarnings = FALSE, recursive = TRUE)

VOTE_COLS <- c(
  "timestamp", "session_id", "poster_id",
  "score_relevance", "score_cocreation", "score_clarity"
)

ensure_votes_file <- function() {
  if (!file.exists(VOTES_PATH)) {
    write.csv(
      data.frame(
        timestamp = character(),
        session_id = character(),
        poster_id = character(),
        score_relevance = integer(),
        score_cocreation = integer(),
        score_clarity = integer(),
        stringsAsFactors = FALSE
      )[0, , drop = FALSE],
      VOTES_PATH,
      row.names = FALSE
    )
  }
}

append_vote <- function(row) {
  ensure_votes_file()
  write.table(
    row,
    file = VOTES_PATH,
    sep = ",",
    col.names = FALSE,
    row.names = FALSE,
    append = TRUE,
    qmethod = "double"
  )
}

read_votes <- function() {
  ensure_votes_file()
  df <- tryCatch(
    read.csv(VOTES_PATH, stringsAsFactors = FALSE),
    error = function(e) {
      data.frame(
        timestamp = character(),
        session_id = character(),
        poster_id = character(),
        score_relevance = integer(),
        score_cocreation = integer(),
        score_clarity = integer(),
        stringsAsFactors = FALSE
      )
    }
  )
  if (nrow(df) == 0L) return(df)
  for (col in c("score_relevance", "score_cocreation", "score_clarity")) {
    if (col %in% names(df)) df[[col]] <- as.numeric(df[[col]])
  }
  df
}

agro_theme <- bs_theme(
  version = 5,
  bootswatch = "flatly",
  primary = "#2E7D32",
  secondary = "#558B2F",
  success = "#43A047",
  info = "#00897B",
  "font-size-base" = "1.05rem",
  "border-radius" = "0.5rem"
)

custom_css <- HTML("
  :root { --poster-btn-h: 3rem; }
  body { background: #f4f7f4; }
  .app-header {
    background: linear-gradient(135deg, #1B5E20 0%, #2E7D32 55%, #558B2F 100%);
    color: #fff; padding: 0.85rem 1.1rem; margin-bottom: 0.75rem;
    border-radius: 0 0 0.75rem 0.75rem;
    box-shadow: 0 2px 8px rgba(0,0,0,.12);
  }
  .app-header h1 { font-size: 1.35rem; margin: 0; font-weight: 700; }
  .app-header .subtitle { opacity: .9; font-size: .9rem; margin: 0; }
  .poster-nav .btn {
    width: 100%; min-height: var(--poster-btn-h); margin-bottom: .4rem;
    font-weight: 600; font-size: 1.05rem; text-align: left;
    border: 2px solid #c8e6c9; background: #fff; color: #1B5E20;
  }
  .poster-nav .btn:hover { background: #e8f5e9; border-color: #81c784; }
  .poster-nav .btn.active-poster {
    background: #2E7D32; color: #fff; border-color: #1B5E20;
    box-shadow: 0 2px 6px rgba(46,125,50,.35);
  }
  .poster-nav .btn.voted {
    border-style: dashed; opacity: .85;
  }
  .poster-nav .btn.voted::after {
    content: ' ✓'; font-weight: 700;
  }
  .score-card {
    background: #fff; border-radius: .75rem; padding: 1.1rem 1.2rem;
    box-shadow: 0 1px 6px rgba(0,0,0,.08); margin-bottom: 1rem;
  }
  .score-card h2 { font-size: 1.25rem; color: #1B5E20; margin-bottom: .15rem; }
  .score-card .author { color: #666; font-size: .95rem; margin-bottom: 1rem; }
  .criterion-block { margin-bottom: 1.35rem; padding-bottom: .85rem;
    border-bottom: 1px solid #e8eee8; }
  .criterion-block:last-of-type { border-bottom: none; }
  .criterion-label { font-weight: 600; color: #2E7D32; margin-bottom: .25rem; }
  .criterion-help { font-size: .82rem; color: #666; margin: .25rem 0 .55rem; }
  .slider-labels {
    display: flex; justify-content: space-between; font-size: .8rem;
    color: #888; margin-top: -.35rem; padding: 0 .15rem;
  }
  .irs--shiny .irs-bar, .irs--shiny .irs-handle { background: #2E7D32 !important;
    border-color: #1B5E20 !important; }
  .irs--shiny .irs-from, .irs--shiny .irs-to, .irs--shiny .irs-single {
    background: #2E7D32 !important; }
  .irs--shiny .irs-line { background: #c8e6c9 !important; }
  .submit-row { margin-top: .5rem; }
  .submit-row .btn-lg { min-height: 3.2rem; font-weight: 700; width: 100%;
    max-width: 420px; }
  .thankyou-box {
    text-align: center; padding: 2.5rem 1.25rem; background: #fff;
    border-radius: .75rem; box-shadow: 0 1px 6px rgba(0,0,0,.08);
  }
  .thankyou-box .check {
    font-size: 3rem; color: #43A047; line-height: 1; margin-bottom: .5rem;
  }
  .admin-wrap { background: #fff; border-radius: .75rem; padding: 1rem;
    box-shadow: 0 1px 6px rgba(0,0,0,.08); }
  @media (max-width: 767.98px) {
    .poster-nav {
      display: flex; flex-wrap: wrap; gap: .35rem; margin-bottom: .75rem;
    }
    .poster-nav .btn {
      width: auto; flex: 1 1 18%; min-width: 3.4rem; text-align: center;
      padding: .45rem .3rem; margin-bottom: 0;
    }
  }
")

ui <- page_fluid(
  theme = agro_theme,
  useShinyjs(),
  tags$head(
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1, maximum-scale=1"),
    tags$style(custom_css)
  ),
  div(
    class = "app-header",
    h1("Poster scoring"),
    p(class = "subtitle", if (isTRUE(VOTES_OPEN)) "Rate each poster on relevance, co-creation & clarity (1 = low, 5 = high)" else "Thanks for checking in. The votes are now CLOSED.")
  ),
  # Admin gate / results (shown when ?admin=1 or password form submitted)
  uiOutput("admin_panel"),
  # Main voting UI (hidden when admin view is active without voting)
  uiOutput("main_ui")
)

server <- function(input, output, session) {
  session_id <- paste0(
    format(Sys.time(), "%Y%m%d%H%M%S"),
    "-",
    paste(sample(c(letters, 0:9), 8, replace = TRUE), collapse = "")
  )

  # Posters already voted in this browser session
  voted <- reactiveVal(character(0))
  selected_poster <- reactiveVal(NULL)
  show_thanks <- reactiveVal(FALSE)
  admin_unlocked <- reactiveVal(FALSE)

  # Deep link + admin query params
  observe({
    qs <- parseQueryString(session$clientData$url_search)
    if (!is.null(qs$poster) && nzchar(qs$poster)) {
      pid <- toupper(trimws(qs$poster))
      if (pid %in% posters$id) {
        selected_poster(pid)
        show_thanks(FALSE)
      }
    }
    if (!is.null(qs$admin) && qs$admin %in% c("1", "true", "yes")) {
      # Still require password unless already unlocked via form
      admin_unlocked(FALSE)
    }
    if (!is.null(qs$password) && identical(qs$password, ADMIN_PASSWORD)) {
      admin_unlocked(TRUE)
    }
  })

  is_admin_mode <- reactive({
    qs <- parseQueryString(session$clientData$url_search)
    admin_q <- !is.null(qs$admin) && qs$admin %in% c("1", "true", "yes")
    admin_q || isTRUE(admin_unlocked())
  })

  output$admin_panel <- renderUI({
    if (!is_admin_mode()) return(NULL)
    if (!isTRUE(admin_unlocked())) {
      return(div(
        class = "admin-wrap mb-3",
        h3("Admin results"),
        p("Enter the admin password to view vote tallies."),
        passwordInput("admin_pw", "Password", value = "", width = "280px"),
        actionButton("admin_login", "Unlock results", class = "btn-primary"),
        tags$hr(),
        p(class = "text-muted small",
          "Tip: set env var VOTE_ADMIN_PASSWORD (default: change-me). ",
          "Or open ?admin=1&password=YOUR_PASSWORD")
      ))
    }
    div(
      class = "admin-wrap mb-3",
      h3("Admin — live results"),
      p(class = "text-muted",
        "Means of Relevance / Co-creation / Clarity and overall average. ",
        actionLink("admin_refresh", "Refresh")),
      DTOutput("admin_table"),
      tags$hr(),
      downloadButton("admin_download", "Download votes CSV", class = "btn-secondary btn-sm"),
      tags$hr(),
      p(tags$a(href = "?", "← Back to voting"))
    )
  })

  observeEvent(input$admin_login, {
    if (identical(input$admin_pw, ADMIN_PASSWORD)) {
      admin_unlocked(TRUE)
    } else {
      showNotification("Incorrect password", type = "error")
    }
  })

  admin_data <- reactive({
    input$admin_refresh
    input$submit_vote
    votes <- read_votes()
    base <- posters[, c("id", "short_title", "author")]
    names(base)[1] <- "poster_id"
    base$n_votes <- 0L
    base$mean_relevance <- NA_real_
    base$mean_cocreation <- NA_real_
    base$mean_clarity <- NA_real_
    base$mean_overall <- NA_real_
    if (nrow(votes) == 0L) return(base)

    for (pid in unique(votes$poster_id)) {
      sub <- votes[votes$poster_id == pid, , drop = FALSE]
      idx <- match(pid, base$poster_id)
      if (is.na(idx)) next
      base$n_votes[idx] <- nrow(sub)
      base$mean_relevance[idx] <- round(mean(sub$score_relevance, na.rm = TRUE), 2)
      base$mean_cocreation[idx] <- round(mean(sub$score_cocreation, na.rm = TRUE), 2)
      base$mean_clarity[idx] <- round(mean(sub$score_clarity, na.rm = TRUE), 2)
      base$mean_overall[idx] <- round(
        mean(c(
          base$mean_relevance[idx],
          base$mean_cocreation[idx],
          base$mean_clarity[idx]
        ), na.rm = TRUE),
        2
      )
    }
    base
  })

  output$admin_table <- renderDT({
    df <- admin_data()
    df$n_votes[is.na(df$n_votes)] <- 0L
    datatable(
      df,
      rownames = FALSE,
      colnames = c(
        "Poster", "Title", "Author", "Votes",
        "Relevance", "Co-creation", "Clarity", "Overall"
      ),
      options = list(pageLength = 15, dom = "t", order = list(list(7, "desc")))
    )
  })

  output$admin_download <- downloadHandler(
    filename = function() paste0("poster-votes-", format(Sys.time(), "%Y%m%d-%H%M%S"), ".csv"),
    content = function(file) {
      ensure_votes_file()
      file.copy(VOTES_PATH, file)
    }
  )

  output$main_ui <- renderUI({
    # Keep voting UI available even in admin mode (below results)
    tagList(
      layout_sidebar(
        sidebar = sidebar(
          title = "Posters",
          width = 220,
          open = "always",
          div(
            class = "poster-nav",
            lapply(posters$id, function(pid) {
              actionButton(
                inputId = paste0("pick_", pid),
                label = pid,
                class = "btn btn-outline-success"
              )
            })
          ),
          tags$hr(),
          tags$small(class = "text-muted", "Scan a poster QR or tap a number.")
        ),
        uiOutput("content_panel")
      )
    )
  })

  # Wire poster buttons
  lapply(posters$id, function(pid) {
    observeEvent(input[[paste0("pick_", pid)]], {
      selected_poster(pid)
      show_thanks(FALSE)
      # Update URL without reload for shareability
      updateQueryString(paste0("?poster=", pid), mode = "replace", session = session)
    }, ignoreInit = TRUE)
  })

  # Style active / voted buttons via shinyjs
  observe({
    sel <- selected_poster()
    done <- voted()
    for (pid in posters$id) {
      bid <- paste0("pick_", pid)
      shinyjs::removeCssClass(bid, "active-poster")
      shinyjs::removeCssClass(bid, "voted")
      if (!is.null(sel) && identical(pid, sel)) shinyjs::addCssClass(bid, "active-poster")
      if (pid %in% done) shinyjs::addCssClass(bid, "voted")
    }
  })

  output$content_panel <- renderUI({
    pid <- selected_poster()

    if (!isTRUE(VOTES_OPEN)) {
      if (is.null(pid)) {
        return(div(
          class = "score-card",
          h2("Votes are closed"),
          p("Choose a poster from the list, or scan its QR code.")
        ))
      }
      row <- posters[posters$id == pid, , drop = FALSE]
      return(div(
        class = "score-card",
        h2(paste0(row$id, " — ", row$short_title)),
        div(class = "author", row$author),
        div(
          class = "thankyou-box",
          style = "box-shadow: none; padding: 1.5rem 0.5rem 0.5rem;",
          div(class = "check", "✓"),
          h2("Thanks for checking in. The votes are now CLOSED.")
        )
      ))
    }

    if (isTRUE(show_thanks())) {
      return(div(
        class = "thankyou-box",
        div(class = "check", "✓"),
        h2("Thank you for helping select the best poster!"),
        p("Your scores have been recorded."),
        actionButton("score_another", "Score another poster", class = "btn-success btn-lg mt-3")
      ))
    }

    if (is.null(pid)) {
      return(div(
        class = "score-card",
        h2("Select a poster"),
        p("Choose a poster from the list (or scan the QR code next to it) to begin scoring.")
      ))
    }

    row <- posters[posters$id == pid, , drop = FALSE]
    already <- pid %in% voted()

    tagList(
      div(
        class = "score-card",
        h2(paste0(row$id, " — ", row$short_title)),
        div(class = "author", row$author),
        if (already) {
          div(
            class = "alert alert-warning",
            "You already scored this poster in this session. You can score other posters."
          )
        } else {
          tagList(
            criterion_ui("relevance", CRITERIA$relevance),
            criterion_ui("cocreation", CRITERIA$cocreation),
            criterion_ui("clarity", CRITERIA$clarity),
            div(
              class = "submit-row",
              actionButton(
                "submit_vote",
                "Submit Vote",
                class = "btn-success btn-lg",
                icon = icon("check")
              )
            ),
            uiOutput("submit_msg")
          )
        }
      )
    )
  })

  observeEvent(input$score_another, {
    show_thanks(FALSE)
    selected_poster(NULL)
    updateQueryString("?", mode = "replace", session = session)
  })

  observeEvent(input$submit_vote, {
    if (!isTRUE(VOTES_OPEN)) {
      showNotification("Voting is closed.", type = "warning")
      return()
    }
    pid <- selected_poster()
    if (is.null(pid)) return()
    if (pid %in% voted()) {
      showNotification("Already voted for this poster in this session.", type = "warning")
      return()
    }

    s_rel <- input$score_relevance
    s_co <- input$score_cocreation
    s_cl <- input$score_clarity

    if (any(vapply(list(s_rel, s_co, s_cl), function(x) is.null(x) || is.na(x), logical(1)))) {
      showNotification("Please set all three scores (1–5).", type = "error")
      return()
    }

    row <- data.frame(
      timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
      session_id = session_id,
      poster_id = pid,
      score_relevance = as.integer(s_rel),
      score_cocreation = as.integer(s_co),
      score_clarity = as.integer(s_cl),
      stringsAsFactors = FALSE
    )
    append_vote(row)
    voted(c(voted(), pid))
    show_thanks(TRUE)
  })
}

criterion_ui <- function(key, meta) {
  div(
    class = "criterion-block",
    div(class = "criterion-label", meta$label),
    tags$details(
      tags$summary(style = "cursor:pointer;color:#558B2F;font-size:.85rem;", "Help / what to look for"),
      div(class = "criterion-help", meta$help)
    ),
    sliderInput(
      inputId = meta$id,
      label = NULL,
      min = 1,
      max = 5,
      value = 3,
      step = 1,
      ticks = TRUE,
      width = "100%"
    ),
    div(class = "slider-labels", span("1 — low"), span("5 — high"))
  )
}

shinyApp(ui, server)
