# Tests behind two decisions in llm_output/abs_direct_uncertainty_planner.md:
# - Step 5 / question 3: can suppressed ([c]) ABS cells be estimated from neighbouring years,
#   or should we stick with suppressed-remainder rows? (Answer: remainder rows.)
# - Question 2: what each sector level (two-digit vs section) costs in suppression and precision
#
# Needs data/abs_itl1_long.csv from code/ABS_direct_dataprep.R. Prints results only, writes nothing.
library(tidyverse)

options(scipen = 999)

abs_long <- read_csv('data/abs_itl1_long.csv', col_types = cols(SIC_code = 'c'), show_col_types = FALSE)

itl1 <- '^TL[C-N]$'


# SET UP: aGVA, 12 ITL1 x two-digit, with each cell's share of its section----

cells <- abs_long %>%
  filter(variable == 'aGVA', level == 'division', str_detect(ITL_code, itl1)) %>%
  select(ITL_code, SIC_code, section, year, value, value_flag, SE) %>%
  mutate(
    suppressed = value_flag %in% '[c]',
    published = !is.na(value)
  )

section_values <- abs_long %>%
  filter(variable == 'aGVA', level == 'section', str_detect(ITL_code, itl1)) %>%
  select(ITL_code, section = SIC_code, year, sec_value = value)

cells <- cells %>%
  left_join(section_values, by = c('ITL_code', 'section', 'year')) %>%
  mutate(share = ifelse(published & !is.na(sec_value) & sec_value != 0, value / sec_value, NA)) %>%
  arrange(ITL_code, SIC_code, year)

# Accuracy summary: how far an estimate is from the published value, in % and in SEs
accuracy <- function(df, pred, label) {
  err <- df[[pred]] - df$value
  tibble(
    method = label,
    n = nrow(df),
    median_abs_pct = round(median(abs(100 * err / df$value)), 1),
    p90_abs_pct = round(quantile(abs(100 * err / df$value), 0.9), 1),
    median_abs_z = round(median(abs(err / df$SE)), 2),
    within_1SE = round(mean(abs(err / df$SE) <= 1), 2),
    within_2SE = round(mean(abs(err / df$SE) <= 2), 2)
  )
}


# 1. HOW PERSISTENT IS SUPPRESSION?----

# If the same region x sector is usually hidden in neighbouring years too,
# there's nothing to estimate from.
cat('==== 1. How persistent is suppression? (aGVA, ITL1 x two-digit, 2008-2024) ====\n')

series <- cells %>%
  group_by(ITL_code, SIC_code) %>%
  summarise(n_suppressed = sum(suppressed), n_published = sum(published), .groups = 'drop')

cat('Series (region x two-digit):', nrow(series),
    '| with any suppression:', sum(series$n_suppressed > 0),
    '| never published:', sum(series$n_published == 0), '\n')

nearest <- cells %>%
  group_by(ITL_code, SIC_code) %>%
  mutate(
    # Years to the nearest year where the same cell is published
    dist = map_dbl(year, function(y) {
      pub_years <- year[published]
      if (length(pub_years) == 0) Inf else min(abs(pub_years - y))
    }),
    prev_published = lag(published, default = FALSE),
    next_published = lead(published, default = FALSE)
  ) %>%
  ungroup() %>%
  filter(suppressed, year >= 2012) %>%
  left_join(series, by = c('ITL_code', 'SIC_code'))

cat('Suppressed cells 2012-2024:', nrow(nearest), '\n')
cat('  Nearest published year of the same cell: adjacent', round(mean(nearest$dist == 1), 2),
    '| 2 years', round(mean(nearest$dist == 2), 2),
    '| 3+ years', round(mean(nearest$dist >= 3 & is.finite(nearest$dist)), 2),
    '| never', round(mean(!is.finite(nearest$dist)), 2), '\n')
cat('  Published on both sides (t-1 and t+1):', round(mean(nearest$prev_published & nearest$next_published), 2),
    '| one side only:', round(mean(xor(nearest$prev_published, nearest$next_published)), 2), '\n')
cat('  Share in series suppressed in 10+ of 17 years:', round(mean(nearest$n_suppressed >= 10), 2), '\n')


# 2. HOW ACCURATE ARE NEIGHBOURING-YEAR ESTIMATES? (tested on published cells)----

# Predict each published cell from the years either side (leave-one-out), then compare with the truth.
# Two versions: interpolate the cell's level, or interpolate its share of the section
# and multiply by this year's (published) section value.
cat('\n==== 2. Neighbouring-year estimates tested on published cells (t from t-1 and t+1) ====\n')

loo <- cells %>%
  group_by(ITL_code, SIC_code) %>%
  mutate(
    v_prev = lag(ifelse(published, value, NA)),
    v_next = lead(ifelse(published, value, NA)),
    s_prev = lag(share),
    s_next = lead(share),
    any_suppressed = any(suppressed)
  ) %>%
  ungroup() %>%
  filter(published, year >= 2012, !is.na(SE), SE > 0, value > 0,
         !is.na(v_prev), !is.na(v_next), !is.na(s_prev), !is.na(s_next), !is.na(sec_value)) %>%
  mutate(
    pred_level = (v_prev + v_next) / 2,
    pred_share = (s_prev + s_next) / 2 * sec_value
  )

bind_rows(
  accuracy(loo, 'pred_level', 'level interpolation, all published'),
  accuracy(loo, 'pred_share', 'share interpolation, all published'),
  accuracy(filter(loo, any_suppressed), 'pred_level', 'level interpolation, series sometimes suppressed'),
  accuracy(filter(loo, any_suppressed), 'pred_share', 'share interpolation, series sometimes suppressed')
) %>%
  as.data.frame() %>%
  print()


# 3. PSEUDO-SUPPRESSION: hide the two smallest two-digit cells in fully published sections----

# Suppressed cells tend to be small, so hide the two smallest cells in each fully published
# section-year and rebuild them three ways:
# - neighbouring-year shares alone
# - the known remainder (section minus visible cells), split in proportion to neighbouring-year shares
# - the known remainder split equally
cat('\n==== 3. Hide the two smallest two-digit cells in fully published section-years, then rebuild ====\n')

neighbour_shares <- cells %>%
  group_by(ITL_code, SIC_code) %>%
  mutate(s_prev = lag(share), s_next = lead(share)) %>%
  ungroup() %>%
  select(ITL_code, SIC_code, year, s_prev, s_next)

hidden <- cells %>%
  filter(year >= 2012) %>%
  group_by(ITL_code, section, year) %>%
  filter(n() >= 3, all(published), all(value > 0), !is.na(first(sec_value))) %>%
  mutate(
    rank_small = rank(value, ties.method = 'first'),
    remainder = first(sec_value) - sum(value[rank_small > 2])
  ) %>%
  ungroup() %>%
  filter(rank_small <= 2) %>%
  left_join(neighbour_shares, by = c('ITL_code', 'SIC_code', 'year')) %>%
  mutate(
    nb_share = rowMeans(cbind(s_prev, s_next), na.rm = TRUE),
    nb_share = ifelse(is.nan(nb_share), NA, nb_share),
    pred_neighbour = nb_share * sec_value
  ) %>%
  group_by(ITL_code, section, year) %>%
  filter(all(!is.na(pred_neighbour)), !is.na(SE), SE > 0) %>%
  mutate(
    pred_hybrid = remainder * pred_neighbour / sum(pred_neighbour),
    pred_equal = remainder / 2
  ) %>%
  ungroup()

bind_rows(
  accuracy(hidden, 'pred_neighbour', 'neighbouring-year shares alone'),
  accuracy(hidden, 'pred_hybrid', 'remainder split by neighbouring-year shares'),
  accuracy(hidden, 'pred_equal', 'remainder split equally')
) %>%
  as.data.frame() %>%
  print()


# 4. REAL SUPPRESSED CELLS: do neighbouring-year estimates add up to the known remainder?----

# Use the nearest published share within 3 years on each side (average if both),
# then compare the sum of estimates for a section's hidden cells with its remainder row.
cat('\n==== 4. Real suppressed cells: neighbouring-year estimates vs the known section remainder ====\n')

filled <- cells %>%
  group_by(ITL_code, SIC_code) %>%
  mutate(
    share_before = share, year_before = ifelse(!is.na(share), year, NA),
    share_after = share, year_after = ifelse(!is.na(share), year, NA)
  ) %>%
  fill(share_before, year_before, .direction = 'down') %>%
  fill(share_after, year_after, .direction = 'up') %>%
  ungroup() %>%
  mutate(
    ok_before = !is.na(year_before) & year - year_before <= 3,
    ok_after = !is.na(year_after) & year_after - year <= 3,
    nb_share = case_when(
      ok_before & ok_after ~ (share_before + share_after) / 2,
      ok_before ~ share_before,
      ok_after ~ share_after
    ),
    pred = nb_share * sec_value
  )

remainders <- abs_long %>%
  filter(variable == 'aGVA', level == 'remainder', str_detect(ITL_code, itl1), !is.na(section), year >= 2012) %>%
  select(ITL_code, section, year, remainder = value)

real <- filled %>%
  filter(suppressed, year >= 2012) %>%
  group_by(ITL_code, section, year) %>%
  summarise(n_suppressed = n(), all_estimable = all(!is.na(pred)), sum_pred = sum(pred), .groups = 'drop') %>%
  inner_join(remainders, by = c('ITL_code', 'section', 'year'))

ratios <- real %>%
  filter(all_estimable, sum_pred > 0, remainder > 0) %>%
  mutate(ratio = remainder / sum_pred)

cat('Section-years with suppressed cells and a known remainder:', nrow(real), '\n')
cat('  Suppressed cells per section-year: 1:', sum(real$n_suppressed == 1),
    '| 2:', sum(real$n_suppressed == 2), '| 3+:', sum(real$n_suppressed >= 3), '\n')
cat('  All hidden cells have a neighbouring-year share within 3 years:', round(mean(real$all_estimable), 2), '\n')
cat('  Remainder / sum of estimates: median', round(median(ratios$ratio), 2),
    '| 10-90%:', round(quantile(ratios$ratio, c(0.1, 0.9)), 2),
    '| within +-20%:', round(mean(abs(ratios$ratio - 1) <= 0.2), 2), '\n')
cat('Suppressed cells 2012+ with no neighbouring-year share within 3 years:',
    round(mean(is.na(filled$pred[filled$suppressed & filled$year >= 2012])), 2), '\n')


# 5. SECTOR LEVEL TRADE-OFF (question 2)----

# What each level costs: share hidden, precision, and how often year-on-year changes
# can be told apart from sampling noise (95%, independent errors assumed)
cat('\n==== 5. Two-digit vs section vs whole economy (aGVA, 12 ITL1, 2012-2024) ====\n')

by_level <- abs_long %>%
  filter(variable == 'aGVA', str_detect(ITL_code, itl1), year >= 2012,
         level %in% c('division', 'section', 'total'))

by_level %>%
  group_by(level) %>%
  summarise(
    n_sectors = n_distinct(SIC_code),
    share_suppressed = round(mean(value_flag %in% '[c]'), 3),
    median_CoV = round(median(CoV100[value > 0], na.rm = TRUE), 1),
    p75_CoV = round(quantile(CoV100[value > 0], 0.75, na.rm = TRUE), 1),
    .groups = 'drop'
  ) %>%
  print()

yoy <- by_level %>%
  filter(level != 'total', !is.na(value), !is.na(SE), SE > 0) %>%
  arrange(ITL_code, SIC_code, year) %>%
  group_by(level, ITL_code, SIC_code) %>%
  mutate(
    z = abs(value - lag(value)) / sqrt(SE^2 + lag(SE)^2),
    gap = year - lag(year)
  ) %>%
  ungroup() %>%
  filter(gap == 1)

cat('\nShare of year-on-year changes significant at 95%:\n')
yoy %>%
  group_by(level) %>%
  summarise(n = n(), share_significant = round(mean(z > 1.96), 2), .groups = 'drop') %>%
  print()
