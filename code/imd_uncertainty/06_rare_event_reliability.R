# How much of each LSOA's published crime and road casualty rate is its own data?
# Runs the shrinkage backwards (see 05) on published rates with approximate denominators, to estimate
# each LSOA's shrinkage weight w and the posterior standard error of its rate.
# Used in docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd (reading uncertainty from shrinkage)
#
# Approximations, all flagged in the write-up:
# - The at-risk denominator is the resident population plus the non-resident workplace population, which
#   isn't published. This uses residents only (File 7), so it understates the count where many people work,
#   which overstates the error there
# - Parent group is the local authority, not supergroup within local authority (see 04)
# - Burglary is left out because its denominator is properties, which isn't published either
# - Road casualties are weighted by severity (1, 2, 3), so they aren't simple counts
# - The technical report doesn't say whether shrinkage used the counts pooled over all years or the annual
#   average count (4.7.10 to 4.7.13 suggest the annual average). Both are run here
source('code/imd_uncertainty/functions.R')

iod <- load_iod_ranks()
crime <- load_underlying('IoD25 Crime Domain')
living <- load_underlying('IoD25 Living Env Domain')

rare_indicators <- tribble(
  ~indicator,                                   ~sheet,     ~column,                                                                          ~years,
  'Violence with injury',                       'crime',    "Violence with injury, rate per 1,000 'at-risk population'",                      6,
  'Violence without injury',                    'crime',    "Violence without injury, rate per 1,000 'at-risk population'",                   6,
  'Stalking and harassment',                    'crime',    "Stalking and harassment, rate per 1,000 'at-risk population'",                   6,
  'Theft',                                      'crime',    "Theft, rate per 1,000 'at-risk population'",                                     6,
  'Criminal damage',                            'crime',    "Criminal damage, rate per 1,000 'at-risk population'",                           6,
  'Public order and weapons',                   'crime',    "Public order and Possession of weapons, rate per 1,000 'at-risk population'",    6,
  'Anti-social behaviour',                      'crime',    "Anti-Social Behaviour, rate per 1,000 'at-risk population'",                     2,
  'Road casualties (pedestrians and cyclists)', 'living',   'Road traffic casualties involving injury to pedestrians and cyclists',           5
)

scenarios <- tribble(
  ~scenario,                     ~pooled,
  'Counts pooled over all years', TRUE,
  'Annual average count',        FALSE
)

rare_inverted <- pmap_dfr(rare_indicators, function(indicator, sheet, column, years) {

  src <- if (sheet == 'crime') crime else living
  d <- tibble(lsoa = src[['LSOA code (2021)']], annual_rate_per_1000 = src[[column]]) %>%
    inner_join(select(iod, lsoa, lad, pop), by = 'lsoa')

  map_dfr(seq_len(nrow(scenarios)), function(i) {
    # Rate as a proportion of person-years (pooled) or of residents (annual average)
    size <- if (scenarios$pooled[i]) d$pop * years else d$pop
    rate <- d$annual_rate_per_1000 / 1000
    back <- invert_shrinkage(rate, size, d$lad)
    tibble(indicator, scenario = scenarios$scenario[i], lsoa = d$lsoa, annual_rate_per_1000 = d$annual_rate_per_1000,
           count = back$r_recovered, w = back$w, se_post = sqrt(back$post_var), converged = back$converged)
  })
})

rare_reliability <- rare_inverted %>%
  group_by(indicator, scenario) %>%
  summarise(
    median_count = median(count),
    median_w = median(w),
    w_q25 = quantile(w, 0.25),
    w_q75 = quantile(w, 0.75),
    share_w_below_half = mean(w < 0.5),
    # On the logit scale, which for rare events is close to the relative standard error of the rate
    median_se_post = median(se_post),
    groups_converged = mean(converged),
    .groups = 'drop'
  ) %>%
  mutate(indicator = fct_reorder(indicator, median_w))
rare_reliability
