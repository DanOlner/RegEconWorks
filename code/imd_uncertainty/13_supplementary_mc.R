# Rank ranges for the two supplementary indices: IDACI (children aged 0 to 15 in income-deprived families)
# and IDAOPI (people aged 60 and over in income-deprived families)
# These are ranked on their own, not part of the IMD, and IDACI in particular is used outside the Indices.
# Their counts are much smaller than the Income domain's (medians of 85 and 60 against 310), so their ranks
# should be much less certain. Same error model as the 'Indices' own model' in 07: independent binomial
# error, shrinkage posterior with local authority parents, normal on the logit scale, centred on the
# published (untied) rate. Suppressed counts (under 10, about 2.5% of LSOAs) use the count recovered by
# running the shrinkage backwards (08)
# Results are cached. Used in docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd
source('code/imd_uncertainty/functions.R')
source('code/imd_uncertainty/08_inversion_real_counts.R')

this_script <- 'code/imd_uncertainty/13_supplementary_mc.R'
n_draws_supp <- getOption('imd.n_draws', 2000)

supp <- cached('13_supplementary_mc', depends = c(this_script, 'code/imd_uncertainty/08_inversion_real_counts.R'), key = n_draws_supp, expr = {

  f7 <- read_csv(get_iod_file('file7'), show_col_types = FALSE)
  published_rank <- list(
    IDACI = f7[['Income Deprivation Affecting Children Index (IDACI) Rank (where 1 is most deprived)']],
    IDAOPI = f7[['Income Deprivation Affecting Older People (IDAOPI) Rank (where 1 is most deprived)']]
  )
  N <- nrow(f7)

  map_dfr(c('IDACI', 'IDAOPI'), function(ind) {
    d <- supplementary_counts %>% filter(indicator == ind)
    stopifnot(identical(d$lsoa, f7[['LSOA code (2021)']]))
    sd_logit <- sqrt(shrink_iod(d$r_used, pmax(d$size, d$r_used), d$lad)$post_var)
    centre <- qlogis(pmin(pmax(untie_by_rank(d$published_rate, published_rank[[ind]], bounds = c(0, 1)), 1e-9), 1 - 1e-9))

    set.seed(20261112)
    ranks <- matrix(0L, N, n_draws_supp)
    for (k in seq_len(n_draws_supp)) ranks[, k] <- rank(-(centre + sd_logit * rnorm(N)), ties.method = 'random')
    q <- row_quantiles(ranks, c(0.05, 0.5, 0.95))
    pub <- published_rank[[ind]]
    tibble(indicator = ind, lsoa = d$lsoa, lad = d$lad, published_rank = pub, count = d$r_used, suppressed = d$suppressed,
           # With no noise the published rank should come back, except where File 7 gives two LSOAs the same rank
           zero_noise_ok = rank(-centre, ties.method = 'first') == pub | pub %in% pub[duplicated(pub)],
           rank_q05 = q[, 1], rank_median = q[, 2], rank_q95 = q[, 3], width_90 = q[, 3] - q[, 1],
           p_most_deprived_10 = rowMeans(ranks <= n_most_deprived_10),
           p_most_deprived_20 = rowMeans(ranks <= 2 * n_most_deprived_10 + 1))
  })
})

supplementary_summary <- supp %>%
  group_by(indicator) %>%
  summarise(
    zero_noise_mismatches = sum(!zero_noise_ok),
    median_count = median(count),
    median_width_90 = median(width_90),
    median_width_decile1 = median(width_90[published_rank <= n_most_deprived_10]),
    published_top10_below_95 = sum(published_rank <= n_most_deprived_10 & p_most_deprived_10 < 0.95),
    uncertain_top10_status = sum(p_most_deprived_10 > 0.05 & p_most_deprived_10 < 0.95),
    # Deciles spanned by the 90% range, using fixed decile cut-offs of N / 10
    share_spanning_2plus_deciles = mean(ceiling(rank_q95 / (n() / 10)) - ceiling(rank_q05 / (n() / 10)) >= 1),
    share_spanning_3plus_deciles = mean(ceiling(rank_q95 / (n() / 10)) - ceiling(rank_q05 / (n() / 10)) >= 2),
    .groups = 'drop'
  )
supplementary_summary

supplementary_width_by_rank <- supp %>%
  mutate(band_mid = (ceiling(published_rank / 500) - 0.5) * 500) %>%
  group_by(indicator, band_mid) %>%
  summarise(median_width = median(width_90), q25 = quantile(width_90, 0.25), q75 = quantile(width_90, 0.75), .groups = 'drop')

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
supp %>%
  select(indicator, lsoa, lad, published_rank, rank_q05, rank_median, rank_q95, p_most_deprived_10, p_most_deprived_20) %>%
  mutate(across(starts_with('p_'), ~ round(.x, 3))) %>%
  write_csv(file.path(output_dir, 'lsoa_idaci_idaopi_rank_ranges.csv'))
