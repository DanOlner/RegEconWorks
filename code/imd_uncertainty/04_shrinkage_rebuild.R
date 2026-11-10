# Rebuild the shrinkage step for the Income and Employment domains from the published counts,
# and see how much of the published 'pull' towards the parent area it explains
# Used in docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd (reading uncertainty from shrinkage)
#
# Parent group: the local authority, as in the IoD 2019. The IoD 2025 shrank most indicators to the
# average of LSOAs in the same area-classification supergroup within the local authority
# (technical report 3.4.3). That classification (GeoDS 2021/2 LSOAC) is open-licensed but needs a
# Geographic Data Service login to download, so it isn't used here. To use it, join each LSOA's
# supergroup code and pass paste(lad, supergroup) as the group
source('code/imd_uncertainty/functions.R')

count_domains <- load_count_domains()

# Suppressed counts (under 10) can't be used here
shrink_input <- count_domains %>% filter(!is.na(r))

rebuilt <- shrink_input %>%
  group_by(domain) %>%
  group_modify(~ bind_cols(.x, shrink_iod(.x$r, .x$size, .x$lad))) %>%
  ungroup() %>%
  mutate(
    raw_rate = r / size,
    # The pull is how far shrinkage moved each LSOA, on the logit scale
    pull_published = qlogis(published) - m,
    pull_rebuilt = m_shrunk - m,
    # Pull = (1 - w)(M - m), so the published pull implies a weight wherever M - m isn't tiny
    w_implied = if_else(abs(M - m) > 0.3, 1 - pull_published / (M - m), NA_real_)
  )


# HOW MUCH COULD ROUNDING EXPLAIN?----

# The published counts are rounded to the nearest 5, and the 'published pull' above is measured from
# those rounded counts. If the local authority parent were exactly right, how close would the two pulls be?
# Add back a uniform rounding error, shrink the 'unrounded' counts, measure the pull from the rounded
# counts as above, and correlate it with the rebuilt pull. Averaged over 20 draws
set.seed(20261110)

rounding_only <- rebuilt %>%
  group_by(domain) %>%
  group_modify(~ {
    x <- .x
    tibble(draw = 1:20) %>%
      mutate(cor_if_only_rounding = map_dbl(draw, function(d) {
        r_unrounded <- pmax(x$r + runif(nrow(x), -2.5, 2.5), 0)
        s <- shrink_iod(r_unrounded, pmax(x$size, r_unrounded), x$lad)
        cor(s$m_shrunk - x$m, x$pull_rebuilt)
      }))
  }) %>%
  summarise(cor_if_only_rounding = mean(cor_if_only_rounding), .groups = 'drop')


# SUMMARY----

rebuild_summary <- rebuilt %>%
  group_by(domain) %>%
  summarise(
    lsoas = n(),
    median_count = median(r),
    cor_rates = cor(published, rate_shrunk),
    cor_pulls = cor(pull_published, pull_rebuilt),
    median_abs_gap_raw_pp = 100 * median(abs(published - raw_rate)),
    median_abs_gap_rebuilt_pp = 100 * median(abs(published - rate_shrunk)),
    median_w = median(w),
    w_p01 = quantile(w, 0.01),
    min_w = min(w),
    median_w_implied = median(w_implied, na.rm = TRUE),
    median_se_raw = median(sqrt(s2)),
    median_se_post = median(sqrt(post_var)),
    # Relative standard error of the rate (SE / rate), roughly (1 - p) x SE on the logit scale
    median_rse_post = median((1 - published) * sqrt(post_var)),
    .groups = 'drop'
  ) %>%
  left_join(rounding_only, by = 'domain') %>%
  arrange(desc(domain))
rebuild_summary
