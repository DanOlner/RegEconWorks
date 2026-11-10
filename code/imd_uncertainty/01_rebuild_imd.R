# Rebuild the IMD 2025 score, rank and local authority summaries from the published files
# Checks that the exponential transform, domain weights and summary measures in the technical report
# reproduce the published numbers, so stages 5 to 7 can be rerun inside a simulation
# Used in llm_output/imd_rank_uncertainty_research.md, section 4.4,
# and docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd
source('code/imd_uncertainty/functions.R')

iod <- load_iod_ranks()
both <- iod %>% inner_join(load_transformed_scores(), by = 'lsoa')

stopifnot(nrow(both) == nrow(iod))


# BASICS----

# 33,755 LSOAs (2021) in 296 local authority districts (2024 boundaries)
basics <- tibble(lsoas = nrow(iod), lads = n_distinct(iod$lad))
basics

summary(iod$pop)


# EXPONENTIAL TRANSFORM----

# Apply the Appendix E transform to each published domain rank and compare with File 9.
# Differences are rounding (File 9 is published to 3 decimal places)
transform_check <- tibble(domain = domains$domain) %>%
  mutate(max_abs_diff = map_dbl(domain, ~ max(abs(exp_transform(both[[paste0(.x, '_rank')]]) - both[[paste0(.x, '_exp')]]))))
transform_check


# DOMAIN WEIGHTS----

# IMD score = weighted sum of the transformed domain scores (technical report Table 3.1)
exp_matrix <- as.matrix(both[paste0(domains$domain, '_exp')])
both <- both %>%
  mutate(
    imd_rebuilt = as.vector(exp_matrix %*% domains$weight),
    rank_rebuilt = rank(-imd_rebuilt, ties.method = 'first')
  )

# The weights are used as printed: they add to 0.999, not 1
sum(domains$weight)

# The same, but from the exact (unrounded) transform of the published domain ranks rather than File 9's
# rounded values. If this gives back every published IMD rank, the published ranks come from unrounded
# scores, and a simulation with no noise added should return them exactly
both <- both %>%
  mutate(
    imd_exact = as.vector(sapply(domains$domain, function(d) exp_transform(both[[paste0(d, '_rank')]])) %*% domains$weight),
    rank_exact = rank(-imd_exact, ties.method = 'first')
  )

rebuild_check <- both %>%
  summarise(
    max_abs_score_diff = max(abs(imd_rebuilt - imd_score)),
    correlation = cor(imd_rebuilt, imd_score),
    max_abs_rank_diff = max(abs(rank_rebuilt - imd_rank)),
    # Rank differences come from ties: the published score has 3 decimal places
    tied_published_scores = sum(duplicated(imd_score)),
    exact_rank_mismatches = sum(rank_exact != imd_rank),
    exact_max_abs_score_diff = max(abs(imd_exact - imd_score))
  )
rebuild_check


# LOCAL AUTHORITY SUMMARIES----

# Rebuild all five IMD summary measures from the LSOA data and compare them and their ranks with File 10.
# File 10 rounds the average score to 3 decimal places, average rank and local concentration to 2, and the
# proportion and extent to 4. Count a value as matching if it is within one unit of the last published digit
lad_rebuilt <- lad_summaries(iod$lad, iod$pop, iod$imd_score, iod$imd_rank)
lad_published_all <- load_lad_summaries_all()

lad_check_by_measure <- names(lad_measure_labels) %>%
  map_dfr(function(m) {
    x <- inner_join(select(lad_rebuilt, lad, value = all_of(m), rank = all_of(paste0('rank_', m))),
                    select(lad_published_all, lad, published = all_of(m), published_rank = all_of(paste0('rank_', m))), by = 'lad')
    digits <- c(avg_score = 3, avg_rank = 2, prop_10 = 4, extent = 4, local_conc = 2)[[m]]
    tibble(measure = m, lads = nrow(x),
           max_abs_diff = max(abs(x$value - x$published)),
           value_mismatches = sum(abs(x$value - x$published) > 10^-digits + 1e-9),
           rank_mismatches = sum(x$rank != x$published_rank))
  })
lad_check_by_measure

lad_check <- tibble(lads = n_distinct(lad_rebuilt$lad), measures = nrow(lad_check_by_measure),
                    measures_matching = sum(lad_check_by_measure$value_mismatches == 0 & lad_check_by_measure$rank_mismatches == 0))
lad_check


# HOW CROWDED THE SCORE SCALE IS----

# Number of LSOAs within +/-1 IMD score point of the LSOA at a given rank.
# The most deprived 10% is 3,375 LSOAs (technical report E.2.2); 16,878 is the median rank
scores_sorted <- sort(iod$imd_score, decreasing = TRUE)

crowding <- tibble(imd_rank = c(1, 100, 1000, n_most_deprived_10, 10000, 16878, 30000)) %>%
  mutate(
    imd_score = scores_sorted[imd_rank],
    lsoas_within_1_point = map_int(imd_score, ~ sum(abs(scores_sorted - .x) <= 1))
  )
crowding
