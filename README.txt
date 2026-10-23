# Poster voting app (R Shiny)

Mobile-friendly Shiny app for scoring conference posters on three agroecology criteria. Supports QR deep-links, session-level double-submit protection, CSV vote storage, and a password-gated admin results view.

## Posters

to be provided in a csv 

## Scoring criteria (1–5)

1. **Relevance and contribution to agroecology**
2. **Co-creation and practical impact**
3. **Clarity and communication**

Sliders default to **3** (midpoint) with labels “1 — low” / “5 — high”. Expandable help under each criterion matches the slide text.

## Requirements

- R ≥ 4.2
- Packages: `shiny`, `bslib`, `shinyjs`, `DT` (app); `qrcode` (QR script); `rsconnect` (optional deploy)

```r
# from this directory
source("install_packages.R")
# or: Rscript install_packages.R
```

## Run locally

```r
setwd("/path/to/poster-votes")
shiny::runApp(".", launch.browser = TRUE)
```

Or from a shell:

```bash
cd /path/to/poster-votes
Rscript -e 'shiny::runApp(".", host="127.0.0.1", port=3838)'
```

Then open `http://127.0.0.1:3838/?poster=P4` to verify deep-linking.

## Deep links & QR codes

Each poster QR should encode:

```
https://YOUR_APP_URL/?poster=P4
```

Generate PNGs after you know the deployed base URL:

```bash
Rscript generate_qrcodes.R https://yourname.shinyapps.io/poster-votes/
# writes qrcodes/P1.png … P10.png and qrcodes/manifest.csv
```

Print `qrcodes/P#.png` next to the matching poster.

## Admin / results

1. Open `https://YOUR_APP_URL/?admin=1`
2. Enter the password (default **`change-me`**)

Or unlock in one step:

```
https://YOUR_APP_URL/?admin=1&password=change-me
```

**Set a real password before the conference:**

```bash
# shinyapps.io: Application Settings → Vars / Environment
VOTE_ADMIN_PASSWORD=your-secret
```

Or edit the default in `config.R` (env var still wins).

Admin view shows vote counts and mean scores per poster (relevance, co-creation, clarity, overall) plus CSV download.

## Data storage

Votes append to `data/votes.csv` with columns:

`timestamp`, `session_id`, `poster_id`, `score_relevance`, `score_cocreation`, `score_clarity`

On **shinyapps.io**, the filesystem is ephemeral across redeploys/restarts — download votes from the admin page during/after the event, or point storage at a persistent backend if you need long-term retention. On **Posit Connect**, persistent disk depends on your server config.

Double-submit: the same browser session cannot vote twice for the same poster (in-memory flag). Other posters remain available. This is not a cryptographic voter ID.

## Deploy to shinyapps.io

1. Create an account at https://www.shinyapps.io and get a token.
2. Install/configure `rsconnect`:

```r
install.packages("rsconnect")
rsconnect::setAccountInfo(
  name   = "YOUR_ACCOUNT",
  token  = "YOUR_TOKEN",
  secret = "YOUR_SECRET"
)
```

3. Deploy from the app directory (include `app.R`, `config.R`, `posters.csv`; `data/` is created at runtime):

```r
setwd("/path/to/poster-votes")
rsconnect::deployApp(
  appDir = ".",
  appName = "poster-votes",
  appFiles = c("app.R", "config.R", "posters.csv", "data/.gitkeep"),
  forceUpdate = TRUE
)
```

4. Set `VOTE_ADMIN_PASSWORD` in the shinyapps.io dashboard.


## Project layout

```
poster-votes/
├── app.R                 # Shiny UI + server
├── config.R              # admin password, criteria metadata, votes path
├── posters.csv           # poster catalogue
├── data/                 # votes.csv written at runtime
├── qrcodes/              # generated PNGs (via generate_qrcodes.R)
├── generate_qrcodes.R
├── install_packages.R
└── README
```

## License / reuse

Conference tooling — adapt posters and criteria as needed.