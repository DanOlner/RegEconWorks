# Formal confidence sets for local authority ranks on average IMD score (Mogstad, Romano, Shaikh and
# Wilhelm 2024, R package csranks)
# The simulation ranges in 07 and 15 are percentile ranges of each authority's simulated rank. csranks
# instead takes the estimates and their covariance and gives confidence sets with stated coverage:
# - marginal: each authority's set covers its true rank with 90% probability
# - simultaneous: all 296 sets cover all the true ranks at once with 90% probability, which is what a claim
#   about the whole league table needs
# - 'tau-best': the authorities that could be among the 10 most deprived, with 90% confidence
# The covariance comes from the simulated average scores, so it carries whatever error the simulation
# includes (07: Income and Employment only; 15 layer 3: all layers, with shared errors). The method assumes
# the estimates are roughly normal around the truth, which the simulated scores should satisfy
# Results are cached. Used in docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd
source('code/imd_uncertainty/functions.R')
source('code/imd_uncertainty/07_income_employment_mc.R')
source('code/imd_uncertainty/15_full_mc.R')
library(csranks)

this_script <- 'code/imd_uncertainty/16_lad_confidence_sets.R'

lad_sets <- cached('16_lad_confidence_sets',
                   depends = c(this_script, 'code/imd_uncertainty/07_income_employment_mc.R', 'code/imd_uncertainty/15_full_mc.R'),
                   key = c(n_draws, n_draws_full), expr = {

  published <- load_lad_summaries_all()
  sources <- list(
    "Income and Employment, Indices' own model (07)" = list(draws = mc07$lad_avg_score_draws, codes = mc07$lad_codes),
    'Income and Employment, correlated, design effect 2 (07)' = list(draws = mc07$lad_avg_score_draws_upper, codes = mc07$lad_codes),
    'All layers, with assumed and shared errors (15, layer 3)' = list(draws = full$lad_avg_score_draws[[full$layer_labels[4]]], codes = full$lad_codes)
  )

  imap_dfr(sources, function(src, label) {
    x <- published$avg_score[match(src$codes, published$lad)]
    Sigma <- cov(t(src$draws))
    marginal <- csranks(x, Sigma, coverage = 0.9, simul = FALSE, R = 1000, seed = 1)
    simultaneous <- csranks(x, Sigma, coverage = 0.9, simul = TRUE, R = 1000, seed = 1)
    top10 <- cstaubest(x, Sigma, tau = 10, coverage = 0.9, R = 1000, seed = 1)
    sim_q <- row_quantiles(apply(src$draws, 2, function(v) rank(-v, ties.method = 'first')), c(0.05, 0.95))
    tibble(source = label, lad = src$codes, avg_score = x,
           published_rank = published$rank_avg_score[match(src$codes, published$lad)],
           marginal_lower = marginal$L, marginal_upper = marginal$U,
           simultaneous_lower = simultaneous$L, simultaneous_upper = simultaneous$U,
           could_be_top10 = top10,
           simulation_q05 = sim_q[, 1], simulation_q95 = sim_q[, 2])
  }) %>%
    left_join(select(load_lad_summaries(), lad, lad_name), by = 'lad')
})

lad_sets_summary <- lad_sets %>%
  group_by(source) %>%
  summarise(
    median_width_simulation = median(simulation_q95 - simulation_q05),
    median_width_marginal = median(marginal_upper - marginal_lower),
    median_width_simultaneous = median(simultaneous_upper - simultaneous_lower),
    max_width_simultaneous = max(simultaneous_upper - simultaneous_lower),
    # Authorities whose simultaneous set includes rank 1 (could be the most deprived)
    could_be_most_deprived = sum(simultaneous_lower == 1),
    could_be_top10 = sum(could_be_top10),
    .groups = 'drop'
  )
lad_sets_summary

lad_sets_top <- lad_sets %>%
  filter(published_rank <= 25) %>%
  arrange(source, published_rank)
