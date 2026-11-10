# A rough first look at rank uncertainty: the Income domain alone
# Treats each LSOA's count of income-deprived people as a binomial draw (the technical report's
# 'super-population' framing, Appendix C.1.3) and turns a 95% interval on its rate into an interval on its rank.
# Illustration only. It ignores: the narrowing from shrinkage, denominator error, rounding of the counts,
# every other LSOA's own error, and the other six domains (see section 8 of the research note).
# 07_income_employment_mc.R does this properly for Income and Employment
# Used in llm_output/imd_rank_uncertainty_research.md, section 8,
# and docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd
source('code/imd_uncertainty/functions.R')

iod <- load_iod_ranks()

income <- iod %>%
  select(lsoa, pop, income_score, income_rank) %>%
  inner_join(load_income_numerators(), by = 'lsoa') %>%
  # 5 LSOAs have suppressed numerators
  filter(!is.na(income_num)) %>%
  # Where the numerator is bigger than the population, the Indices set the denominator to the numerator
  # (technical report 4.3.22)
  mutate(n = pmax(pop, income_num), raw_rate = income_num / n)


# SIZE OF SHRINKAGE----

# Published (shrunk) rate minus the raw rate from the published numerator and mid-2022 population,
# in percentage points. Small, because Income counts are large (median about 310)
summary(income$income_num)

income_shrinkage_size <- quantile(100 * (income$income_score - income$raw_rate), c(0, 0.01, 0.05, 0.25, 0.5, 0.75, 0.95, 0.99, 1))
income_shrinkage_size

cor(income$raw_rate, income$income_score)


# RANK INTERVALS----

# 95% interval on the logit scale, centred on the published rate, using the Appendix C variance.
# Each end is turned into a rank against all 33,755 published Income rates, holding the others fixed
published_sorted <- sort(iod$income_score)
rank_against_published <- function(rate) length(published_sorted) - findInterval(rate, published_sorted) + 1

income <- income %>%
  mutate(
    se_logit = sqrt(logit_var(income_num, n)),
    rate_low = plogis(qlogis(income_score) - 1.96 * se_logit),
    rate_high = plogis(qlogis(income_score) + 1.96 * se_logit),
    rank_most_deprived_end = rank_against_published(rate_high),
    rank_least_deprived_end = rank_against_published(rate_low),
    width = rank_least_deprived_end - rank_most_deprived_end
  )

bands <- tribble(
  ~band,                             ~from,  ~to,
  '1 to 100',                        1,      100,
  '1 to 3,375 (most deprived 10%)',  1,      3375,
  '3,376 to 10,000',                 3376,   10000,
  '10,001 to 20,000',                10001,  20000,
  '20,001 to 33,755',                20001,  33755
)

income_interval_bands <- bands %>%
  mutate(stats = map2(from, to, ~ income %>%
    filter(income_rank >= .x, income_rank <= .y) %>%
    summarise(lsoas = n(), median_width = median(width), q25 = quantile(width, 0.25), q75 = quantile(width, 0.75)))) %>%
  unnest(stats)
income_interval_bands
