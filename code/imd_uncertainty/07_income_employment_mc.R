# Carry the chance error in the Income and Employment domains through to IMD ranks, by Monte Carlo
# Each draw perturbs every LSOA's Income and Employment rate by its posterior standard error (from the
# shrinkage rebuild, local authority parent), then reruns stages 5 to 7 exactly as published: rank, exponential
# transform, domain weights, IMD rank, and all five local authority summary measures. The other five domains
# are held at their published values.
#
# Two error models, which bracket the answer (see the review note, sections 2.1 and 2.2):
# - 'The Indices' own model': independent binomial error in each domain, as Appendix C implies.
#   This is the lower edge.
# - 'Correlated, design effect 2': the two domains' errors correlated as if every employment-deprived person
#   were also counted in the Income domain (correlation sqrt(employment count / income count) in each LSOA,
#   median about 0.6), and variances doubled for clustering (people enter and leave the counts a benefit unit
#   at a time). An upper edge, from assumptions that Stat-Xplore data could later pin down.
# A grid of intermediate assumptions is run with fewer draws and summaries only.
#
# The simulation is centred on the published ranking: tied published rates (3 decimal places) are spread
# across their rounding interval in published-rank order, and the other domains use the exact transform of
# their published ranks. So a run with no noise gives back the published ranks (checked below).
# Still chance error only, and only these two domains: no denominator error, no systematic error
# Results are cached (see cached() in functions.R). Used in docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd
source('code/imd_uncertainty/functions.R')

this_script <- 'code/imd_uncertainty/07_income_employment_mc.R'
# Fewer draws can be set for a quick test, e.g. options(imd.n_draws = 100); the cache keeps them apart
n_draws <- getOption('imd.n_draws', 2000)
n_draws_grid <- ceiling(n_draws / 2)

mc07 <- cached('07_income_employment_mc', depends = this_script, key = n_draws, expr = {

  iod <- load_iod_ranks()
  N <- nrow(iod)

  # POSTERIOR STANDARD ERRORS AND CENTRES----

  # From the shrinkage rebuild (see 04). Suppressed counts (under 10): assume a count of 5, for the variance only
  count_domains <- load_count_domains() %>% mutate(r_for_var = coalesce(r, 5), size = pmax(size, r_for_var))
  posterior <- count_domains %>%
    group_by(domain) %>%
    group_modify(~ bind_cols(select(.x, lsoa, r_for_var), select(shrink_iod(.x$r_for_var, .x$size, .x$lad), post_var))) %>%
    ungroup() %>%
    pivot_wider(names_from = domain, values_from = c(post_var, r_for_var))

  w <- set_names(domains$weight, domains$domain)
  others <- setdiff(domains$domain, c('income', 'employment'))

  both <- iod %>%
    left_join(posterior, by = 'lsoa') %>%
    mutate(
      income_centre = qlogis(pmin(pmax(untie_by_rank(income_score, income_rank, bounds = c(0, 1)), 1e-9), 1 - 1e-9)),
      employment_centre = qlogis(pmin(pmax(untie_by_rank(employment_score, employment_rank, bounds = c(0, 1)), 1e-9), 1 - 1e-9)),
      income_sd = sqrt(post_var_Income),
      employment_sd = sqrt(post_var_Employment),
      # If every employment-deprived person were also in the Income count, and people entered and left the
      # counts independently, the correlation between the two counts would be sqrt(E / I)
      rho_overlap = pmin(sqrt(r_for_var_Employment / r_for_var_Income), 0.95)
    )
  both$fixed_part <- as.vector(sapply(others, function(d) exp_transform(both[[paste0(d, '_rank')]])) %*% w[others])
  stopifnot(!anyNA(both$income_sd), !anyNA(both$employment_sd), !anyNA(both$rho_overlap))

  lad_factor <- factor(both$lad)
  lad_index <- as.integer(lad_factor)
  lad_codes <- levels(lad_factor)

  # The exact IMD rank from the published domain ranks (01 shows it matches the published rank for all
  # but one swapped pair)
  imd_exact <- w['income'] * exp_transform(both$income_rank) + w['employment'] * exp_transform(both$employment_rank) + both$fixed_part
  rank_exact <- rank(-imd_exact, ties.method = 'first')

  run <- function(rho, sd_mult, draws, seed, keep_ranks) {
    simulate_two_domains(both$income_centre, sd_mult * both$income_sd, both$employment_centre, sd_mult * both$employment_sd,
                         rho, both$fixed_part, lad_index, both$pop, draws, seed, keep_ranks)
  }

  # ZERO-NOISE CHECK----

  # With no noise the simulation must give back the published ranking
  zero <- run(0, 0, 1, 1, TRUE)
  zero_noise_check <- tibble(
    # File 7 gives the same Income rank to two LSOAs in 3 places, so up to 3 mismatches are expected there
    income_tied_published_ranks = sum(duplicated(both$income_rank)),
    income_rank_mismatches = sum(zero$income_ranks[, 1] != both$income_rank),
    employment_rank_mismatches = sum(zero$employment_ranks[, 1] != both$employment_rank),
    imd_rank_mismatches_vs_exact = sum(zero$imd_ranks[, 1] != rank_exact),
    imd_rank_mismatches_vs_published = sum(zero$imd_ranks[, 1] != both$imd_rank),
    lad_rank_mismatches = sum(zero$lad_ranks[, , 1] != rank_lad_measures(lad_measures_fast(lad_index, both$pop, imd_exact, rank_exact, length(lad_codes))))
  )

  # SUMMARIES----

  decile_breaks <- tapply(both$imd_rank, both$imd_decile, max)
  decile_of_rank <- function(rk) findInterval(rk - 1, decile_breaks) + 1
  probe_ranks <- round(seq(1, N - 5200, length.out = 300))
  gaps <- c(seq(25, 500, 25), seq(600, 2000, 100), seq(2250, 5000, 250))
  position_of <- function(rk) cut(rk, c(0, 3375, 10000, 20000, N), labels = c('Most deprived 10%', '10% to 30%', '30% to 60%', 'Least deprived 40%'))

  summarise_lsoa <- function(sim) {
    q <- row_quantiles(sim$imd_ranks, c(0.05, 0.5, 0.95))
    qi <- row_quantiles(sim$income_ranks, c(0.05, 0.95))
    qe <- row_quantiles(sim$employment_ranks, c(0.05, 0.95))
    decile_draws <- matrix(decile_of_rank(sim$imd_ranks), nrow = nrow(sim$imd_ranks))
    decile_probs <- sapply(1:10, function(k) rowMeans(decile_draws == k))
    rm(decile_draws)
    colnames(decile_probs) <- paste0('p_decile_', 1:10)
    lsoa <- both %>%
      select(lsoa, lad, lad_name, imd_rank, imd_decile, income_rank, employment_rank) %>%
      mutate(rank_q05 = q[, 1], rank_median = q[, 2], rank_q95 = q[, 3], width_90 = rank_q95 - rank_q05,
             income_width_90 = qi[, 2] - qi[, 1], employment_width_90 = qe[, 2] - qe[, 1],
             p_most_deprived_10 = sim$p_top10,
             deciles_spanned = decile_of_rank(rank_q95) - decile_of_rank(rank_q05) + 1) %>%
      bind_cols(as_tibble(decile_probs))
    sep <- separation_curves(sim$imd_ranks, both$imd_rank, probe_ranks, gaps)
    list(lsoa = lsoa, separation = sep)
  }

  summarise_lad <- function(sim) {
    published <- load_lad_summaries_all()
    idx <- match(lad_codes, published$lad)
    imap_dfr(set_names(names(lad_measure_labels)), function(measure, i) {
      rk <- matrix(sim$lad_ranks[, measure, ], nrow = dim(sim$lad_ranks)[1])
      qq <- row_quantiles(rk, c(0.05, 0.5, 0.95))
      pub_rank <- published[[paste0('rank_', measure)]][idx]
      pub_value <- published[[measure]][idx]
      ord <- order(pub_rank)
      p_hold <- map_dbl(seq_len(length(ord) - 1), ~ mean(rk[ord[.x], ] < rk[ord[.x + 1], ]))
      tibble(lad = lad_codes, measure = measure, published_rank = pub_rank, published_value = pub_value,
             rank_q05 = qq[, 1], rank_median = qq[, 2], rank_q95 = qq[, 3], width_90 = qq[, 3] - qq[, 1],
             # For each authority, whether its order with the next one down the published ranking holds in 95% of draws
             next_pair_holds_95 = c(p_hold >= 0.95, NA)[order(ord)])
    }) %>%
      left_join(select(load_lad_summaries(), lad, lad_name), by = 'lad')
  }

  # MAIN RUNS----

  model_labels <- c(own = "The Indices' own model", upper = 'Correlated, design effect 2')

  main <- run(0, 1, n_draws, 20261110, TRUE)
  main_lsoa <- summarise_lsoa(main)
  main_lad <- summarise_lad(main)
  # Simulated local authority average scores, for formal confidence sets (16)
  lad_avg_score_draws <- main$lad_values[, 'avg_score', ]
  rm(main); gc()

  upper <- run(both$rho_overlap, sqrt(2), n_draws, 20261111, TRUE)
  upper_lsoa <- summarise_lsoa(upper)
  upper_lad <- summarise_lad(upper)
  lad_avg_score_draws_upper <- upper$lad_values[, 'avg_score', ]
  rm(upper); gc()

  # SENSITIVITY GRID----

  # Summaries only, fewer draws. Widths come from the LAD and top-10% outputs, so LSOA rank draws are kept
  # one scenario at a time
  grid <- expand_grid(correlation = c('None', 'Overlap model (median about 0.6)', '0.8 everywhere'), design_effect = c(1, 1.5, 2))
  sensitivity <- pmap_dfr(grid, function(correlation, design_effect) {
    rho <- switch(correlation, 'None' = 0, 'Overlap model (median about 0.6)' = both$rho_overlap, '0.8 everywhere' = 0.8)
    sim <- run(rho, sqrt(design_effect), n_draws_grid, 7, TRUE)
    q <- row_quantiles(sim$imd_ranks, c(0.05, 0.95))
    width <- q[, 2] - q[, 1]
    lad_w <- row_quantiles(sim$lad_ranks[, 'avg_score', ], c(0.05, 0.95))
    tibble(correlation, design_effect,
           median_width_90 = median(width),
           median_width_decile1 = median(width[both$imd_decile == 1]),
           published_top10_below_95 = sum(both$imd_rank <= n_most_deprived_10 & sim$p_top10 < 0.95),
           uncertain_top10_status = sum(sim$p_top10 > 0.05 & sim$p_top10 < 0.95),
           lad_avg_score_median_width = median(lad_w[, 2] - lad_w[, 1]))
  })

  list(
    zero_noise_check = zero_noise_check,
    rho_overlap_summary = quantile(both$rho_overlap, c(0.1, 0.25, 0.5, 0.75, 0.9)),
    lsoa = bind_rows(main_lsoa$lsoa %>% mutate(model = model_labels['own']), upper_lsoa$lsoa %>% mutate(model = model_labels['upper'])),
    separation = bind_rows(main_lsoa$separation %>% mutate(model = model_labels['own']), upper_lsoa$separation %>% mutate(model = model_labels['upper'])) %>%
      mutate(position = position_of(probe_rank)),
    lad = bind_rows(main_lad %>% mutate(model = model_labels['own']), upper_lad %>% mutate(model = model_labels['upper'])),
    lad_codes = lad_codes,
    lad_avg_score_draws = lad_avg_score_draws,
    lad_avg_score_draws_upper = lad_avg_score_draws_upper,
    sensitivity = sensitivity,
    model_labels = model_labels
  )
})


# RESULTS FOR THE REPORT----

model_labels <- mc07$model_labels
zero_noise_check <- mc07$zero_noise_check
zero_noise_check
lsoa_mc <- mc07$lsoa
mc_sensitivity <- mc07$sensitivity

lsoa_summary <- lsoa_mc %>%
  group_by(model) %>%
  summarise(
    median_width_90 = median(width_90),
    median_width_decile1 = median(width_90[imd_decile == 1]),
    median_width_decile10 = median(width_90[imd_decile == 10]),
    share_spanning_2plus_deciles = mean(deciles_spanned >= 2),
    share_spanning_3plus_deciles = mean(deciles_spanned >= 3),
    uncertain_top10_status = sum(p_most_deprived_10 > 0.05 & p_most_deprived_10 < 0.95),
    published_top10_below_95 = sum(imd_rank <= n_most_deprived_10 & p_most_deprived_10 < 0.95),
    published_top10 = sum(imd_rank <= n_most_deprived_10),
    median_income_width_90 = median(income_width_90),
    median_employment_width_90 = median(employment_width_90),
    .groups = 'drop'
  )
lsoa_summary

# Interval width by position in the published ranking, in bands of 500 ranks
lsoa_width_by_rank <- lsoa_mc %>%
  mutate(band_mid = (ceiling(imd_rank / 500) - 0.5) * 500) %>%
  group_by(model, band_mid) %>%
  summarise(median_width = median(width_90), q25 = quantile(width_90, 0.25), q75 = quantile(width_90, 0.75), .groups = 'drop')

# Domain rank ranges on their own (the Income and Employment domain ranks are published and used too)
domain_width_by_decile <- lsoa_mc %>%
  filter(model == model_labels['own']) %>%
  mutate(income_decile = ceiling(income_rank / (nrow(.) / 10)), employment_decile = ceiling(employment_rank / (nrow(.) / 10))) %>%
  { bind_rows(
      group_by(., decile = income_decile) %>% summarise(median_width = median(income_width_90), .groups = 'drop') %>% mutate(domain = 'Income'),
      group_by(., decile = employment_decile) %>% summarise(median_width = median(employment_width_90), .groups = 'drop') %>% mutate(domain = 'Employment')
    ) }

separation <- mc07$separation
separation_by_position <- separation %>%
  group_by(model, position, probe_rank) %>%
  summarise(gap_needed_95 = gap_needed(gap, p_order_holds), .groups = 'drop') %>%
  group_by(model, position) %>%
  summarise(lsoas_checked = n(), median_gap_needed = median(gap_needed_95, na.rm = TRUE), never_reached = sum(is.na(gap_needed_95)), .groups = 'drop')
separation_by_position

separation_curve_by_position <- separation %>%
  group_by(model, position, gap) %>%
  summarise(p_order_holds = mean(p_order_holds), .groups = 'drop')

lad_mc <- mc07$lad
lad_summary <- lad_mc %>%
  # Authorities with no LSOAs in the most deprived 10% (or none in the most deprived 30%, for extent) tie at
  # the bottom; leave them out of those measures
  filter(!(measure %in% c('prop_10', 'extent') & published_value == 0)) %>%
  group_by(model, measure) %>%
  summarise(lads = n(), median_width_90 = median(width_90), max_width_90 = max(width_90),
            adjacent_pairs_separable_95 = mean(next_pair_holds_95, na.rm = TRUE), .groups = 'drop') %>%
  mutate(measure = factor(measure, levels = names(lad_measure_labels))) %>%
  arrange(model, measure)
lad_summary

n_draws_used <- n_draws


# OUTPUT FILE----

# One row per LSOA: published rank, simulated range and the probability of each decile, under both models
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
lsoa_mc %>%
  mutate(model = if_else(model == model_labels['own'], 'own_model', 'correlated_deff2')) %>%
  select(model, lsoa, lad, lad_name, imd_rank, imd_decile, rank_q05, rank_median, rank_q95, p_most_deprived_10, starts_with('p_decile_')) %>%
  mutate(across(starts_with('p_'), ~ round(.x, 3))) %>%
  write_csv(file.path(output_dir, 'lsoa_imd_rank_ranges_income_employment.csv'))
