# Shared functions for the IMD rank uncertainty work
# Write-ups: llm_output/imd_rank_uncertainty_research.md and docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd
# All scripts in this folder run from the project root, like the rest of code/. See README.md here
library(tidyverse)
library(readxl)
# matrixStats is used with matrixStats:: (attaching it would mask dplyr::count)

# Raw downloads go here (local/ is gitignored)
raw_dir <- 'local/imd_raw'

# Results of the slow simulations are cached here, so the report renders quickly (see cached() below)
cache_dir <- 'local/imd_uncertainty/cache'

# Outputs meant for other people (CSV files) go next to the report
output_dir <- 'docs/chunks/imd_uncertainty/outputs'


# CACHING----

# Run expr once and save the result; reuse the saved result until any of the files it depends on change.
# The script that calls it and functions.R are always among the dependencies, so editing either reruns it.
# Set options(imd.refresh = TRUE) to rerun everything (00_run_all.R does this)
# 'key' is anything else the result depends on, such as the number of draws.
# track_functions = FALSE leaves functions.R out, for slow data preparation that doesn't use the method code
cached <- function(name, expr, depends = character(), key = NULL, track_functions = TRUE) {

  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  depends <- unique(c(if (track_functions) 'code/imd_uncertainty/functions.R', depends))
  stamp <- paste(name, paste(tools::md5sum(depends), collapse = ''), paste(key, collapse = ' '))
  path <- file.path(cache_dir, paste0(name, '.rds'))

  if (!isTRUE(getOption('imd.refresh')) && file.exists(path)) {
    saved <- readRDS(path)
    if (identical(saved$stamp, stamp)) return(saved$value)
  }

  message('Running ', name, ' (not cached, or its code changed)')
  # Evaluate in a fresh environment, so the working objects stay out of the session that called it
  value <- eval(substitute(expr), envir = new.env(parent = parent.frame()))
  saveRDS(list(stamp = stamp, value = value), path)
  value
}


# DOWNLOADING----

# Download once and reuse after that.
# Check xlsx files really start with the zip signature 'PK', in case a download failed and saved an error page
get_file <- function(url, filename, dir = raw_dir, check_zip = str_detect(filename, '\\.(xlsx|zip)$')) {

  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  dest <- file.path(dir, filename)

  if (!file.exists(dest)) download.file(url, dest, mode = 'wb', quiet = TRUE)

  if (check_zip && !identical(readBin(dest, 'raw', 2), charToRaw('PK'))) {
    unlink(dest)
    stop('Download of ', filename, ' did not return a zip/xlsx file. Check the URL and rerun.')
  }

  dest
}


# IoD 2025 FILES----

# From https://www.gov.uk/government/statistics/english-indices-of-deprivation-2025
# These are the versions reissued on 17 November 2025 after one LSOA's local authority was corrected
# (E01027305, now West Northamptonshire). MHCLG says files 1 to 9 had no change to the data;
# File 10 (local authority summaries) had minor changes and is the 'v2' file
iod_files <- tribble(
  ~file,    ~filename,                                                                ~url,
  'file6',  'File_6_IoD2025_Population_Denominators.xlsx',                            'https://assets.publishing.service.gov.uk/media/691ded46513046b952c500be/File_6_IoD2025_Population_Denominators.xlsx',
  'file7',  'File_7_IoD2025_All_Ranks_Scores_Deciles_Population_Denominators.csv',   'https://assets.publishing.service.gov.uk/media/691ded56d140bbbaa59a2a7d/File_7_IoD2025_All_Ranks_Scores_Deciles_Population_Denominators.csv',
  'file8',  'File_8_IoD2025_Underlying_Indicators.xlsx',                             'https://assets.publishing.service.gov.uk/media/691dec012c6b98ecdbc500d4/File_8_IoD2025_Underlying_Indicators.xlsx',
  'file9',  'File_9_IoD2025_Transformed_Domain_Scores.xlsx',                         'https://assets.publishing.service.gov.uk/media/691ded670dcbf6343e9a2a6c/File_9_IoD2025_Transformed_Domain_Scores.xlsx',
  'file10', 'File_10_IoD2025_LAD_Summaries_v2.xlsx',                                 'https://assets.publishing.service.gov.uk/media/6917412ebc34c86ce4e6e7fc/File_10_-_IoD2025_Local_Authority_District_Summaries__lower-tier__v2.xlsx'
)

get_iod_file <- function(which_file) {
  f <- filter(iod_files, file == which_file)
  get_file(f$url, f$filename)
}

# The seven domains: short name, File 7 score and rank columns, File 9 transformed score column,
# and the IMD weight (technical report Table 3.1). The weights add to 0.999, as published
domains <- tribble(
  ~domain,      ~file7_score,                                ~file7_rank,                                                          ~file9_exp,                                              ~weight,
  'income',     'Income Score (rate)',                       'Income Rank (where 1 is most deprived)',                             'Income Score - exponentially transformed',              0.225,
  'employment', 'Employment Score (rate)',                   'Employment Rank (where 1 is most deprived)',                         'Employment Score - exponentially transformed',          0.225,
  'education',  'Education, Skills and Training Score',      'Education, Skills and Training Rank (where 1 is most deprived)',     'Education Score - exponentially transformed',           0.135,
  'health',     'Health Deprivation and Disability Score',   'Health Deprivation and Disability Rank (where 1 is most deprived)',  'Health Score - exponentially transformed',              0.135,
  'crime',      'Crime Score',                               'Crime Rank (where 1 is most deprived)',                              'Crime Score - exponentially transformed',               0.093,
  'barriers',   'Barriers to Housing and Services Score',    'Barriers to Housing and Services Rank (where 1 is most deprived)',   'Barriers Score - exponentially transformed',            0.093,
  'living',     'Living Environment Score',                  'Living Environment Rank (where 1 is most deprived)',                 'Living Environment Score - exponentially transformed',  0.093
)

# Size of the most deprived 10% of LSOAs (technical report E.2.2)
n_most_deprived_10 <- 3375

# File 7: one row per LSOA with the IMD and domain scores and ranks (1 = most deprived) and mid-2022 population.
# Domain columns are named e.g. income_score, income_rank
load_iod_ranks <- function() {

  raw <- read_csv(get_iod_file('file7'), show_col_types = FALSE)

  base <- tibble(
    lsoa       = raw[['LSOA code (2021)']],
    lad        = raw[['Local Authority District code (2024)']],
    lad_name   = raw[['Local Authority District name (2024)']],
    imd_score  = raw[['Index of Multiple Deprivation (IMD) Score']],
    imd_rank   = raw[['Index of Multiple Deprivation (IMD) Rank (where 1 is most deprived)']],
    imd_decile = raw[['Index of Multiple Deprivation (IMD) Decile (where 1 is most deprived 10% of LSOAs)']],
    pop        = raw[['Total population: mid 2022']]
  )

  domain_cols <- map(seq_len(nrow(domains)), function(i) {
    tibble(!!paste0(domains$domain[i], '_score') := raw[[domains$file7_score[i]]],
           !!paste0(domains$domain[i], '_rank')  := raw[[domains$file7_rank[i]]])
  })

  bind_cols(base, domain_cols)
}

# File 9: the exponentially transformed domain scores (0 to 100). Columns named e.g. income_exp
load_transformed_scores <- function() {

  raw <- read_excel(get_iod_file('file9'), sheet = 'IoD25 Transformed Domain Scores')

  out <- tibble(lsoa = raw[['LSOA code (2021)']])
  for (i in seq_len(nrow(domains))) out[[paste0(domains$domain[i], '_exp')]] <- raw[[domains$file9_exp[i]]]
  out
}

# File 6: the population denominators (mid-2022, bespoke ONS series including prisoners)
load_population_denominators <- function() {
  read_excel(get_iod_file('file6'), sheet = 'ID 2025 Population Denominators') %>%
    transmute(
      lsoa = `LSOA code (2021)`,
      pop_total = `Total population: mid 2022`,
      pop_children = `Dependent Children aged 0-15: mid 2022`,
      pop_older = `Older population aged 60 and over: mid 2022`,
      pop_working_age = `Working age population 18-66 (for use with Employment Deprivation Domain): mid 2022`
    )
}

# File 8, any domain sheet, as published
load_underlying <- function(sheet) read_excel(get_iod_file('file8'), sheet = sheet)

# File 8: the Income and Employment domain numerators (counts of deprived people).
# Counts under 10 are suppressed (NA) and the rest rounded to the nearest 5, at DWP's request
load_income_numerators <- function() {
  load_underlying('IoD25 Income Domain') %>%
    transmute(lsoa = `LSOA code (2021)`, income_num = `Income Domain numerator`)
}

load_employment_numerators <- function() {
  load_underlying('IoD25 Employment Domain') %>%
    transmute(lsoa = `LSOA code (2021)`, employment_num = `Employment Domain numerator`)
}

# The two count-based domains in long format: one row per LSOA x domain, with the published (shrunk) rate,
# the published count r (NA where suppressed) and the denominator. Where the count is bigger than the
# denominator, the Indices set the denominator to the count (technical report 4.3.22), so do the same
load_count_domains <- function() {

  d <- load_iod_ranks() %>%
    select(lsoa, lad, income_score, employment_score) %>%
    left_join(load_income_numerators(), by = 'lsoa') %>%
    left_join(load_employment_numerators(), by = 'lsoa') %>%
    left_join(load_population_denominators(), by = 'lsoa')

  bind_rows(
    d %>% transmute(domain = 'Income', lsoa, lad, published = income_score, r = income_num,
                    size = pmax(pop_total, income_num, na.rm = TRUE)),
    d %>% transmute(domain = 'Employment', lsoa, lad, published = employment_score, r = employment_num,
                    size = pmax(pop_working_age, employment_num, na.rm = TRUE))
  )
}

# File 10: the IMD local authority summaries (lower tier, 2024 boundaries)
load_lad_summaries <- function() {
  read_excel(get_iod_file('file10'), sheet = 'IMD') %>%
    transmute(
      lad = `Local Authority District code (2024)`,
      lad_name = `Local Authority District name (2024)`,
      avg_rank = `IMD - Average rank`,
      rank_avg_rank = `IMD - Rank of average rank`,
      avg_score = `IMD - Average score`,
      rank_avg_score = `IMD - Rank of average score`,
      prop_10 = `IMD - Proportion of LSOAs in most deprived 10% nationally`,
      rank_prop_10 = `IMD - Rank of proportion of LSOAs in most deprived 10% nationally`
    )
}

# File 10 with all five IMD summary measures, as published
load_lad_summaries_all <- function() {
  read_excel(get_iod_file('file10'), sheet = 'IMD') %>%
    transmute(
      lad = `Local Authority District code (2024)`,
      avg_rank = `IMD - Average rank`, rank_avg_rank = `IMD - Rank of average rank`,
      avg_score = `IMD - Average score`, rank_avg_score = `IMD - Rank of average score`,
      prop_10 = `IMD - Proportion of LSOAs in most deprived 10% nationally`,
      rank_prop_10 = `IMD - Rank of proportion of LSOAs in most deprived 10% nationally`,
      extent = `IMD25 - Extent`, rank_extent = `IMD25 - Rank of extent`,
      local_conc = `IMD25 - Local concentration`, rank_local_conc = `IMD25 - Rank of local concentration`
    )
}

# Extent weights (technical report Appendix M.5): 1 for the most deprived 10% of LSOAs, then falling by
# (0.95 - 0.05) / 19 for each percentile from 0.95 at the 11th to 0.05 at the 30th, and 0 after that.
# Percentile = rank / N x 100, rounded up
extent_weight <- function(rank, n) {
  pctile <- ceiling(rank / n * 100)
  case_when(pctile <= 10 ~ 1, pctile <= 30 ~ 0.95 - (pctile - 11) * (0.9 / 19), TRUE ~ 0)
}

# Population-weighted local authority summaries from LSOA scores and ranks (technical report Table 3.2
# and Appendix M). Ranks: 1 = most deprived. Average rank and local concentration are reported the way
# File 10 does, with ranks reversed (N + 1 - rank, so bigger = more deprived).
# Local concentration: the population-weighted mean reversed rank of the authority's most deprived LSOAs
# that together hold exactly 10% of its population, taking part of the last LSOA where needed.
# Ties in the proportion measure share the lowest rank
lad_summaries <- function(lad, pop, score, rank, n = length(rank)) {
  tibble(lad, pop, score, rank) %>%
    arrange(lad, rank) %>%
    group_by(lad) %>%
    mutate(
      cum_before = cumsum(pop) - pop,
      lc_pop = pmin(pop, pmax(0, 0.1 * sum(pop) - cum_before))
    ) %>%
    summarise(
      avg_score = weighted.mean(score, pop),
      avg_rank = n + 1 - weighted.mean(rank, pop),
      prop_10 = mean(rank <= n_most_deprived_10),
      extent = sum(pop * extent_weight(rank, n)) / sum(pop),
      local_conc = n + 1 - sum(lc_pop * rank) / sum(lc_pop),
      .groups = 'drop'
    ) %>%
    mutate(
      rank_avg_score = rank(-avg_score, ties.method = 'first'),
      rank_avg_rank = rank(-avg_rank, ties.method = 'first'),
      rank_prop_10 = rank(-prop_10, ties.method = 'min'),
      rank_extent = rank(-extent, ties.method = 'min'),
      rank_local_conc = rank(-local_conc, ties.method = 'first')
    )
}

# The same five measures inside a simulation, for many draws at once. Faster than lad_summaries():
# takes integer local authority indexes and returns a matrix of scores, one column per measure.
# 'order_within' must order the LSOAs by authority then by rank, for local concentration
lad_measures_fast <- function(lad_index, pop, score, rank, n_lads, n = length(rank)) {
  lad_pop <- tabulate_weighted(lad_index, pop, n_lads)
  ord <- order(lad_index, rank)
  li <- lad_index[ord]; p <- pop[ord]; rk <- rank[ord]
  cum <- cumsum(p)
  start <- c(0, cum)[match(li, li)]  # cumulative population before each authority's first LSOA
  cum_before <- cum - p - start
  lc_pop <- pmin(p, pmax(0, 0.1 * lad_pop[li] - cum_before))
  cbind(
    avg_score = tabulate_weighted(lad_index, score * pop, n_lads) / lad_pop,
    avg_rank = n + 1 - tabulate_weighted(lad_index, rank * pop, n_lads) / lad_pop,
    prop_10 = tabulate_weighted(lad_index, as.numeric(rank <= n_most_deprived_10), n_lads) / tabulate(lad_index, n_lads),
    extent = tabulate_weighted(lad_index, pop * extent_weight(rank, n), n_lads) / lad_pop,
    local_conc = n + 1 - tabulate_weighted(li, lc_pop * rk, n_lads) / tabulate_weighted(li, lc_pop, n_lads)
  )
}

tabulate_weighted <- function(index, w, n) {
  out <- numeric(n)
  s <- rowsum(w, index, reorder = TRUE)
  out[as.integer(rownames(s))] <- s[, 1]
  out
}

# Rank of each measure across authorities (1 = most deprived = biggest value).
# Ties share the lowest rank for the two threshold measures, which have many ties at zero
rank_lad_measures <- function(m) {
  cbind(
    avg_score = rank(-m[, 'avg_score'], ties.method = 'first'),
    avg_rank = rank(-m[, 'avg_rank'], ties.method = 'first'),
    prop_10 = rank(-m[, 'prop_10'], ties.method = 'min'),
    extent = rank(-m[, 'extent'], ties.method = 'min'),
    local_conc = rank(-m[, 'local_conc'], ties.method = 'first')
  )
}

lad_measure_labels <- c(
  avg_score = 'Average score', avg_rank = 'Average rank', prop_10 = 'Proportion of LSOAs in the most deprived 10%',
  extent = 'Extent', local_conc = 'Local concentration'
)


# IoD METHOD----

# Exponential transform of a rank (technical report Appendix E).
# Takes ranks with 1 = most deprived, as published, and scales them to R in (0, 1],
# with R = 1/N for the least deprived and R = 1 for the most deprived.
# Returns 0 (least deprived) to 100 (most deprived); the most deprived 10% get 50 to 100
exp_transform <- function(rank_most_deprived_first, n = length(rank_most_deprived_first)) {
  R <- (n - rank_most_deprived_first + 1) / n
  -23 * log(1 - R * (1 - exp(-100 / 23)))
}

# Variance of the empirical logit log((r + 0.5) / (n - r + 0.5)) for r events out of n
# (technical report Appendix C, used in the shrinkage step)
logit_var <- function(r, n) (n + 1) * (n + 2) / (n * (r + 1) * (n - r + 1))


# SHRINKAGE----

# The empirical logit, and its inverse: the count r that gives empirical logit m out of size
emp_logit <- function(r, size) log((r + 0.5) / (size - r + 0.5))
emp_logit_count <- function(m, size) (exp(m) * (size + 0.5) - 0.5) / (1 + exp(m))

# The IoD shrinkage step (technical report Appendix C), for r events out of size in each LSOA,
# shrinking towards the pooled rate of each LSOA's parent group.
# Returns, per LSOA: the raw logit m and its variance s2, the group logit M and between-LSOA variance t2,
# the weight w on the LSOA's own data, the shrunk logit and rate, and post_var = w * s2.
# post_var is the usual empirical Bayes posterior variance of the shrunk logit. It ignores the
# uncertainty in M and t2, and the report doesn't state it - it's my reading of the method.
# Groups with one LSOA can't be shrunk (report 3.4.4), so they keep w = 1
shrink_iod <- function(r, size, group) {
  tibble(r, size, group) %>%
    group_by(group) %>%
    mutate(
      m = emp_logit(r, size),
      s2 = logit_var(r, size),
      M = emp_logit(sum(r), sum(size)),
      k = length(r),
      t2 = if (length(r) > 1) sum((m - M)^2) / (length(r) - 1) else NA_real_,
      w = if_else(k > 1, (1 / s2) / (1 / s2 + 1 / t2), 1),
      m_shrunk = w * m + (1 - w) * M
    ) %>%
    ungroup() %>%
    transmute(m, s2, M, t2, w, m_shrunk, rate_shrunk = plogis(m_shrunk), post_var = w * s2)
}

# Run the shrinkage backwards: given published shrunk rates, their denominators and parent groups,
# find the raw counts that the shrinkage step would turn into those rates.
# Within each group this iterates the shrinkage equations (damped fixed point) until they balance.
# Returns the recovered count and raw logit, s2, w and post_var per LSOA, in the input order
invert_shrinkage <- function(rate_shrunk, size, group, max_iter = 2000, tol = 1e-7) {
  tibble(id = seq_along(rate_shrunk), rate_shrunk, size, group) %>%
    group_by(group) %>%
    group_modify(~ invert_one_group(.x, max_iter, tol)) %>%
    ungroup() %>%
    arrange(id) %>%
    select(-id, -group)
}

invert_one_group <- function(g, max_iter, tol) {

  k <- nrow(g)
  lowest <- emp_logit(0, g$size)
  highest <- emp_logit(g$size, g$size)
  m_star <- pmin(pmax(qlogis(g$rate_shrunk), lowest), highest)
  m <- m_star
  converged <- TRUE

  if (k > 1) {
    converged <- FALSE
    for (i in seq_len(max_iter)) {
      r <- emp_logit_count(m, g$size)
      s2 <- logit_var(r, g$size)
      M <- emp_logit(sum(r), sum(g$size))
      t2 <- sum((m - M)^2) / (k - 1)
      w <- (1 / s2) / (1 / s2 + 1 / t2)
      m_new <- pmin(pmax((m_star - (1 - w) * M) / w, lowest), highest)
      m_new <- 0.5 * m + 0.5 * m_new
      done <- max(abs(m_new - m)) < tol
      m <- m_new
      if (done) {
        converged <- TRUE
        break
      }
    }
  }

  r <- emp_logit_count(m, g$size)
  s2 <- logit_var(r, g$size)
  if (k > 1) {
    M <- emp_logit(sum(r), sum(g$size))
    t2 <- sum((m - M)^2) / (k - 1)
    w <- (1 / s2) / (1 / s2 + 1 / t2)
  } else {
    w <- 1
  }

  tibble(id = g$id, r_recovered = r, m_recovered = m, s2 = s2, w = w, post_var = w * s2, converged = converged)
}


# RANK HELPERS----

# Rank-based normal score, as the Indices use to standardise indicators before combining them
# (technical report 3.5 and Appendix D). The report doesn't give the formula. qnorm(rank / (N + 1)), with
# tied values sharing their average rank, is the one that rebuilds the published Health domain score to
# within its rounding (10_stage4_rebuild.R). Higher values = more deprived, so pass the indicator so that
# bigger means more deprived
normal_score <- function(x) {
  r <- rank(x, ties.method = 'average', na.last = 'keep')
  qnorm(r / (sum(!is.na(x)) + 1))
}

# Published values are rounded (rates to 3 decimal places), so many LSOAs share a value even though the
# published rank orders them. Spread each group of tied values evenly across its rounding interval, in the
# order of the published rank (1 = most deprived = highest value), so that ranking the result gives back
# the published rank exactly. Used to centre simulations on the published ranking
# For rates, pass bounds = c(0, 1) so the interval stays inside 0 to 1
untie_by_rank <- function(value, published_rank, step = 0.001, bounds = c(-Inf, Inf)) {
  tibble(value, published_rank, id = seq_along(value)) %>%
    group_by(value) %>%
    mutate(
      k = n(),
      j = rank(published_rank, ties.method = 'first'),
      upper = pmin(value + step / 2, bounds[2]),
      lower = pmax(value - step / 2, bounds[1]),
      untied = upper - (j - 0.5) / k * (upper - lower)
    ) %>%
    ungroup() %>%
    arrange(id) %>%
    pull(untied)
}

# Row quantiles of a draws matrix (rows = areas, columns = draws). Type 1 keeps ranks whole numbers
row_quantiles <- function(m, probs) matrixStats::rowQuantiles(m, probs = probs, type = 1L, drop = FALSE)


# STAGE 4: INDICATORS TO DOMAINS----

# Rebuilds of the within-domain combinations (technical report chapter 4), from indicator values in
# File 8 form. Each takes a data frame with the File 8 columns (or perturbed versions of them) and returns
# the domain or sub-domain score. Checked against the published scores in 10_stage4_rebuild.R
crime_weights <- c(
  "Violence with injury, rate per 1,000 'at-risk population'" = 0.151,
  "Violence without injury, rate per 1,000 'at-risk population'" = 0.154,
  "Stalking and harassment, rate per 1,000 'at-risk population'" = 0.132,
  "Burglary, rate per 1,000 'at-risk properties'" = 0.074,
  "Theft, rate per 1,000 'at-risk population'" = 0.097,
  "Criminal damage, rate per 1,000 'at-risk population'" = 0.144,
  "Public order and Possession of weapons, rate per 1,000 'at-risk population'" = 0.145,
  "Anti-Social Behaviour, rate per 1,000 'at-risk population'" = 0.103
)

build_crime <- function(d) {
  as.vector(sapply(names(crime_weights), function(v) normal_score(d[[v]])) %*% crime_weights)
}

build_health <- function(d) {
  0.294 * normal_score(d[['Comparative illness and disability ratio indicator']]) +
    0.240 * normal_score(d[['Years of potential life lost indicator']]) +
    0.222 * normal_score(d[['Acute morbidity indicator']]) +
    0.244 * normal_score(d[['Mental health indicator']])
}

# Wider barriers: the SUM of five normal scores, each composite item re-standardised first
# (found by fitting, 10_stage4_rebuild.R; the report says 'equal weights')
build_wider_barriers <- function(d) {
  normal_score(d[['Housing affordability indicator']]) +
    normal_score(normal_score(d[['Household overcrowding indicator (rooms)']]) + normal_score(d[['Household overcrowding indicator (bedrooms)']])) +
    normal_score(normal_score(d[['Core homelessness rate (% of households)']]) + normal_score(d[['Homelessness indicator (rate per 1,000 households)']])) +
    normal_score(d[['Digital Connectivity (Broadband download and upload speeds)']]) +
    normal_score(d[['Patient-to-GP Ratio']])
}

build_housing_affordability <- function(d) {
  (normal_score(d[['Owner-occupation affordability (component of housing affordability indicator)']]) +
     normal_score(d[['Private rental affordability (component of housing affordability indicator)']])) / 2
}

build_indoors <- function(d) {
  (normal_score(d[['Housing in poor condition indicator']]) +
     normal_score(d[['Housing energy performance deprivation Score']]) +
     normal_score(d[['Housing lacking private outdoor space deprivation score']])) / 3
}

build_outdoors <- function(d) {
  (normal_score(d[['Air quality indicator']]) +
     normal_score(d[['Road traffic casualties involving injury to pedestrians and cyclists']]) +
     normal_score(d[['Noise pollution']])) / 3
}

# Two sub-domains, each ranked and exponentially transformed, then combined with weights
combine_subdomains <- function(score_a, score_b, weight_a) {
  weight_a * exp_transform(rank(-score_a, ties.method = 'first')) +
    (1 - weight_a) * exp_transform(rank(-score_b, ties.method = 'first'))
}


# OTHER OPEN DATA----

# IoD 2019 Files 6 to 8 (2011 LSOAs), for testing the shrinkage rebuild where the parent group is known
iod2019_files <- tribble(
  ~file,    ~filename,                                                                   ~url,
  'file6',  'File_6_-_IoD2019_Population_Denominators.xlsx',                            'https://assets.publishing.service.gov.uk/media/5d8b3b60ed915d0373d35411/File_6_-_IoD2019_Population_Denominators.xlsx',
  'file7',  'File_7_-_All_IoD2019_Scores__Ranks__Deciles_and_Population_Denominators_3.csv', 'https://assets.publishing.service.gov.uk/media/5dc407b440f0b6379a7acc8d/File_7_-_All_IoD2019_Scores__Ranks__Deciles_and_Population_Denominators_3.csv',
  'file8',  'File_8_-_IoD2019_Underlying_Indicators.xlsx',                              'https://assets.publishing.service.gov.uk/media/5d8b3cd740f0b609909b590a/File_8_-_IoD2019_Underlying_Indicators.xlsx'
)

get_iod2019_file <- function(which_file) {
  f <- filter(iod2019_files, file == which_file)
  get_file(f$url, f$filename, dir = file.path(raw_dir, 'iod2019'))
}

# DfT road safety open data (STATS19), one file per year and table
get_stats19 <- function(table, year) {
  fname <- paste0('dft-road-casualty-statistics-', table, '-', year, '.csv')
  get_file(paste0('https://data.dft.gov.uk/road-accidents-safety-data/', fname), fname, dir = file.path(raw_dir, 'stats19'))
}

# 2021 LSOA boundaries for England (ONS Open Geography Portal, generalised to 20 m, clipped to the coast),
# in British National Grid. Downloaded in pages of 2,000 and saved once as a geopackage
get_lsoa_boundaries <- function() {
  dest <- file.path(raw_dir, 'lsoa2021_bgc_england.gpkg')
  if (!file.exists(dest)) {
    base <- 'https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/Lower_layer_Super_Output_Areas_December_2021_Boundaries_EW_BGC_V5/FeatureServer/0/query'
    pages <- map(seq(0, 36000, by = 2000), function(offset) {
      url <- paste0(base, "?where=LSOA21CD%20LIKE%20'E%25'&outFields=LSOA21CD&outSR=27700&f=geojson&orderByFields=FID",
                    '&resultOffset=', offset, '&resultRecordCount=2000')
      tmp <- tempfile(fileext = '.geojson')
      download.file(url, tmp, quiet = TRUE)
      g <- sf::st_read(tmp, quiet = TRUE)
      if (nrow(g) == 0) return(NULL)
      sf::st_set_crs(g, 27700)  # the service returns British National Grid when asked; geojson drops the label
    })
    b <- do.call(rbind, compact(pages))
    stopifnot(!anyDuplicated(b$LSOA21CD))
    sf::st_write(b, dest, quiet = TRUE)
  }
  sf::st_read(dest, quiet = TRUE)
}

# Census 2021 topic summary tables at LSOA level, from the Nomis bulk downloads
get_census_lsoa <- function(table) {
  zip <- get_file(paste0('https://www.nomisweb.co.uk/output/census/2021/census2021-', table, '.zip'),
                  paste0('census2021-', table, '.zip'), dir = file.path(raw_dir, 'census2021'))
  inner <- paste0('census2021-', table, '-lsoa.csv')
  read_csv(unz(zip, inner), show_col_types = FALSE)
}

# Business Register and Employment Survey (open access, rounded): total employment by 2021 LSOA in England,
# from the Nomis API. Used as a rough stand-in for the workplace population in the road casualty denominator
get_bres_lsoa <- function(year) {
  dest <- file.path(raw_dir, paste0('bres_employment_lsoa2021_', year, '.csv'))
  if (!file.exists(dest)) {
    pages <- map(c(0, 25000), function(offset) {
      url <- paste0('https://www.nomisweb.co.uk/api/v01/dataset/NM_189_1.data.csv?geography=2092957699TYPE151',
                    '&date=', year, '&industry=37748736&employment_status=4&measure=1&measures=20100',
                    '&select=geography_code,obs_value&recordoffset=', offset, '&recordlimit=25000')
      read_csv(url, show_col_types = FALSE)
    })
    write_csv(bind_rows(pages), dest)
  }
  read_csv(dest, show_col_types = FALSE) %>% rename(lsoa = GEOGRAPHY_CODE, employment = OBS_VALUE)
}


# MONTE CARLO HELPERS----

# Simulate IMD ranks when only the Income and Employment domains carry error.
# centre_*: each LSOA's published rate on the logit scale (untied, see untie_by_rank());
# sd_*: its standard error on the logit scale; rho: correlation between the two domains' errors in an LSOA
# (one number or one per LSOA); fixed_part: the weighted sum of the other five transformed domains.
# Returns IMD ranks (if keep_ranks), Income and Employment domain rank quantiles, and the five local
# authority measures (values and ranks) for every draw
simulate_two_domains <- function(centre_income, sd_income, centre_employment, sd_employment, rho,
                                 fixed_part, lad_index, pop, n_draws, seed, keep_ranks = TRUE) {
  set.seed(seed)
  N <- length(centre_income)
  n_lads <- max(lad_index)
  w_inc <- domains$weight[domains$domain == 'income']
  w_emp <- domains$weight[domains$domain == 'employment']
  rho <- rep_len(rho, N)

  imd_ranks <- if (keep_ranks) matrix(0L, N, n_draws) else NULL
  income_ranks <- employment_ranks <- if (keep_ranks) matrix(0L, N, n_draws) else NULL
  lad_values <- array(0, c(n_lads, 5, n_draws), dimnames = list(NULL, names(lad_measure_labels), NULL))
  lad_ranks <- array(0L, c(n_lads, 5, n_draws), dimnames = list(NULL, names(lad_measure_labels), NULL))
  top10 <- numeric(N)

  for (d in seq_len(n_draws)) {
    z1 <- rnorm(N)
    z2 <- rho * z1 + sqrt(1 - rho^2) * rnorm(N)
    inc_rank <- rank(-(centre_income + sd_income * z1), ties.method = 'random')
    emp_rank <- rank(-(centre_employment + sd_employment * z2), ties.method = 'random')
    score <- w_inc * exp_transform(inc_rank) + w_emp * exp_transform(emp_rank) + fixed_part
    rk <- rank(-score, ties.method = 'first')
    if (keep_ranks) {
      imd_ranks[, d] <- rk
      income_ranks[, d] <- inc_rank
      employment_ranks[, d] <- emp_rank
    }
    top10 <- top10 + (rk <= n_most_deprived_10)
    m <- lad_measures_fast(lad_index, pop, score, rk, n_lads)
    lad_values[, , d] <- m
    lad_ranks[, , d] <- rank_lad_measures(m)
  }

  list(imd_ranks = imd_ranks, income_ranks = income_ranks, employment_ranks = employment_ranks,
       p_top10 = top10 / n_draws, lad_values = lad_values, lad_ranks = lad_ranks)
}

# How far apart in the published ranking two LSOAs need to be before the more deprived one stays ahead.
# For each probe LSOA and each gap, the share of draws in which the probe ranks above each of the 21 LSOAs
# published closest to (probe rank + gap), averaged over those 21. Averaging over neighbours smooths out the
# noise of testing a single partner LSOA at each gap
separation_curves <- function(rank_draws, published_rank, probe_ranks, gaps, half_window = 10) {
  by_rank <- order(published_rank)
  N <- length(by_rank)
  map_dfr(probe_ranks, function(rk) {
    a <- rank_draws[by_rank[rk], ]
    p <- map_dbl(gaps, function(g) {
      partners <- by_rank[pmin(pmax(rk + g + (-half_window:half_window), 1), N)]
      m <- rank_draws[partners, , drop = FALSE]
      mean(m > rep(a, each = nrow(m)))
    })
    tibble(probe_rank = rk, gap = gaps, p_order_holds = p)
  })
}

# The smallest gap at which the order holds in at least 'level' of draws, at that gap and all larger ones tested
gap_needed <- function(gap, p, level = 0.95) {
  ok <- rev(cumprod(rev(p >= level))) == 1
  if (!any(ok)) NA_real_ else min(gap[ok])
}
