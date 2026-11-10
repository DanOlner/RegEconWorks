# Shared functions for the IMD rank uncertainty work
# Write-ups: llm_output/imd_rank_uncertainty_research.md and docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd
# All scripts in this folder run from the project root, like the rest of code/
library(tidyverse)
library(readxl)

# Raw downloads go here (local/ is gitignored)
raw_dir <- 'local/imd_raw'


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

# Population-weighted local authority summaries from LSOA scores and ranks (technical report Table 3.2).
# Ranks: 1 = most deprived. Ties in the proportion measure share the lowest rank
lad_summaries <- function(lad, pop, score, rank) {
  tibble(lad, pop, score, rank) %>%
    group_by(lad) %>%
    summarise(
      avg_score = weighted.mean(score, pop),
      avg_rank = weighted.mean(rank, pop),
      prop_10 = mean(rank <= n_most_deprived_10),
      .groups = 'drop'
    ) %>%
    mutate(
      rank_avg_score = rank(-avg_score, ties.method = 'first'),
      rank_avg_rank = rank(avg_rank, ties.method = 'first'),
      rank_prop_10 = rank(-prop_10, ties.method = 'min')
    )
}


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
