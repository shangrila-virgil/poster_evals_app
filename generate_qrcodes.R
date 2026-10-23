#!/usr/bin/env Rscript
# Generate PNG QR codes for each poster deep-link.
#
# Usage:
#   Rscript generate_qrcodes.R https://yourname.shinyapps.io/poster-votes/
#   Rscript generate_qrcodes.R https://yourname.shinyapps.io/poster-votes/ ./qrcodes
#
# Requires package: qrcode  (install via install_packages.R)

`%||%` <- function(a, b) if (!is.null(a)) a else b

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) {
  stop(
    "Usage: Rscript generate_qrcodes.R <base_url> [output_dir]\n",
    "Example: Rscript generate_qrcodes.R https://you.shinyapps.io/poster-votes/",
    call. = FALSE
  )
}

base_url <- sub("/+$", "", args[[1]])
out_dir <- if (length(args) >= 2L) args[[2]] else "qrcodes"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# Locate posters.csv next to this script or in the working directory
ca <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", ca, value = TRUE)
script_dir <- if (length(file_arg)) {
  dirname(normalizePath(sub("^--file=", "", file_arg)))
} else {
  getwd()
}
posters_file <- file.path(script_dir, "posters.csv")
if (!file.exists(posters_file)) posters_file <- file.path(getwd(), "posters.csv")
if (!file.exists(posters_file)) stop("Cannot find posters.csv")

posters <- read.csv(posters_file, stringsAsFactors = FALSE, fileEncoding = "UTF-8")

if (!requireNamespace("qrcode", quietly = TRUE)) {
  stop("Package 'qrcode' is required. Run: source('install_packages.R')", call. = FALSE)
}

make_qr_matrix <- function(url) {
  ns <- asNamespace("qrcode")
  if (exists("qr_code", envir = ns, inherits = FALSE)) {
    qrcode::qr_code(url)
  } else {
    qrcode::qrcode(url)
  }
}

write_qr_png <- function(url, path, px = 512) {
  obj <- make_qr_matrix(url)
  grDevices::png(path, width = px, height = px, res = 120)
  on.exit(grDevices::dev.off(), add = TRUE)
  # qrcode objects have a plot method; plain matrices use image()
  if (inherits(obj, c("qr_code", "qrcode"))) {
    plot(obj)
  } else if (is.matrix(obj)) {
    op <- par(mar = rep(0, 4))
    on.exit(par(op), add = TRUE)
    image(
      t(obj[nrow(obj):1, , drop = FALSE]),
      col = c("white", "black"),
      axes = FALSE, xlab = "", ylab = ""
    )
  } else {
    plot(obj)
  }
}

# Normalize URL joining (avoid double slashes except after scheme)
join_url <- function(base, query) {
  paste0(base, "/?", sub("^\\?", "", query))
}

manifest <- data.frame(
  poster_id = character(0),
  url = character(0),
  file = character(0),
  stringsAsFactors = FALSE
)

for (i in seq_len(nrow(posters))) {
  pid <- posters$id[[i]]
  url <- join_url(base_url, paste0("poster=", pid))
  fname <- file.path(out_dir, paste0(pid, ".png"))
  message("Writing ", fname, " -> ", url)
  write_qr_png(url, fname)
  manifest <- rbind(
    manifest,
    data.frame(poster_id = pid, url = url, file = normalizePath(fname), stringsAsFactors = FALSE)
  )
}

manifest_path <- file.path(out_dir, "manifest.csv")
write.csv(manifest, manifest_path, row.names = FALSE)
message("Done. Wrote ", nrow(manifest), " QR codes. Manifest: ", manifest_path)
