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

rebuild_check <- both %>%
  summarise(
    max_abs_score_diff = max(abs(imd_rebuilt - imd_score)),
    correlation = cor(imd_rebuilt, imd_score),
    max_abs_rank_diff = max(abs(rank_rebuilt - imd_rank)),
    # Rank differences come from ties: the published score has 3 decimal places
    tied_published_scores = sum(duplicated(imd_score))
  )
rebuild_check


# LOCAL AUTHORITY SUMMARIES----

# Rebuild average score, average rank and proportion in the most deprived 10% from the LSOA data,
# and compare them and their ranks with File 10.
# File 10's average rank counts LSOA ranks the other way round (33,755 = most deprived), so compare
# with N + 1 minus ours. File 10 gives the proportion to 4 decimal places
lad_check <- lad_summaries(iod$lad, iod$pop, iod$imd_score, iod$imd_rank) %>%
  inner_join(load_lad_summaries(), by = 'lad', suffix = c('', '_published')) %>%
  summarise(
    lads = n(),
    max_abs_avg_score_diff = max(abs(avg_score - avg_score_published)),
    avg_score_rank_mismatches = sum(rank_avg_score != rank_avg_score_published),
    max_abs_avg_rank_diff = max(abs((nrow(iod) + 1 - avg_rank) - avg_rank_published)),
    avg_rank_rank_mismatches = sum(rank_avg_rank != rank_avg_rank_published),
    prop_10_mismatches = sum(abs(round(prop_10, 4) - prop_10_published) > 1e-9),
    prop_10_rank_mismatches = sum(rank_prop_10 != rank_prop_10_published)
  )
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
