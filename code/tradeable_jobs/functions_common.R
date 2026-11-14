# Shared helpers for the tradeable jobs pipeline. Base R plus dplyr, tidyr, readr, readxl, ggplot2.
# Run scripts from the repo root.

suppressPackageStartupMessages(suppressWarnings({  # warnings here are only "built under R 4.5.2"
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
}))

tj_cache_dir  <- 'local/tradeable_jobs/cache'
tj_raw_dir    <- 'local/tradeable_jobs/data_raw'
tj_output_dir <- 'docs/chunks/tradeable_jobs/outputs'
for (d in c(tj_cache_dir, tj_raw_dir, tj_output_dir)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

# Cache a slow result. The stamp is the name, the md5 of the files it depends on (this file and the
# calling script's function files by default) and an optional key, so editing any of them reruns it.
# options(tj.refresh = TRUE) forces a rerun of everything.
tj_cached <- function(name, expr, depends = character(), key = NULL) {
  depends <- unique(c('code/tradeable_jobs/functions_common.R', depends))
  stamp <- paste(name, paste(tools::md5sum(depends), collapse = ''), paste(key, collapse = ' '))
  path <- file.path(tj_cache_dir, paste0(name, '.rds'))
  if (!isTRUE(getOption('tj.refresh')) && file.exists(path)) {
    saved <- readRDS(path)
    if (identical(saved$stamp, stamp)) return(saved$value)
  }
  message('Running ', name, ' (not cached, or its code changed)')
  value <- eval(substitute(expr), envir = new.env(parent = parent.frame()))
  saveRDS(list(stamp = stamp, value = value), path)
  value
}

# Download once, reuse after. Fails loudly if the file looks like an error page rather than data.
tj_get_file <- function(url, filename, dir = tj_raw_dir, expect = c('any', 'zip', 'csv', 'xls')) {
  expect <- match.arg(expect)
  dest <- file.path(dir, filename)
  if (!file.exists(dest)) {
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    status <- system2('curl', c('-sL', '--max-time', '300', '-A', shQuote('Mozilla/5.0 (research script)'),
                                '-o', shQuote(dest), shQuote(url)))
    if (status != 0) { unlink(dest); stop('Download failed: ', url) }
  }
  head <- readBin(dest, 'raw', 8)
  ok <- switch(expect,
               any = TRUE,
               zip = identical(head[1:2], as.raw(c(0x50, 0x4b))),
               xls = identical(head[1:2], as.raw(c(0x50, 0x4b))) || identical(head[1:4], as.raw(c(0xd0, 0xcf, 0x11, 0xe0))),
               csv = !grepl('<html|<!DOCTYPE', rawToChar(readBin(dest, 'raw', 200)), ignore.case = TRUE))
  if (!ok) { unlink(dest); stop('Downloaded file is not the expected type (error page?): ', url) }
  dest
}

# Sample skewness (the moment estimator, as in Stata's summarize, detail)
tj_skew <- function(x) { x <- x[is.finite(x)]; m <- mean(x); mean((x - m)^3) / mean((x - m)^2)^1.5 }

# Write a table to the outputs folder and return it invisibly
tj_write <- function(df, name) { write_csv(df, file.path(tj_output_dir, name)); invisible(df) }

tj_theme <- function() theme_minimal(base_size = 11) + theme(panel.grid.minor = element_blank(), legend.position = 'bottom')
