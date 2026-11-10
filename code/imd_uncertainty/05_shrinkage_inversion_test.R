# Can the error behind a published shrunk rate be recovered from the rate alone?
# A synthetic test with a known answer. Make up a rare-event indicator, shrink it the IoD way, publish the
# shrunk rate, then run the shrinkage backwards from the published rates, denominators and parent groups.
# Compare what comes back with the truth.
# Used in docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd (reading uncertainty from shrinkage)
#
# The made-up indicator uses the real LSOA populations and local authorities, and true rates proportional
# to the published Income rates, scaled so the average LSOA expects a set number of events.
#
# Six cases:
# 1. Everything known: exact published rates, right denominators, right parent groups
# 2. Rates rounded the way the crime rates are (annual rate per 1,000 to 1 decimal place, 6 years of data)
# 3. As 2, but inverted with denominators 25% too small (like using residents for crime's at-risk population)
# 4. As 2, but inverted with denominators 25% too large (the opposite mistake)
# 5. As 2, but shrunk within local authority x deprivation tertile groups (standing in for the supergroups
#    used in 2025) and inverted assuming local authority groups only (groups too coarse)
# 6. As 2, but shrunk within local authorities and inverted assuming the finer tertile groups (too fine)
# It also checks a small-count interval: a gamma-Poisson (conjugate) posterior with its prior fitted to each
# parent group, against the normal-on-the-logit-scale posterior that the IoD's method implies
# Shrinking and un-shrinking with the same model makes case 1 exact by construction. What it shows is that
# the published value plus denominator plus parent group pins down the count, and so the error
source('code/imd_uncertainty/functions.R')

base <- load_iod_ranks() %>%
  transmute(lsoa, lad, p = income_score, size = pop) %>%
  group_by(lad) %>%
  mutate(lad_tertile = paste(lad, ntile(p, 3))) %>%
  ungroup()

expected_counts <- c(3, 10, 30, 100, 300)

publish_like_crime <- function(rate, years = 6) pmax(round(1000 * rate / years, 1), 0.05) * years / 1000

cases <- tribble(
  ~case,                                      ~rounded, ~size_factor, ~true_groups,  ~assumed_groups,
  'Everything known',                         FALSE,    1,            'lad',         'lad',
  'Rounded like crime',                       TRUE,     1,            'lad',         'lad',
  'Rounded, denominator 25% too small',       TRUE,     0.75,         'lad',         'lad',
  'Rounded, denominator 25% too large',       TRUE,     1.25,         'lad',         'lad',
  'Rounded, groups too coarse',               TRUE,     1,            'lad_tertile', 'lad',
  'Rounded, groups too fine',                 TRUE,     1,            'lad',         'lad_tertile'
)

# 90% interval coverage of a gamma-Poisson posterior, with a gamma prior fitted to each group by moments
gamma_poisson_coverage <- function(r, size, group, truth) {
  tibble(r, size, group, truth) %>%
    group_by(group) %>%
    mutate(
      mu = sum(r) / sum(size),
      # Spread of the true rates within the group: observed spread minus the Poisson part (floored).
      # Groups of one LSOA get the floor
      between = pmax(coalesce(var(r / size), 0) - mu * mean(1 / size), mu^2 / 100),
      a = mu^2 / between, b = mu / between,
      inside = truth >= qgamma(0.05, a + r, b + size) & truth <= qgamma(0.95, a + r, b + size)
    ) %>%
    ungroup() %>%
    summarise(coverage = mean(inside, na.rm = TRUE)) %>%
    pull(coverage)
}

set.seed(20261110)

inversion_test <- map_dfr(expected_counts, function(target) {

  scale <- target / mean(base$p * base$size)
  truth <- pmin(base$p * scale, 0.99)
  r <- rbinom(nrow(base), base$size, truth)
  z90 <- qnorm(0.95)

  pmap_dfr(cases, function(case, rounded, size_factor, true_groups, assumed_groups) {

    forward <- shrink_iod(r, base$size, base[[true_groups]])
    published <- if (rounded) publish_like_crime(forward$rate_shrunk) else forward$rate_shrunk
    back <- invert_shrinkage(published, base$size * size_factor, base[[assumed_groups]])
    se_ratio <- sqrt(back$post_var) / sqrt(forward$post_var)

    tibble(
      mean_expected_count = target,
      case,
      share_converged = mean(back$converged),
      median_w_true = median(forward$w),
      median_w_recovered = median(back$w),
      cor_counts = cor(back$r_recovered / size_factor, r),
      median_se_ratio = median(se_ratio),
      se_ratio_p10 = quantile(se_ratio, 0.1),
      se_ratio_p90 = quantile(se_ratio, 0.9),
      # Share of LSOAs whose true rate lies inside a 90% interval on the logit scale:
      # from the raw count alone, from the true posterior, and from the recovered posterior
      coverage_raw = mean(abs(qlogis(truth) - forward$m) <= z90 * sqrt(forward$s2)),
      coverage_posterior = mean(abs(qlogis(truth) - forward$m_shrunk) <= z90 * sqrt(forward$post_var)),
      coverage_recovered = mean(abs(qlogis(truth) - qlogis(published)) <= z90 * sqrt(back$post_var)),
      coverage_gamma_poisson = if (case == 'Everything known') gamma_poisson_coverage(r, base$size, base$lad, truth) else NA_real_
    )
  })
})
inversion_test
