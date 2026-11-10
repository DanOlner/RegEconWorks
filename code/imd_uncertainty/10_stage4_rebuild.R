# Rebuild stage 4 (indicators to domains) from the published indicators in File 8
# Checks whether the within-domain combinations described in chapter 4 of the technical report reproduce
# the published domain and sub-domain scores in File 7. If they do, indicator-level error can be carried
# through to the IMD exactly as the Indices would (15_full_mc.R uses these builders).
# The builders are in functions.R (STAGE 4 section). What this script found:
# - The normal score is qnorm(rank / (N + 1)) with tied values sharing their average rank. It rebuilds the
#   Health domain to within File 7's rounding; the other common choices don't
# - The mental health indicator in File 8 (already a composite of normal scores) is re-standardised
#   before it enters the Health domain
# - Wider barriers is the SUM of its five normal scores, and each composite item (housing affordability,
#   overcrowding, homelessness) and the published broadband score are re-standardised first. The report
#   says 'equal weights', which is consistent, but doesn't say composites are re-standardised
# - Where File 8 values are coarsely rounded (crime rates to 1 decimal place), ties limit the rebuild
# Used in docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd
source('code/imd_uncertainty/functions.R')

f7 <- read_csv(get_iod_file('file7'), show_col_types = FALSE)
ind <- list(
  crime = load_underlying('IoD25 Crime Domain'),
  health = load_underlying('IoD25 Health Domain'),
  barriers = load_underlying('IoD25 Barriers Domain'),
  living = load_underlying('IoD25 Living Env Domain'),
  education = load_underlying('IoD25 Education Domain')
)
stopifnot(all(map_lgl(ind, ~ identical(.x[['LSOA code (2021)']], f7[['LSOA code (2021)']]))))
N <- nrow(f7)

score_col <- function(name) f7[[name]]
rank_col <- function(name) f7[[paste0(name, ' Rank (where 1 is most deprived)')]]

# Compare a rebuilt score with the published one: the score difference, and how far the ranks move
compare_rebuilt <- function(what, rebuilt, published_score, published_rank) {
  rk <- rank(-rebuilt, ties.method = 'first')
  tibble(
    what,
    correlation = cor(rebuilt, published_score),
    max_abs_score_diff = max(abs(rebuilt - published_score)),
    p99_abs_score_diff = unname(quantile(abs(rebuilt - published_score), 0.99)),
    median_abs_rank_diff = median(abs(rk - published_rank)),
    p99_abs_rank_diff = unname(quantile(abs(rk - published_rank), 0.99)),
    max_abs_rank_diff = max(abs(rk - published_rank))
  )
}


# NORMAL SCORE FORMULA----

# Which rank-to-normal formula rebuilds the Health domain best? The Health indicators are published to
# 3 decimal places with few ties, so this is the cleanest test
normal_score_variants <- list(
  'rank / (N + 1)' = function(x) qnorm(rank(x, ties.method = 'average') / (length(x) + 1)),
  '(rank - 0.5) / N' = function(x) qnorm((rank(x, ties.method = 'average') - 0.5) / length(x)),
  '(rank - 3/8) / (N + 1/4)' = function(x) qnorm((rank(x, ties.method = 'average') - 3 / 8) / (length(x) + 1 / 4))
)

normal_score_test <- imap_dfr(normal_score_variants, function(f, label) {
  h <- ind$health
  rebuilt <- 0.294 * f(h[['Comparative illness and disability ratio indicator']]) +
    0.240 * f(h[['Years of potential life lost indicator']]) +
    0.222 * f(h[['Acute morbidity indicator']]) +
    0.244 * f(h[['Mental health indicator']])
  tibble(formula = label, max_abs_score_diff = max(abs(rebuilt - score_col('Health Deprivation and Disability Score'))))
})
normal_score_test


# HOW THE WIDER BARRIERS ITEMS COMBINE----

# Regress the published sub-domain score on the five re-standardised items: coefficients of 1 and no
# intercept mean a plain sum
b <- ind$barriers
wider_items <- tibble(
  wider = score_col('Wider Barriers Sub-domain Score'),
  affordability = normal_score(b[['Housing affordability indicator']]),
  overcrowding = normal_score(normal_score(b[['Household overcrowding indicator (rooms)']]) + normal_score(b[['Household overcrowding indicator (bedrooms)']])),
  homelessness = normal_score(normal_score(b[['Core homelessness rate (% of households)']]) + normal_score(b[['Homelessness indicator (rate per 1,000 households)']])),
  broadband = normal_score(b[['Digital Connectivity (Broadband download and upload speeds)']]),
  gp_ratio = normal_score(b[['Patient-to-GP Ratio']])
)
wider_fit <- lm(wider ~ affordability + overcrowding + homelessness + broadband + gp_ratio, data = wider_items)
wider_coefficients <- enframe(coef(wider_fit), name = 'term', value = 'coefficient')
wider_coefficients


# REBUILD EACH DOMAIN AND SUB-DOMAIN----

stage4_rebuilt <- list(
  crime = build_crime(ind$crime),
  health = build_health(ind$health),
  housing_affordability = build_housing_affordability(ind$barriers),
  wider = build_wider_barriers(ind$barriers),
  indoors = build_indoors(ind$living),
  outdoors = build_outdoors(ind$living)
)

stage4_check <- bind_rows(
  compare_rebuilt('Crime domain (8 indicators, factor weights)', stage4_rebuilt$crime, score_col('Crime Score'), rank_col('Crime')),
  compare_rebuilt('Health domain (4 indicators, factor weights)', stage4_rebuilt$health, score_col('Health Deprivation and Disability Score'), rank_col('Health Deprivation and Disability')),
  compare_rebuilt('Housing affordability item (2 components)', stage4_rebuilt$housing_affordability, b[['Housing affordability indicator']], rank(-b[['Housing affordability indicator']], ties.method = 'first')),
  compare_rebuilt('Wider barriers sub-domain (5 items)', stage4_rebuilt$wider, score_col('Wider Barriers Sub-domain Score'), rank_col('Wider Barriers Sub-domain')),
  compare_rebuilt('Indoors living environment sub-domain (3)', stage4_rebuilt$indoors, score_col('Indoors Sub-domain Score'), rank_col('Indoors Sub-domain')),
  compare_rebuilt('Outdoors living environment sub-domain (3)', stage4_rebuilt$outdoors, score_col('Outdoors Sub-domain Score'), rank_col('Outdoors Sub-domain')),
  # Geographical barriers is 100 minus the connectivity score; adult skills is its one indicator
  compare_rebuilt('Geographical barriers sub-domain (1)', 100 - b[['Connectivity Score']], score_col('Geographical Barriers Sub-domain Score'), rank_col('Geographical Barriers Sub-domain')),
  compare_rebuilt('Adult skills sub-domain (1)', ind$education[['Adult skills and English language proficiency indicator']], score_col('Adult Skills Sub-domain Score'), rank_col('Adult Skills Sub-domain')),
  # Two-sub-domain domains, from the published sub-domain ranks
  compare_rebuilt('Education domain (from published sub-domain ranks)',
                  0.5 * exp_transform(rank_col('Children and Young People Sub-domain')) + 0.5 * exp_transform(rank_col('Adult Skills Sub-domain')),
                  score_col('Education, Skills and Training Score'), rank_col('Education, Skills and Training')),
  compare_rebuilt('Barriers domain (from published sub-domain ranks)',
                  0.5 * exp_transform(rank_col('Geographical Barriers Sub-domain')) + 0.5 * exp_transform(rank_col('Wider Barriers Sub-domain')),
                  score_col('Barriers to Housing and Services Score'), rank_col('Barriers to Housing and Services')),
  compare_rebuilt('Living environment domain (from published sub-domain ranks)',
                  0.7 * exp_transform(rank_col('Indoors Sub-domain')) + 0.3 * exp_transform(rank_col('Outdoors Sub-domain')),
                  score_col('Living Environment Score'), rank_col('Living Environment'))
)
stage4_check


# WHERE THE OUTDOORS REBUILD MISSES----

# The worst-fitting LSOAs all have a published road casualty rate of exactly 0. Shrinkage as Appendix C
# describes pulls every LSOA towards its parent group, so it shouldn't leave a rate of 0 (11_road_casualties.R
# looks at this with DfT's own data)
outdoors_miss <- tibble(
  lsoa = f7[['LSOA code (2021)']],
  miss = stage4_rebuilt$outdoors - score_col('Outdoors Sub-domain Score'),
  road_zero = ind$living[['Road traffic casualties involving injury to pedestrians and cyclists']] == 0
)
outdoors_miss_summary <- outdoors_miss %>%
  group_by(road_zero) %>%
  summarise(lsoas = n(), median_abs_miss = median(abs(miss)), p99_abs_miss = quantile(abs(miss), 0.99), .groups = 'drop')
outdoors_miss_summary


# HOW COARSE IS EACH PUBLISHED INDICATOR?----

# The share of LSOAs that share their published value with another LSOA. Ties come from rounding, and they
# are what stops the rebuild being exact
indicator_ties <- imap_dfr(ind, function(d, domain) {
  cols <- setdiff(names(d), c('LSOA code (2021)', 'LSOA name (2021)', 'Local Authority District code (2024)', 'Local Authority District name (2024)'))
  map_dfr(cols, ~ tibble(domain, indicator = .x, distinct_values = n_distinct(d[[.x]]),
                         share_tied = mean(duplicated(d[[.x]]) | duplicated(d[[.x]], fromLast = TRUE))))
})
indicator_ties
