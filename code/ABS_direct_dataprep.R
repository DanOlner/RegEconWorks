# ABS regional data prep: values plus standard errors, staying within the ABS itself
# (rather than grafting ABS error rates onto region-by-industry GVA, as in ABS_error_rates.R)
# Plan and background checks: llm_output/abs_direct_uncertainty_planner.md
#
# Outputs:
# - data/abs_itl1_long.csv: all four ABS variables with SEs, 12 ITL1 + England + UK, 2008-2024
#   (SEs from 2012), all SIC levels plus suppressed-remainder rows
# - data/abs_itl1_aGVA_legacyshape.csv: aGVA divisions in the column shape the
#   ABS_error_rates.R simulation/plot functions expect
# - data/abs_itl1_revisions.csv: planned revisions to 2022 and 2023, plus the 2023 error correction
library(tidyverse)
library(readxl)

source('code/ABS_direct_functions.R')

options(scipen = 999)

# Remainder rows stand in for suppressed divisions so sums match published totals (see functions file)
include_remainders <- TRUE


# FILES----

# Values for the current edition only exist at 'current/'. When the 2025 edition comes out,
# the 2024 file should move to 'current/previous/v15/' - the cached copy in local/abs_raw avoids that.
# Quality files have stable dated paths.
# 2023 had a processing error: v13 is the original (8 May 2025), v14 the correction (18 Sep 2025).
abs_values_base <- 'https://www.ons.gov.uk/file?uri=/businessindustryandtrade/business/businessservices/datasets/uknonfinancialbusinesseconomyannualbusinesssurveyregionalresultssectionsas/current/'
abs_quality_base <- 'https://www.ons.gov.uk/file?uri=/businessindustryandtrade/business/businessservices/datasets/uknonfinancialbusinesseconomyannualbusinesssurveyregionalresultsqualitymeasures/'

abs_files <- tribble(
  ~name,                    ~url,                                                            ~file,
  'values_2024',            paste0(abs_values_base, 'absregionalsectionas2024.xlsx'),         'abs_regional_values_2024ed.xlsx',
  'quality_2024',           paste0(abs_quality_base, '2024/absregionalqualitymeasures2024.xlsx'), 'abs_regional_quality_2024ed.xlsx',
  'values_2023_corrected',  paste0(abs_values_base, 'previous/v14/absregionalsectionas2023.xlsx'), 'abs_regional_values_2023ed_corrected.xlsx',
  'values_2023_original',   paste0(abs_values_base, 'previous/v13/absregionalsectionsas2023.xlsx'), 'abs_regional_values_2023ed_original.xlsx',
  'values_2022',            paste0(abs_values_base, 'previous/v12/absregionalsectionsas2022.xlsx'), 'abs_regional_values_2022ed.xlsx'
)

abs_paths <- map2_chr(abs_files$url, abs_files$file, get_abs_file) %>% set_names(abs_files$name)


# READ CURRENT EDITION----

# Drop Great Britain: values only, no quality measures
abs_values <- read_abs_values(abs_paths['values_2024']) %>%
  filter(ITL_code != 'GB') %>%
  harmonise_abs_sic()

abs_quality <- read_abs_quality(abs_paths['quality_2024']) %>%
  harmonise_abs_sic() %>%
  mutate(in_quality_file = TRUE)

# Structural checks before joining
stopifnot(
  # 98 SIC rows (78 divisions, 17 sections, 3 totals/aggregates) per geography x year x variable
  all(count(abs_values, ITL_code, year, variable)$n == 98),
  !anyNA(abs_values$level), !anyNA(abs_quality$level),
  # Join keys unique in both
  !anyDuplicated(abs_values %>% select(ITL_code, SIC_code, level, year, variable)),
  !anyDuplicated(abs_quality %>% select(ITL_code, SIC_code, level, year, variable))
)


# JOIN VALUES AND STANDARD ERRORS----

abs_long <- abs_values %>%
  left_join(
    abs_quality %>% select(ITL_code, SIC_code, level, year, variable, SE, SE_flag, CoV_published, in_quality_file),
    by = c('ITL_code', 'SIC_code', 'level', 'year', 'variable')
  )

# Every 2012+ value row should have a quality row
stopifnot(all(abs_long$in_quality_file[abs_long$year >= 2012] %in% TRUE))


# SUPPRESSED REMAINDERS AND DERIVED COLUMNS----

abs_long <- abs_long %>%
  add_single_division_sections() %>%
  add_suppressed_remainders() %>%
  add_abs_derived() %>%
  mutate(
    edition = '2024',
    release_date = get_abs_release_date(abs_paths['values_2024'])
  )


# CHECKS----

cat('\n==== Checks ====\n')

# Published CoV vs SE/|value|. In the 2024 edition, 2022-2024 are full precision and 2012-2021
# are rounded to 2dp. The small remaining mismatches are tiny or negative cells: ONS computes CoV
# from unrounded values and keeps the sign, so for cells of a few GBP m any CoV is noise anyway.
cov_check <- abs_long %>%
  filter(!is.na(CoV_published), !is.na(CoV100), level != 'remainder') %>%
  mutate(
    diff = abs(CoV_published - CoV100 / 100),
    period = ifelse(year >= 2022, '2022+ (exact?)', '2012-21 (within 2dp rounding?)'),
    ok = ifelse(year >= 2022, diff < 1e-9, diff <= 0.005)
  )
cat('Published CoV vs SE/|value|, share matching:\n')
print(cov_check %>% group_by(period) %>% summarise(n = n(), share_ok = round(mean(ok), 3)))

# Regions should sum to the UK row (additive by construction)
region_sums <- abs_long %>%
  filter(level == 'total', !is.na(value)) %>%
  group_by(year, variable) %>%
  summarise(
    sum_itl1 = sum(value[str_detect(ITL_code, '^TL[C-N]$')]),
    uk = value[ITL_code == 'UK'],
    .groups = 'drop'
  ) %>%
  mutate(diff_pct = 100 * (sum_itl1 / uk - 1))
cat('Regions vs UK, whole economy, max abs diff %:', signif(max(abs(region_sums$diff_pct)), 3), '\n')
if (any(abs(region_sums$diff_pct) > 0.01)) warning('ITL1 regions do not sum to the UK total within 0.01%')

# Remainders should close the gap: visible divisions + remainders = published whole-economy total
closure <- abs_long %>%
  filter(level %in% c('division', 'remainder')) %>%
  mutate(v0 = ifelse(value_flag %in% c('[low]', '[x]'), 0, value)) %>%
  group_by(ITL_code, year, variable) %>%
  summarise(parts = sum(v0, na.rm = TRUE), .groups = 'drop') %>%
  inner_join(
    abs_long %>% filter(level == 'total') %>% select(ITL_code, year, variable, total = value),
    by = c('ITL_code', 'year', 'variable')
  ) %>%
  mutate(diff = parts - total)
cat('Divisions + remainders vs whole-economy total (GBP m): median abs diff', median(abs(closure$diff)),
    '| max abs diff', max(abs(closure$diff)), '\n')
# Rounding to GBP 1m across ~100 published cells should only ever give a handful of GBP m
if (max(abs(closure$diff)) > 50) warning('Divisions + remainders do not add up to the whole-economy total')

remainders <- abs_long %>% filter(level == 'remainder')
cat('Remainder rows:', nrow(remainders),
    '| 2012+ with SE not derivable (NA):', sum(is.na(remainders$SE) & remainders$year >= 2012),
    '| negative value:', sum(remainders$value < 0, na.rm = TRUE), '\n')

# Independence across divisions: section SE vs divisions added in quadrature (expect ratio near 1)
quadrature <- abs_long %>%
  filter(variable == 'aGVA', level == 'division', year >= 2012) %>%
  group_by(ITL_code, year, section) %>%
  summarise(n = n(), all_se = all(!is.na(SE)), quad_SE = sqrt(sum(SE^2)), .groups = 'drop') %>%
  filter(all_se, n > 1) %>%
  inner_join(
    abs_long %>% filter(variable == 'aGVA', level == 'section') %>% select(ITL_code, year, section = SIC_code, SE),
    by = c('ITL_code', 'year', 'section')
  ) %>%
  filter(!is.na(SE)) %>%
  mutate(ratio = SE / quad_SE)
cat('Section SE / sqrt(sum division SE^2), aGVA: quantiles (5, 50, 95%):',
    round(quantile(quadrature$ratio, c(.05, .5, .95)), 3), '\n')

# Earlier years should match the 2023-edition extract used by the regional GVA chunk.
# A mismatch would mean ONS has revised further back than the latest year.
old_extract <- read_csv('data/abs_gva_se_combo.csv', col_types = cols(SIC = 'c'), show_col_types = FALSE) %>%
  filter(Year <= 2022) %>%
  inner_join(
    abs_long %>% filter(level == 'division', variable == 'aGVA') %>% select(SIC_code, Region_name, year, value, SE),
    by = c('SIC' = 'SIC_code', 'Country_and_Region' = 'Region_name', 'Year' = 'year')
  ) %>%
  mutate(
    same_value = (is.na(GVA) & is.na(value)) | (!is.na(GVA) & !is.na(value) & GVA == value),
    same_SE = (is.na(GVA_SE) & is.na(SE)) | abs(GVA_SE - SE) < 1e-9
  )
cat('Match with data/abs_gva_se_combo.csv for 2012-2022 (n =', nrow(old_extract), '): values',
    round(mean(old_extract$same_value), 4), '| SEs', round(mean(old_extract$same_SE %in% TRUE), 4), '\n')
if (!all(old_extract$same_value) || !all(old_extract$same_SE %in% TRUE)) {
  warning('2012-2022 aGVA or SEs differ from the 2023-edition extract: check for back revisions')
}


# REVISIONS BETWEEN EDITIONS----

# Planned revisions: each year's first figures are revised once, in the following year's edition.
# Error correction: 2023 original (May 2025) vs corrected (Sep 2025).
# Revision/SE uses the current edition's SE for that cell.
read_edition <- function(name) {
  read_abs_values(abs_paths[name]) %>% filter(ITL_code != 'GB') %>% harmonise_abs_sic()
}

ed2022 <- read_edition('values_2022')
ed2023_original <- read_edition('values_2023_original')
ed2023_corrected <- read_edition('values_2023_corrected')
ed2024 <- abs_values

abs_revisions <- bind_rows(
  compare_abs_editions(ed2022, ed2023_corrected, 2022, '2022', '2023_corrected', 'planned'),
  compare_abs_editions(ed2023_corrected, ed2024, 2023, '2023_corrected', '2024', 'planned'),
  compare_abs_editions(ed2023_original, ed2023_corrected, 2023, '2023_original', '2023_corrected', 'error_correction')
) %>%
  left_join(
    abs_long %>% filter(level != 'remainder') %>% select(ITL_code, level, SIC_code, year, variable, SE_current = SE),
    by = c('ITL_code', 'level', 'SIC_code', 'year', 'variable')
  ) %>%
  mutate(revision_over_SE = revision / SE_current)

# Earlier years shouldn't move between editions
no_back_revision <- compare_abs_editions(ed2022, ed2023_corrected, 2012:2021, '2022', '2023_corrected', 'check') %>%
  bind_rows(compare_abs_editions(ed2023_corrected, ed2024, 2012:2022, '2023_corrected', '2024', 'check')) %>%
  filter(!is.na(revision))
cat('Back revisions to earlier years (should be 0):', sum(no_back_revision$revision != 0), '\n')

cat('\nRevision summary, aGVA, ITL1 x division (abs %):\n')
abs_revisions %>%
  filter(variable == 'aGVA', level == 'division', str_detect(ITL_code, '^TL[C-N]$'), !is.na(revision_pct)) %>%
  group_by(revision_type, year) %>%
  summarise(
    n = n(),
    median_abs_pct = round(median(abs(revision_pct)), 2),
    p90_abs_pct = round(quantile(abs(revision_pct), 0.9), 1),
    share_within_1SE = round(mean(abs(revision_over_SE) <= 1, na.rm = TRUE), 2),
    .groups = 'drop'
  ) %>%
  print()


# SAVE----

abs_long_out <- abs_long %>%
  select(
    edition, release_date, ITL_code, Region_name, level, section, SIC_code, SIC_description,
    partial_coverage, year, variable, value, value_flag, SE, SE_flag, CoV100, min95, max95,
    has_se, positive, provisional
  ) %>%
  arrange(ITL_code, variable, factor(level, levels = c('total', 'aggregate', 'section', 'division', 'remainder')), SIC_code, year)

abs_legacy <- abs_legacy_shape(abs_long, var = 'aGVA', include_remainders = include_remainders)

write_csv(abs_long_out, 'data/abs_itl1_long.csv')
write_csv(abs_legacy, 'data/abs_itl1_aGVA_legacyshape.csv')
write_csv(abs_revisions, 'data/abs_itl1_revisions.csv')

cat('\nWritten:\n')
walk(c('data/abs_itl1_long.csv', 'data/abs_itl1_aGVA_legacyshape.csv', 'data/abs_itl1_revisions.csv'), function(f) {
  cat(sprintf('  %-40s %6.1f MB\n', f, file.size(f) / 1e6))
})
