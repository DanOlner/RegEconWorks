# Round 2 helpers for the Companies House firm data (test T11). The firm data are read, read-only, from
# the report outputs of the companieshouseopen project (Parquet and RDS files under
# local/reports/*/data/), not from its database. Only aggregate tables are written, to the gitignored
# local/tradeable_jobs/companieshouse/. Nothing at firm level leaves this machine or enters the repo.
#
# Where the reports live: options(tj.ch_reports = '<path>') overrides the default below.
# Needs functions_common.R and functions_io.R (for the sector groups).

suppressPackageStartupMessages(suppressWarnings({
  library(arrow)
  library(fixest)
}))
setFixest_notes(FALSE)

ch_reports <- function() path.expand(getOption('tj.ch_reports', '~/Code/companieshouseopen/local/reports'))
ch_out_dir <- 'local/tradeable_jobs/companieshouse'
ch_available <- function() dir.exists(file.path(ch_reports(), 'gva_spatial', 'data'))
ch_file <- function(report, file) {
  f <- file.path(ch_reports(), report, 'data', file)
  if (!file.exists(f)) stop('Companies House output not found: ', f, call. = FALSE)
  f
}
ch_read <- function(report, file, cols = NULL) {
  if (is.null(cols)) read_parquet(ch_file(report, file)) else read_parquet(ch_file(report, file), col_select = all_of(cols))
}
# The build times of the report outputs used, recorded with every table
ch_builds <- function() {
  b <- function(r) format(readRDS(ch_file(r, 'meta.rds'))$built, '%Y-%m-%d %H:%M')
  c(gva_spatial = b('gva_spatial'), jobs_gva = b('jobs_gva'))
}
ch_write <- function(df, name, builds) {
  dir.create(ch_out_dir, recursive = TRUE, showWarnings = FALSE)
  write_csv(df %>% mutate(ch_gva_spatial_built = builds[['gva_spatial']], ch_jobs_gva_built = builds[['jobs_gva']]),
            file.path(ch_out_dir, name))
  invisible(df)
}

# SIC division to T2's sector groups: io_group_sic2() in functions_io.R
ch_group <- function(sic2) io_group_sic2(sic2)

# The dynamic Olley-Pakes decomposition of Melitz and Polanec (2015), in levels: the change in a group's
# GVA per job (total GVA over total jobs) between periods 1 and 2, split into
#   within  (change in survivors' unweighted mean), between (change in survivors' covariance term),
#   entry   s_E2 * (Phi_E2 - Phi_S2), exit s_X1 * (Phi_S1 - Phi_X1).
# The same definitions as companieshouseopen's analysis/decomposition_functions.R, without its bootstrap.
# d: one row per firm and period, with columns id, period (1 or 2), w (jobs) and y (real GVA).
mp_terms <- function(d) {
  d <- d %>% filter(w > 0, !is.na(y)) %>% mutate(phi = y / w)
  ids <- split(d$id, d$period)
  surv <- intersect(ids[['1']], ids[['2']])
  d <- d %>% mutate(status = case_when(id %in% surv ~ 'S', period == 2 ~ 'E', TRUE ~ 'X'))
  Phi <- function(x) if (nrow(x) == 0) NA_real_ else sum(x$w * x$phi) / sum(x$w)
  p <- function(t, st = NULL) d %>% filter(period == t, is.null(st) | status %in% st)
  S1 <- p(1, 'S'); S2 <- p(2, 'S'); E2 <- p(2, 'E'); X1 <- p(1, 'X')
  cov_term <- function(x) sum((x$w / sum(x$w) - 1 / nrow(x)) * (x$phi - mean(x$phi)))
  s_E2 <- sum(E2$w) / sum(p(2)$w); s_X1 <- sum(X1$w) / sum(p(1)$w)
  tibble(
    n_survivors = length(surv), n_entrants = nrow(E2), n_exiters = nrow(X1),
    jobs_1 = sum(p(1)$w), jobs_2 = sum(p(2)$w), Phi_1 = Phi(p(1)), Phi_2 = Phi(p(2)),
    change = Phi(p(2)) - Phi(p(1)),
    within = if (length(surv)) mean(S2$phi) - mean(S1$phi) else NA_real_,
    between = if (length(surv)) cov_term(S2) - cov_term(S1) else NA_real_,
    entry = if (nrow(E2)) s_E2 * (Phi(E2) - Phi(S2)) else 0,
    exit = if (nrow(X1)) s_X1 * (Phi(S1) - Phi(X1)) else 0) %>%
    mutate(residual = change - within - between - entry - exit)
}

# One clustered regression, as a tidy row per term (companieshouseopen's pt(), with the formula passed in)
ch_reg <- function(d, f) {
  m <- feols(f, d, cluster = ~company_number, warn = FALSE, notes = FALSE)
  ct <- coeftable(m)
  tibble(term = rownames(ct), estimate = ct[, 1], se = ct[, 2], n_links = nobs(m), n_firms = n_distinct(d$company_number))
}
