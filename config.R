# configuration for the poster voting app.
# override the password with environment variable VOTE_ADMIN_PASSWORD.

ADMIN_PASSWORD <- Sys.getenv("VOTE_ADMIN_PASSWORD", unset = "change-me")

# Votes are appended here (created on first vote).
VOTES_PATH <- file.path("data", "votes.csv")

# Criteria metadata (labels + expandable help text).
CRITERIA <- list(
  relevance = list(
    id = "score_relevance",
    label = "Relevance and contribution to agroecology",
    help = paste(
      "Addresses agroecological challenges or opportunities.",
      "Contributes to agroecological transition, resilience, and sustainability.",
      "Provides useful insights for practice, research and/or policy."
    )
  ),
  cocreation = list(
    id = "score_cocreation",
    label = "Co-creation and practical impact",
    help = paste(
      "Involves stakeholders in a meaningful way.",
      "Is based on co-creation and participatory approaches.",
      "Results have practical value and potential impact."
    )
  ),
  clarity = list(
    id = "score_clarity",
    label = "Clarity and communication",
    help = paste(
      "Is visually clear and well organized.",
      "Communicates key messages and results effectively.",
      "Is easy to understand and engaging."
    )
  )
)
