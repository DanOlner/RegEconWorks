# Test the reading of the shrinkage method on the IoD 2019, where the parent group is known
# In 2019 every LSOA was shrunk towards its local authority. 04 rebuilds the 2025 shrinkage with local
# authority parents and explains only part of the published 'pull' (correlation about 0.77 for Income and
# 0.82 for Employment, against about 0.92 and 0.90 if rounding were the only difference). Two explanations:
# the 2025 supergroup parents, or a misreading of Appendix C. If the same rebuild on 2019 data reaches the
# rounding-only benchmark, the reading is right and the 2025 gap is the supergroups.
# Same method as 04, on the IoD 2019 Files 6 to 8 (2011 LSOAs, 2019 local authorities)
# Used in docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd
source('code/imd_uncertainty/functions.R')

f7_2019 <- read_csv(get_iod2019_file('file7'), show_col_types = FALSE)
f8_2019_inc <- read_excel(get_iod2019_file('file8'), sheet = 'IoD2019 Income Domain')
f8_2019_emp <- read_excel(get_iod2019_file('file8'), sheet = 'IoD2019 Employment Domain')
f6_2019 <- read_excel(get_iod2019_file('file6'), sheet = 'Population Denominators')

d2019 <- tibble(
  lsoa = f7_2019[['LSOA code (2011)']],
  lad = f7_2019[['Local Authority District code (2019)']],
  income_rate = f7_2019[['Income Score (rate)']],
  employment_rate = f7_2019[['Employment Score (rate)']]
) %>%
  left_join(transmute(f8_2019_inc, lsoa = `LSOA code (2011)`, income_num = `Income Domain numerator`), by = 'lsoa') %>%
  left_join(transmute(f8_2019_emp, lsoa = `LSOA code (2011)`, employment_num = `Employment Domain numerator`), by = 'lsoa') %>%
  left_join(transmute(f6_2019, lsoa = `LSOA code (2011)`,
                      pop_total = `Total population: mid 2015 (excluding prisoners)`,
                      pop_working_age = `Working age population 18-59/64: for use with Employment Deprivation Domain (excluding prisoners)`), by = 'lsoa')

# Are the 2019 counts rounded to 5 like the 2025 ones?
rounding_2019 <- d2019 %>%
  summarise(income_multiples_of_5 = mean(income_num %% 5 == 0, na.rm = TRUE),
            employment_multiples_of_5 = mean(employment_num %% 5 == 0, na.rm = TRUE),
            income_suppressed = sum(is.na(income_num)), employment_suppressed = sum(is.na(employment_num)))
rounding_2019

count_domains_2019 <- bind_rows(
  d2019 %>% transmute(domain = 'Income', lsoa, lad, published = income_rate, r = income_num, size = pmax(pop_total, income_num)),
  d2019 %>% transmute(domain = 'Employment', lsoa, lad, published = employment_rate, r = employment_num, size = pmax(pop_working_age, employment_num))
) %>%
  filter(!is.na(r))

counts_rounded_2019 <- rounding_2019$income_multiples_of_5 > 0.99

rebuilt_2019 <- count_domains_2019 %>%
  group_by(domain) %>%
  group_modify(~ bind_cols(.x, shrink_iod(.x$r, .x$size, .x$lad))) %>%
  ungroup() %>%
  mutate(pull_published = qlogis(published) - m, pull_rebuilt = m_shrunk - m)

# Rounding-only benchmark, as in 04 (and adding the rounding of the published rate to 3 decimal places,
# which 04 leaves out). If the 2019 counts aren't rounded, only the rate rounding applies
set.seed(20261110)
rounding_only_2019 <- rebuilt_2019 %>%
  group_by(domain) %>%
  group_modify(~ {
    x <- .x
    tibble(draw = 1:20) %>%
      mutate(cor = map_dbl(draw, function(d) {
        r_un <- if (counts_rounded_2019) pmax(x$r + runif(nrow(x), -2.5, 2.5), 0) else x$r
        s <- shrink_iod(r_un, pmax(x$size, r_un), x$lad)
        published_like <- pmax(round(s$rate_shrunk, 3), 0.0005)
        cor(qlogis(published_like) - x$m, x$pull_rebuilt)
      }))
  }) %>%
  summarise(cor_if_only_rounding = mean(cor), .groups = 'drop')

shrinkage_2019_summary <- rebuilt_2019 %>%
  group_by(domain) %>%
  summarise(
    lsoas = n(),
    median_count = median(r),
    cor_rates = cor(published, rate_shrunk),
    cor_pulls = cor(pull_published, pull_rebuilt),
    # Share of LSOAs whose rebuilt rate rounds to the published rate (3 decimal places), allowing one unit
    share_rate_within_0.001 = mean(abs(rate_shrunk - published) <= 0.001 + 1e-9),
    max_abs_rate_diff = max(abs(rate_shrunk - published)),
    median_w = median(w),
    .groups = 'drop'
  ) %>%
  left_join(rounding_only_2019, by = 'domain') %>%
  mutate(year = 'IoD 2019 (local authority parents)')

# The same summary for 2025 from 04, side by side (computed here so this script stands alone)
count_domains_2025 <- load_count_domains() %>% filter(!is.na(r))
rebuilt_2025 <- count_domains_2025 %>%
  group_by(domain) %>%
  group_modify(~ bind_cols(.x, shrink_iod(.x$r, .x$size, .x$lad))) %>%
  ungroup() %>%
  mutate(pull_published = qlogis(published) - m, pull_rebuilt = m_shrunk - m)

set.seed(20261110)
rounding_only_2025 <- rebuilt_2025 %>%
  group_by(domain) %>%
  group_modify(~ {
    x <- .x
    tibble(draw = 1:20) %>%
      mutate(cor = map_dbl(draw, function(d) {
        r_un <- pmax(x$r + runif(nrow(x), -2.5, 2.5), 0)
        s <- shrink_iod(r_un, pmax(x$size, r_un), x$lad)
        published_like <- pmax(round(s$rate_shrunk, 3), 0.0005)
        cor(qlogis(published_like) - x$m, x$pull_rebuilt)
      }))
  }) %>%
  summarise(cor_if_only_rounding = mean(cor), .groups = 'drop')

shrinkage_2025_summary <- rebuilt_2025 %>%
  group_by(domain) %>%
  summarise(
    lsoas = n(), median_count = median(r),
    cor_rates = cor(published, rate_shrunk), cor_pulls = cor(pull_published, pull_rebuilt),
    share_rate_within_0.001 = mean(abs(rate_shrunk - published) <= 0.001 + 1e-9),
    max_abs_rate_diff = max(abs(rate_shrunk - published)),
    median_w = median(w), .groups = 'drop'
  ) %>%
  left_join(rounding_only_2025, by = 'domain') %>%
  mutate(year = 'IoD 2025 (local authority parents; 2025 used supergroups within them)')

shrinkage_by_year <- bind_rows(shrinkage_2019_summary, shrinkage_2025_summary) %>%
  mutate(domain = factor(domain, levels = c('Income', 'Employment'))) %>%
  arrange(domain, year)
shrinkage_by_year


# WHERE DOES 2025 MISS?----

# The LSOAs where the 2025 rebuild misses the published rate most, by type of local authority group size,
# to look for a pattern (prisons, student areas, counts close to the population)
worst_2025 <- rebuilt_2025 %>%
  mutate(miss_pp = 100 * (rate_shrunk - published)) %>%
  group_by(domain) %>%
  slice_max(abs(miss_pp), n = 50) %>%
  ungroup() %>%
  left_join(select(load_iod_ranks(), lsoa, lad_name, pop), by = 'lsoa') %>%
  mutate(count_over_pop = r / pop)

worst_2025_pattern <- worst_2025 %>%
  group_by(domain) %>%
  summarise(lsoas = n(), median_abs_miss_pp = median(abs(miss_pp)), share_rebuilt_higher = mean(miss_pp > 0),
            median_published_rate = median(published), median_rate_all = NA_real_, .groups = 'drop') %>%
  mutate(median_rate_all = map_dbl(domain, ~ median(rebuilt_2025$published[rebuilt_2025$domain == .x])))
worst_2025_pattern


# WERE COUNTS FROM SEVERAL TIME POINTS POOLED BEFORE SHRINKAGE?----

# The same question as for crime in 06, but here the counts are published, so it can be tested.
# The 2025 Employment numerator is the average of 12 monthly counts and the 2019 one the average of 4
# quarterly counts. If shrinkage used the counts pooled over the months or quarters, its variance would be
# 12 (or 4) times smaller and the pull much weaker. Rebuild with the counts multiplied up and see which fits.
# 'Slope' is the regression of the published pull on the rebuilt pull: 1 means the pull is the right size
pooling_test <- bind_rows(
  rebuilt_2019 %>% mutate(year = '2019'),
  rebuilt_2025 %>% mutate(year = '2025')
) %>%
  group_by(year, domain) %>%
  group_modify(~ {
    x <- .x
    multipliers <- if (.y$domain == 'Employment') c(1, if (.y$year == '2019') 4 else 12) else 1
    map_dfr(multipliers, function(mult) {
      s <- shrink_iod(x$r * mult, x$size * mult, x$lad)
      pull <- s$m_shrunk - s$m
      tibble(counts_multiplied_by = mult, cor_pulls = cor(x$pull_published, pull),
             slope = unname(coef(lm(x$pull_published ~ pull))[2]), median_w = median(s$w))
    })
  }) %>%
  ungroup()
pooling_test
