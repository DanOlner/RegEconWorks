# Carry the chance error in the Income and Employment domains through to IMD ranks, by Monte Carlo
# Each draw perturbs every LSOA's Income and Employment rate by its posterior standard error (from the
# shrinkage rebuild, local authority parent), then reruns stages 5 to 7 exactly as published: rank, exponential
# transform, domain weights, IMD rank, and the local authority summaries. The other five domains are held at
# their published values.
# So this is a lower bound on IMD rank uncertainty: two domains (45% of the weight), chance error only,
# no denominator error, no systematic error, no error in the other domains
# Used in docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd
source('code/imd_uncertainty/functions.R')

n_draws <- 500

iod <- load_iod_ranks()
both <- iod %>% inner_join(load_transformed_scores(), by = 'lsoa')


# POSTERIOR STANDARD ERRORS----

# From the shrinkage rebuild (see 04). Suppressed counts (under 10): assume a count of 5, for the variance only
posterior <- load_count_domains() %>%
  mutate(r_for_var = coalesce(r, 5), size = pmax(size, r_for_var)) %>%
  group_by(domain) %>%
  group_modify(~ bind_cols(select(.x, lsoa), select(shrink_iod(.x$r_for_var, .x$size, .x$lad), post_var))) %>%
  ungroup() %>%
  pivot_wider(names_from = domain, values_from = post_var, names_prefix = 'post_var_')

w <- set_names(domains$weight, domains$domain)

both <- both %>%
  left_join(posterior, by = 'lsoa') %>%
  mutate(
    # Centre each draw on the published (shrunk) rate, on the logit scale
    income_centre = qlogis(pmin(pmax(income_score, 0.0005), 0.9995)),
    employment_centre = qlogis(pmin(pmax(employment_score, 0.0005), 0.9995)),
    income_sd = sqrt(post_var_Income),
    employment_sd = sqrt(post_var_Employment),
    fixed_part = w['education'] * education_exp + w['health'] * health_exp +
      w['crime'] * crime_exp + w['barriers'] * barriers_exp + w['living'] * living_exp
  )

stopifnot(!anyNA(both$income_sd), !anyNA(both$employment_sd))


# SIMULATION----

N <- nrow(both)
lad_factor <- factor(both$lad)
lad_index <- as.integer(lad_factor)
lad_codes <- levels(lad_factor)
lad_pop <- as.vector(rowsum(both$pop, lad_index))
lad_lsoas <- as.vector(rowsum(rep(1, N), lad_index))

rank_draws <- matrix(0L, N, n_draws)
lad_rank_draws <- list(
  avg_score = matrix(0L, length(lad_codes), n_draws),
  avg_rank = matrix(0L, length(lad_codes), n_draws),
  prop_10 = matrix(0L, length(lad_codes), n_draws)
)

set.seed(20261110)

for (d in seq_len(n_draws)) {

  income_draw <- both$income_centre + both$income_sd * rnorm(N)
  employment_draw <- both$employment_centre + both$employment_sd * rnorm(N)

  score <- w['income'] * exp_transform(rank(-income_draw, ties.method = 'random')) +
    w['employment'] * exp_transform(rank(-employment_draw, ties.method = 'random')) +
    both$fixed_part
  imd_rank_draw <- rank(-score, ties.method = 'first')
  rank_draws[, d] <- imd_rank_draw

  avg_score <- as.vector(rowsum(score * both$pop, lad_index)) / lad_pop
  avg_rank <- as.vector(rowsum(imd_rank_draw * both$pop, lad_index)) / lad_pop
  prop_10 <- as.vector(rowsum(as.numeric(imd_rank_draw <= n_most_deprived_10), lad_index)) / lad_lsoas

  lad_rank_draws$avg_score[, d] <- rank(-avg_score, ties.method = 'first')
  lad_rank_draws$avg_rank[, d] <- rank(avg_rank, ties.method = 'first')
  lad_rank_draws$prop_10[, d] <- rank(-prop_10, ties.method = 'min')
}


# LSOA RESULTS----

row_quantiles <- function(m, probs) t(apply(m, 1, quantile, probs = probs, type = 1, names = FALSE))

# Published decile boundaries: the highest rank in each decile
decile_breaks <- tapply(both$imd_rank, both$imd_decile, max)
decile_of_rank <- function(rk) findInterval(rk - 1, decile_breaks) + 1

q <- row_quantiles(rank_draws, c(0.05, 0.5, 0.95))

lsoa_mc <- both %>%
  select(lsoa, lad, lad_name, imd_rank, imd_decile) %>%
  mutate(
    rank_q05 = q[, 1],
    rank_median = q[, 2],
    rank_q95 = q[, 3],
    width_90 = rank_q95 - rank_q05,
    p_most_deprived_10 = rowMeans(rank_draws <= n_most_deprived_10),
    deciles_spanned = decile_of_rank(rank_q95) - decile_of_rank(rank_q05) + 1
  )

# Interval width by position in the published ranking, in bands of 500 ranks
lsoa_width_by_rank <- lsoa_mc %>%
  mutate(band_mid = (ceiling(imd_rank / 500) - 0.5) * 500) %>%
  group_by(band_mid) %>%
  summarise(median_width = median(width_90), q25 = quantile(width_90, 0.25), q75 = quantile(width_90, 0.75), .groups = 'drop')

lsoa_summary <- lsoa_mc %>%
  summarise(
    median_width_90 = median(width_90),
    median_width_decile1 = median(width_90[imd_decile == 1]),
    median_width_decile10 = median(width_90[imd_decile == 10]),
    share_spanning_2plus_deciles = mean(deciles_spanned >= 2),
    share_spanning_3plus_deciles = mean(deciles_spanned >= 3),
    uncertain_top10_status = sum(p_most_deprived_10 > 0.05 & p_most_deprived_10 < 0.95),
    published_top10_below_95 = sum(imd_rank <= n_most_deprived_10 & p_most_deprived_10 < 0.95),
    published_top10 = sum(imd_rank <= n_most_deprived_10)
  )

# How far apart in the published ranking do two LSOAs have to be before the more deprived one comes out
# more deprived in at least 95% of draws? Checked for 300 LSOAs spread evenly through the ranking
by_published_rank <- order(both$imd_rank)
gaps <- c(10, 25, 50, 75, 100, 150, 200, 300, 400, 500, 750, 1000, 1250, 1500, 2000, 2500, 3000, 4000, 5000)
probe_ranks <- round(seq(1, N - max(gaps), length.out = 300))

separation <- map_dfr(probe_ranks, function(rk) {
  a <- by_published_rank[rk]
  p <- map_dbl(gaps, function(g) mean(rank_draws[a, ] < rank_draws[by_published_rank[rk + g], ]))
  tibble(imd_rank = rk, gap_needed_95 = gaps[which(p >= 0.95)[1]])
})

separation_by_position <- separation %>%
  mutate(position = cut(imd_rank, c(0, 3375, 10000, 20000, N), labels = c('Most deprived 10%', '10% to 30%', '30% to 60%', 'Least deprived 40%'))) %>%
  group_by(position) %>%
  summarise(lsoas_checked = n(), median_gap_needed = median(gap_needed_95), .groups = 'drop')


# LOCAL AUTHORITY RESULTS----

lad_published <- load_lad_summaries()

lad_mc <- imap_dfr(lad_rank_draws, function(m, measure) {
  qq <- row_quantiles(m, c(0.05, 0.5, 0.95))
  tibble(lad = lad_codes, measure, rank_q05 = qq[, 1], rank_median = qq[, 2], rank_q95 = qq[, 3])
}) %>%
  left_join(
    lad_published %>%
      select(lad, lad_name, avg_score = rank_avg_score, avg_rank = rank_avg_rank, prop_10 = rank_prop_10, prop_10_value = prop_10) %>%
      pivot_longer(c(avg_score, avg_rank, prop_10), names_to = 'measure', values_to = 'published_rank'),
    by = c('lad', 'measure')
  ) %>%
  mutate(width_90 = rank_q95 - rank_q05)

# Adjacent pairs in the published ranking: how often does the more deprived one stay ahead?
adjacent_pairs <- imap_dfr(lad_rank_draws, function(m, measure) {
  published <- lad_published[[c(avg_score = 'rank_avg_score', avg_rank = 'rank_avg_rank', prop_10 = 'rank_prop_10')[measure]]]
  idx <- match(lad_codes, lad_published$lad)
  ord <- order(published[idx])
  tibble(measure, pair = seq_len(length(ord) - 1),
         p_order_holds = map_dbl(pair, ~ mean(m[ord[.x], ] < m[ord[.x + 1], ])))
})

lad_summary <- lad_mc %>%
  # Many authorities have no LSOAs in the most deprived 10% and tie at the bottom; leave them out of that measure
  filter(!(measure == 'prop_10' & prop_10_value == 0)) %>%
  group_by(measure) %>%
  summarise(lads = n(), median_width_90 = median(width_90), max_width_90 = max(width_90), .groups = 'drop') %>%
  left_join(
    adjacent_pairs %>% group_by(measure) %>% summarise(adjacent_pairs_separable_95 = mean(p_order_holds >= 0.95), .groups = 'drop'),
    by = 'measure'
  )
lad_summary
