# Do the simulated 90% rank ranges contain the true rank 90% of the time?
# 07 adds noise to the published rates and re-ranks. That gives a range around the published rank, but
# ranges built this way can miss the truth where many areas are close together. Test with a known answer:
# 1. Take the published Income and Employment rates as the truth, with the other domains fixed.
#    The true IMD ranks are then the published ones
# 2. Make an 'observed' dataset by adding error to the truth
# 3. Run the 07 simulation centred on the observed rates, and see how often each LSOA's (and local
#    authority's) 90% range contains its true rank. Repeat
# Three cases: error generated and analysed with the Indices' own model; generated with the correlated,
# design-effect-2 model and analysed with the own model (the analysis assumes too little error); and
# generated and analysed with the correlated model
# Results are cached. Used in docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd
source('code/imd_uncertainty/functions.R')

this_script <- 'code/imd_uncertainty/14_coverage_test.R'
n_replicates <- getOption('imd.n_replicates', 20)
n_draws_cov <- getOption('imd.n_draws_coverage', 400)

coverage <- cached('14_coverage_test', depends = this_script, key = c(n_replicates, n_draws_cov), expr = {

  iod <- load_iod_ranks()
  N <- nrow(iod)
  count_domains <- load_count_domains() %>% mutate(r_for_var = coalesce(r, 5), size = pmax(size, r_for_var))
  post_sd <- count_domains %>%
    group_by(domain) %>%
    group_modify(~ tibble(lsoa = .x$lsoa, r = .x$r_for_var, sd = sqrt(shrink_iod(.x$r_for_var, .x$size, .x$lad)$post_var))) %>%
    ungroup()
  sd_inc <- post_sd$sd[post_sd$domain == 'Income'][match(iod$lsoa, post_sd$lsoa[post_sd$domain == 'Income'])]
  sd_emp <- post_sd$sd[post_sd$domain == 'Employment'][match(iod$lsoa, post_sd$lsoa[post_sd$domain == 'Employment'])]
  r_inc <- post_sd$r[post_sd$domain == 'Income'][match(iod$lsoa, post_sd$lsoa[post_sd$domain == 'Income'])]
  r_emp <- post_sd$r[post_sd$domain == 'Employment'][match(iod$lsoa, post_sd$lsoa[post_sd$domain == 'Employment'])]
  rho_overlap <- pmin(sqrt(r_emp / r_inc), 0.95)

  true_inc <- qlogis(pmin(pmax(untie_by_rank(iod$income_score, iod$income_rank, bounds = c(0, 1)), 1e-9), 1 - 1e-9))
  true_emp <- qlogis(pmin(pmax(untie_by_rank(iod$employment_score, iod$employment_rank, bounds = c(0, 1)), 1e-9), 1 - 1e-9))
  w <- set_names(domains$weight, domains$domain)
  others <- setdiff(domains$domain, c('income', 'employment'))
  fixed_part <- as.vector(sapply(others, function(d) exp_transform(iod[[paste0(d, '_rank')]])) %*% w[others])

  lad_index <- as.integer(factor(iod$lad))
  n_lads <- max(lad_index)
  true_score <- w['income'] * exp_transform(iod$income_rank) + w['employment'] * exp_transform(iod$employment_rank) + fixed_part
  true_rank <- rank(-true_score, ties.method = 'first')
  true_lad_rank <- rank_lad_measures(lad_measures_fast(lad_index, iod$pop, true_score, true_rank, n_lads))

  models <- list(own = list(rho = 0, mult = 1), upper = list(rho = rho_overlap, mult = sqrt(2)))
  cases <- tribble(
    ~case,                                              ~generate, ~analyse,
    "Own model, analysed with own model",               'own',     'own',
    'Correlated, design effect 2, analysed with own model', 'upper', 'own',
    'Correlated, design effect 2, analysed with the same', 'upper', 'upper'
  )

  pmap_dfr(cases, function(case, generate, analyse) {
    g <- models[[generate]]; a <- models[[analyse]]
    map_dfr(seq_len(n_replicates), function(k) {
      set.seed(1000 + k)
      z1 <- rnorm(N); z2 <- g$rho * z1 + sqrt(1 - g$rho^2) * rnorm(N)
      obs_inc <- true_inc + g$mult * sd_inc * z1
      obs_emp <- true_emp + g$mult * sd_emp * z2
      sim <- simulate_two_domains(obs_inc, a$mult * sd_inc, obs_emp, a$mult * sd_emp, a$rho, fixed_part,
                                  lad_index, iod$pop, n_draws_cov, seed = 2000 + k, keep_ranks = TRUE)
      q <- row_quantiles(sim$imd_ranks, c(0.05, 0.95))
      inside <- true_rank >= q[, 1] & true_rank <= q[, 2]
      truly_top10 <- true_rank <= n_most_deprived_10
      lq <- row_quantiles(sim$lad_ranks[, 'avg_score', ], c(0.05, 0.95))
      lad_inside <- true_lad_rank[, 'avg_score'] >= lq[, 1] & true_lad_rank[, 'avg_score'] <= lq[, 2]
      tibble(case, replicate = k, decile = iod$imd_decile, inside = inside,
             confident_top10 = sim$p_top10 >= 0.95, truly_top10 = truly_top10) %>%
        group_by(case, replicate, decile) %>%
        summarise(coverage = mean(inside), confident_and_true = sum(confident_top10 & truly_top10), confident_top10 = sum(confident_top10), .groups = 'drop') %>%
        mutate(lad_coverage_avg_score = mean(lad_inside))
    })
  })
})

coverage_by_decile <- coverage %>%
  group_by(case, decile) %>%
  summarise(coverage = mean(coverage), .groups = 'drop')

coverage_summary <- coverage %>%
  group_by(case) %>%
  summarise(
    lsoa_coverage = mean(coverage),  # deciles are equal-sized, so the mean over deciles is the overall share
    lowest_decile_coverage = min(tapply(coverage, decile, mean)),
    # Of the LSOAs a run calls at least 95% likely to be in the most deprived 10%, the share that truly are
    top10_claims_correct = sum(confident_and_true) / sum(confident_top10),
    lad_coverage_avg_score = mean(lad_coverage_avg_score),
    replicates = n_distinct(replicate),
    .groups = 'drop'
  )
coverage_summary
