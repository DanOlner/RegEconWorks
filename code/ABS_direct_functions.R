# Functions for reading and wrangling the Annual Business Survey (ABS) regional files
# Used by code/ABS_direct_dataprep.R
# Background and checks behind the choices here: llm_output/abs_direct_uncertainty_planner.md
library(tidyverse)
library(readxl)

# The four variables the ABS publishes at ITL1, in the order they appear in the files
abs_vars <- c('turnover', 'aGVA', 'purchases', 'employment_costs')


# DOWNLOADING----

# Download once into local/abs_raw (gitignored) and reuse after that.
# ONS rate-limits repeated requests: Cloudflare error 1015 comes back as a tiny text file,
# so check we actually got an xlsx (which is a zip archive starting with 'PK')
get_abs_file <- function(url, filename, dir = 'local/abs_raw') {

  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  dest <- file.path(dir, filename)

  if (!file.exists(dest)) download.file(url, dest, mode = 'wb', quiet = TRUE)

  if (!identical(readBin(dest, 'raw', 2), charToRaw('PK'))) {
    unlink(dest)
    stop('Download of ', filename, ' did not return an xlsx file (ONS rate limit?). Wait a few minutes and rerun.')
  }

  dest
}


# Release date from the cover sheet, e.g. "Publication Date: 4 June 2026" or "Release Date: 24 June 2024"
get_abs_release_date <- function(path) {

  cover <- suppressMessages(read_excel(path, sheet = 1, col_names = FALSE, col_types = 'text'))
  txt <- str_subset(unlist(cover), regex('Publication Date|Release Date', ignore_case = TRUE))[1]

  str_squish(str_remove(txt, regex('.*(Publication|Release) Date\\s*:?', ignore_case = TRUE)))
}


# READING----

# Header row position varies a little between editions, so find it by looking for the 'Year' column
find_header_row <- function(raw) {
  which(apply(raw, 1, function(r) any(str_trim(r) == 'Year', na.rm = TRUE)))[1]
}


# Values file ("regional results: Sections A to S"). Reads every per-geography sheet.
# The 2024 edition also has an 'All Regions' sheet, but older editions don't,
# so reading per-geography sheets works for every edition back to at least 2022.
# Returns long format: one row per SIC x geography x year x variable.
# Non-numeric cells ([c] confidential, [low] below half the rounding unit, [x] not available)
# become NA in value, with the marker kept in value_flag.
read_abs_values <- function(path) {

  sheets <- setdiff(excel_sheets(path), c('Cover Sheet', 'Cover sheet', 'Contents', 'Notes', 'All Regions'))

  map(sheets, function(s) {

    raw <- suppressMessages(read_excel(path, sheet = s, col_names = FALSE, col_types = 'text'))
    hr <- find_header_row(raw)
    if (is.na(hr)) return(NULL)

    raw <- raw[(hr + 1):nrow(raw), 1:9]
    names(raw) <- c('SIC_raw', 'SIC_description', 'ITL_code', 'Region_name', 'year', abs_vars)

    raw %>% filter(!is.na(year))

  }) %>%
    bind_rows() %>%
    mutate(
      year = as.numeric(year),
      SIC_description = str_squish(SIC_description)
    ) %>%
    pivot_longer(all_of(abs_vars), names_to = 'variable', values_to = 'value_raw') %>%
    mutate(
      value = suppressWarnings(as.numeric(value_raw)),
      value_flag = ifelse(is.na(value), value_raw, NA_character_)
    ) %>%
    select(-value_raw)
}


# Quality measures file: standard errors and coefficients of variation, 2012 onwards.
# Single sheet. Columns 14-15 are empty in the 2024 edition so only take 1-13.
# Published CoV is kept only for checking: we recompute it as SE/value.
read_abs_quality <- function(path, sheet = 'Section Division by Region') {

  raw <- suppressMessages(read_excel(path, sheet = sheet, col_names = FALSE, col_types = 'text'))
  hr <- find_header_row(raw)

  raw <- raw[(hr + 1):nrow(raw), 1:13]
  names(raw) <- c('SIC_raw', 'SIC_description', 'ITL_code', 'Region_name', 'year',
                  paste0('SE_', abs_vars), paste0('CoVpub_', abs_vars))

  raw %>%
    filter(!is.na(year)) %>%
    mutate(year = as.numeric(year)) %>%
    pivot_longer(
      c(starts_with('SE_'), starts_with('CoVpub_')),
      names_to = c('.value', 'variable'),
      names_pattern = '^(SE|CoVpub)_(.*)$'
    ) %>%
    mutate(
      SE_num = suppressWarnings(as.numeric(SE)),
      SE_flag = ifelse(is.na(SE_num), SE, NA_character_),
      SE = SE_num,
      CoV_published = suppressWarnings(as.numeric(CoVpub))
    ) %>%
    select(-SE_num, -CoVpub, -SIC_description, -Region_name)
}


# SECTOR CODES----

# Division -> section letter (SIC 2007). No section K in the ABS.
division_to_section <- function(division) {

  # case_when evaluates this for every row, including section letters, so silence the NA coercion
  d <- suppressWarnings(as.numeric(division))

  case_when(
    d <= 3 ~ 'A', d <= 9 ~ 'B', d <= 33 ~ 'C', d <= 35 ~ 'D', d <= 39 ~ 'E',
    d <= 43 ~ 'F', d <= 47 ~ 'G', d <= 53 ~ 'H', d <= 56 ~ 'I', d <= 63 ~ 'J',
    d <= 68 ~ 'L', d <= 75 ~ 'M', d <= 82 ~ 'N', d <= 85 ~ 'P', d <= 88 ~ 'Q',
    d <= 93 ~ 'R', d <= 96 ~ 'S'
  )
}


# Make SIC codes joinable across the values and quality files, and across editions.
# The two files spell the aggregates differently ('A to S (Exc K)' vs 'A-S (Exc K)', 'B to E' vs 'B-E').
# level: total (A-S), aggregate (B-E, H-S), section (single letter) or division (two-digit)
# partial_coverage: A, 01, P and Q only cover part of the section/division (private provision etc.)
harmonise_abs_sic <- function(df) {

  df %>%
    mutate(
      SIC_raw = str_squish(SIC_raw),
      partial_coverage = str_detect(SIC_raw, regex('part', ignore_case = TRUE)),
      level = case_when(
        str_detect(SIC_raw, '^\\d{2}') ~ 'division',
        str_detect(SIC_raw, '^A( to |-)S') ~ 'total',
        str_detect(SIC_raw, '^(B( to |-)E|H( to |-)S)') ~ 'aggregate',
        str_detect(SIC_raw, '^[A-S]\\b') ~ 'section'
      ),
      SIC_code = case_when(
        level == 'division' ~ str_sub(SIC_raw, 1, 2),
        level %in% c('total', 'aggregate') ~ str_replace(str_extract(SIC_raw, '^[A-S]( to |-)[A-S]'), ' to ', '-'),
        level == 'section' ~ str_sub(SIC_raw, 1, 1)
      ),
      section = case_when(
        level == 'division' ~ division_to_section(SIC_code),
        level == 'section' ~ SIC_code
      )
    )
}


# Sections D, L and P are single divisions (35, 68, 85) that the ABS publishes only as section rows.
# Copy them down as division rows so the division level is a complete partition of the A-S total.
# (Real estate alone is a big chunk of aGVA - without this, division-level sums and LQs miss it.)
single_division_sections <- c(D = '35', L = '68', P = '85')

add_single_division_sections <- function(df) {

  extra <- df %>%
    filter(level == 'section', SIC_code %in% names(single_division_sections)) %>%
    mutate(
      level = 'division',
      section = SIC_code,
      SIC_code = unname(single_division_sections[SIC_code])
    ) %>%
    # In case a future edition publishes these divisions directly
    anti_join(df %>% filter(level == 'division'), by = c('ITL_code', 'SIC_code', 'year', 'variable'))

  bind_rows(df, extra)
}


# SUPPRESSED REMAINDER PSEUDO-SECTORS----

# About 18% of division x region aGVA cells are suppressed ([c]), so summing the visible
# divisions undercounts every regional and national total. Section and whole-economy totals
# are (almost always) published, so the suppressed amount can be recovered as a remainder:
#
# 1. Section remainder: published section value minus its visible divisions,
#    for sections that are published but have at least one suppressed division.
# 2. Whole-economy remainder: what's left of the A-S total once published sections and the visible
#    divisions of suppressed sections are accounted for. Only created where a section is suppressed.
#
# Remainders make totals right; they are not estimates of individual hidden cells.
# Estimating hidden cells from neighbouring years was tested and rejected (too often no neighbour,
# too rough where there is one): see step 5 of llm_output/abs_direct_uncertainty_planner.md
#
# SEs: sampling errors are effectively independent across divisions (published section SEs match
# sqrt(sum of division SE^2), median ratio 1.004), so variances add and
# SE_remainder = sqrt(SE_parent^2 - sum of visible SE^2).
# Independence only holds approximately, so that difference is sometimes negative: SE is NA there
# (can't be derived) rather than zero (which would claim the remainder is known exactly).
#
# [low] and [x] cells are treated as zero here. Only [c] counts as suppressed.
# Expects the joined long table (values + SE) with harmonised SIC codes,
# after add_single_division_sections().
remainder_se <- function(parent_var, known_var) {
  diff <- parent_var - known_var
  se <- rep(NA_real_, length(diff))
  ok <- !is.na(diff) & diff > 0
  se[ok] <- sqrt(diff[ok])
  se
}

add_suppressed_remainders <- function(df) {

  keys <- c('ITL_code', 'Region_name', 'year', 'variable')

  d <- df %>%
    mutate(
      suppressed = value_flag %in% '[c]',
      v0 = ifelse(value_flag %in% c('[low]', '[x]'), 0, value),
      se0 = ifelse(value_flag %in% c('[low]', '[x]'), 0, SE)
    )

  # Visible divisions summed within each section
  div_by_section <- d %>%
    filter(level == 'division') %>%
    group_by(across(all_of(keys)), section) %>%
    summarise(
      n_suppressed = sum(suppressed),
      vis_value = sum(v0, na.rm = TRUE),
      vis_var = sum(se0[!suppressed]^2),# NA if any visible division lacks an SE
      .groups = 'drop'
    )

  sections <- d %>%
    filter(level == 'section') %>%
    select(all_of(keys), section, sec_suppressed = suppressed, sec_value = value, sec_SE = SE)

  # 1. Section remainders
  section_remainders <- sections %>%
    filter(!sec_suppressed, !is.na(sec_value)) %>%
    inner_join(div_by_section %>% filter(n_suppressed > 0), by = c(keys, 'section')) %>%
    mutate(
      value = sec_value - vis_value,
      SE = remainder_se(sec_SE^2, vis_var),
      SIC_code = paste0(section, '_rem'),
      SIC_description = paste0('Suppressed remainder: section ', section)
    )

  # 2. Whole-economy remainder, where any section is itself suppressed
  total_remainders <- div_by_section %>%
    inner_join(sections, by = c(keys, 'section')) %>%
    group_by(across(all_of(keys))) %>%
    summarise(
      any_sec_suppressed = any(sec_suppressed),
      known_value = sum(ifelse(sec_suppressed, vis_value, sec_value)),
      known_var = sum(ifelse(sec_suppressed, vis_var, sec_SE^2)),
      .groups = 'drop'
    ) %>%
    filter(any_sec_suppressed) %>%
    inner_join(
      d %>% filter(level == 'total', !suppressed) %>% select(all_of(keys), tot_value = value, tot_SE = SE),
      by = keys
    ) %>%
    mutate(
      value = tot_value - known_value,
      SE = remainder_se(tot_SE^2, known_var),
      section = NA_character_,
      SIC_code = 'A-S_rem',
      SIC_description = 'Suppressed remainder: suppressed sections'
    )

  remainders <- bind_rows(section_remainders, total_remainders) %>%
    transmute(
      across(all_of(keys)), section, SIC_code, SIC_description, value, SE,
      level = 'remainder', partial_coverage = FALSE
    )

  bind_rows(df, remainders)
}


# DERIVED COLUMNS----

# CoV uses abs(value) because some aGVA cells are negative.
# positive: needed for log-normal draws and log(value) slopes in ABS_error_rates.R functions.
# provisional: the latest year in an edition gets revised once in the following edition.
add_abs_derived <- function(df) {

  df %>%
    mutate(
      CoV100 = 100 * SE / abs(value),
      min95 = value - 1.96 * SE,
      max95 = value + 1.96 * SE,
      has_se = !is.na(value) & !is.na(SE) & SE > 0,
      positive = !is.na(value) & value > 0,
      provisional = year == max(year)
    )
}


# LEGACY SHAPE----

# Same columns as data/itl1_cp_withestimatederrorratefromABS.csv, so the simulation and plot
# functions in ABS_error_rates.R run unchanged. Works for any of the four variables,
# though the bounds columns keep their gva_ names for compatibility.
# Suppressed cells are dropped. With include_remainders = TRUE the remainder rows stand in for them,
# so regional and national sums (and therefore LQs) match the published totals.
abs_legacy_shape <- function(df, var = 'aGVA', include_remainders = TRUE, min_year = 2012) {

  df %>%
    filter(
      variable == var,
      str_detect(ITL_code, '^TL[C-N]$'),
      level %in% c('division', if (include_remainders) 'remainder'),
      year >= min_year,
      !is.na(value)
    ) %>%
    transmute(
      ITL_code, Region_name,
      SIC07_code = SIC_code, SIC07_description = SIC_description,
      year, value, CoV100, SE,
      gva_min95 = min95, gva_max95 = max95,
      is_remainder = level == 'remainder', provisional
    )
}


# REVISIONS----

# Compare one edition's values against another's for the given years.
# Both inputs: output of read_abs_values() %>% harmonise_abs_sic()
compare_abs_editions <- function(from_df, to_df, years, from_edition, to_edition, revision_type) {

  k <- c('ITL_code', 'level', 'SIC_code', 'year', 'variable')

  from_df %>%
    filter(year %in% years) %>%
    select(all_of(k), Region_name, section, SIC_description, value_from = value, flag_from = value_flag) %>%
    inner_join(
      to_df %>% filter(year %in% years) %>% select(all_of(k), value_to = value, flag_to = value_flag),
      by = k
    ) %>%
    mutate(
      revision_type = revision_type,
      from_edition = from_edition,
      to_edition = to_edition,
      revision = value_to - value_from,
      revision_pct = 100 * revision / abs(value_from)
    )
}
