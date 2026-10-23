#!/usr/bin/env Rscript
# Install packages needed by the poster voting app and QR generator.
# Run once:  Rscript install_packages.R

user_lib <- file.path(Sys.getenv("HOME"), "R", "library")
dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(user_lib, .libPaths()))

pkgs <- c(
  "shiny",
  "bslib",
  "shinyjs",
  "DT",
  "qrcode",      # for generate_qrcodes.R
  "rsconnect"    # optional: deploy to shinyapps.io
)

repos <- getOption("repos")
if (is.null(repos) || identical(unname(repos["CRAN"]), "@CRAN@")) {
  options(repos = c(CRAN = "https://cloud.r-project.org"))
}

message("Library: ", user_lib)
message("Installing: ", paste(pkgs, collapse = ", "))
# dependencies = NA => Depends/Imports/LinkingTo only (faster, fewer Suggests)
install.packages(pkgs, dependencies = NA, lib = user_lib)

ok <- vapply(pkgs, requireNamespace, quietly = TRUE, FUN.VALUE = logical(1))
print(ok)
if (!all(ok)) {
  stop(
    "Some packages failed to install: ", paste(names(ok)[!ok], collapse = ", "),
    "\nOn Debian/Ubuntu you may need: sudo apt-get install libcurl4-openssl-dev libssl-dev",
    call. = FALSE
  )
}
message("All packages ready.")
