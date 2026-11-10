# A real-data test of running shrinkage backwards
# 05 tests the inversion on made-up data. Here it is tested on the four indicators whose counts ARE
# published: the Income and Employment domains, and the two supplementary indices (IDACI for children,
# IDAOPI for older people). Invert each published rate with its published denominator and local authority
# parent groups, then compare the recovered count with the published count.
# The published counts are rounded to the nearest 5, and the 2025 parent groups were LSOA classification
# supergroups within local authorities, not local authorities, so the match can't be perfect.
# It also checks whether IDACI and IDAOPI were shrunk at all (the technical report doesn't say), and recovers
# the counts that File 8 suppresses (under 10), which 13_supplementary_mc.R needs
# Used in docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd
source('code/imd_uncertainty/functions.R')

iod <- read_csv(get_iod_file('file7'), show_col_types = FALSE)
numerators <- load_underlying('IoD25 Income Domain') %>%
  transmute(lsoa = `LSOA code (2021)`, Income = `Income Domain numerator`,
            IDACI = `Income Deprivation Affecting Children Index (IDACI) numerator`,
            IDAOPI = `Income Deprivation Affecting Older People Index (IDAOPI) numerator`) %>%
  left_join(load_employment_numerators() %>% rename(Employment = employment_num), by = 'lsoa')

base <- tibble(
  lsoa = iod[['LSOA code (2021)']],
  lad = iod[['Local Authority District code (2024)']],
  Income = iod[['Income Score (rate)']],
  Employment = iod[['Employment Score (rate)']],
  IDACI = iod[['Income Deprivation Affecting Children Index (IDACI) Score (rate)']],
  IDAOPI = iod[['Income Deprivation Affecting Older People (IDAOPI) Score (rate)']]
) %>%
  left_join(load_population_denominators(), by = 'lsoa')

indicators <- tribble(
  ~indicator,   ~denominator,
  'Income',     'pop_total',
  'Employment', 'pop_working_age',
  'IDACI',      'pop_children',
  'IDAOPI',     'pop_older'
)

# Long table: published rate, published count (NA if suppressed) and denominator for each LSOA x indicator.
# As the Indices do, a denominator smaller than the count is raised to the count
long <- pmap_dfr(indicators, function(indicator, denominator) {
  this <- indicator  # tibble() below would otherwise read 'indicator' as its own new column
  tibble(indicator = this, lsoa = base$lsoa, lad = base$lad, published_rate = base[[this]],
         r = numerators[[this]][match(base$lsoa, numerators$lsoa)], pop = base[[denominator]]) %>%
    mutate(size = pmax(pop, coalesce(r, 0)))
})

recovered <- long %>%
  group_by(indicator) %>%
  group_modify(~ {
    back <- invert_shrinkage(.x$published_rate, .x$size, .x$lad)
    fwd <- shrink_iod(coalesce(.x$r, 5), .x$size, .x$lad)
    bind_cols(.x, back %>% select(r_recovered, w_recovered = w, post_var_recovered = post_var, converged),
              fwd %>% select(w_from_counts = w, post_var_from_counts = post_var))
  }) %>%
  ungroup() %>%
  mutate(
    count_from_rate = published_rate * size,  # the count if the rate hadn't been shrunk at all
    diff_recovered = r_recovered - r,
    diff_unshrunk = count_from_rate - r
  )


# HOW CLOSE ARE THE RECOVERED COUNTS?----

inversion_real <- recovered %>%
  filter(!is.na(r)) %>%
  group_by(indicator) %>%
  summarise(
    lsoas = n(),
    median_count = median(r),
    # Rounding to the nearest 5 alone allows a difference of up to 2.5; File 7's 3 decimal places add a little
    share_within_rounding_recovered = mean(abs(diff_recovered) <= 2.5 + 0.0005 * size),
    share_within_rounding_unshrunk = mean(abs(diff_unshrunk) <= 2.5 + 0.0005 * size),
    median_abs_diff_recovered = median(abs(diff_recovered)),
    median_abs_diff_unshrunk = median(abs(diff_unshrunk)),
    p95_abs_diff_recovered = quantile(abs(diff_recovered), 0.95),
    cor_counts = cor(r_recovered, r),
    median_se_ratio = median(sqrt(post_var_recovered / post_var_from_counts)),
    se_ratio_p05 = quantile(sqrt(post_var_recovered / post_var_from_counts), 0.05),
    se_ratio_p95 = quantile(sqrt(post_var_recovered / post_var_from_counts), 0.95),
    groups_converged = mean(converged),
    .groups = 'drop'
  ) %>%
  mutate(indicator = factor(indicator, levels = indicators$indicator)) %>%
  arrange(indicator)
inversion_real


# SUPPRESSED COUNTS----

# File 8 suppresses counts under 10. The inversion recovers a count for these too: check that it falls below 10
suppressed_recovered <- recovered %>%
  filter(is.na(r)) %>%
  group_by(indicator) %>%
  summarise(suppressed = n(), recovered_below_10 = mean(r_recovered < 10), median_recovered = median(r_recovered), .groups = 'drop')
suppressed_recovered

# Counts for 13_supplementary_mc.R: the published count where there is one, the recovered count where suppressed
supplementary_counts <- recovered %>%
  filter(indicator %in% c('IDACI', 'IDAOPI')) %>%
  transmute(indicator, lsoa, lad, published_rate, size, r_used = if_else(is.na(r), pmin(r_recovered, 9.99), r), suppressed = is.na(r))
