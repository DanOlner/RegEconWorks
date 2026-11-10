# Carry error in many indicators through stages 4 to 7, in three layers
# 07 perturbs only the Income and Employment domains. This perturbs indicators inside the other domains too,
# rebuilds each domain with the stage 4 builders (functions.R, checked in 10), then reruns stages 5 to 7.
#
# Layers (each includes the one before):
# 1. Income and Employment chance error, the Indices' own model (as 07)
# 2. Plus the chance error that open data can size: the 8 crime indicators (06's inversion; 'annual average'
#    reading, with the 'pooled' reading as a variant), overcrowding and adult skills (12, Census), and road
#    casualties (11, DfT's own records)
# 3. Plus ASSUMED errors for everything else, including errors shared by all LSOAs in a local authority:
#    health indicators, the children and young people education sub-domain, the modelled indicators,
#    homelessness (supplied at local authority level) and the population denominators. The sizes are
#    order-of-magnitude guesses, listed in the 'assumed_errors' table below, not estimates
#
# Delta method: each domain or sub-domain score in a draw is its published score (untied by published rank)
# plus the change the perturbation makes to the rebuilt score. The change is computed first, in brackets:
# (published + rebuilt) - zero isn't exactly the published value in floating point, and that tiny error would
# break ties in rounded inputs. So with no noise the published ranks come back
# exactly, and rounding in File 8 doesn't move the starting point.
# Results are cached. Used in docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd
source('code/imd_uncertainty/functions.R')

this_script <- 'code/imd_uncertainty/15_full_mc.R'
n_draws_full <- ceiling(getOption('imd.n_draws', 2000) / 2)

# ASSUMED ERRORS (layer 3)----

# scale: 'log' (relative error), 'logit', or 'add' (in the indicator's own units).
# shared: the share of the error variance common to every LSOA in a local authority
assumed_errors <- tribble(
  ~item,                                   ~scale,  ~sd,    ~shared, ~basis,
  'Comparative illness and disability ratio', 'log', NA,     0,       'Poisson error for about 150 claimants in an average LSOA (rough national total), scaled by the ratio',
  'Years of potential life lost',          'log',   NA,     0,       'About 20 deaths under 75 in five years in an average LSOA, inflated 1.5 times for the age weighting',
  'Acute morbidity',                       'log',   NA,     0,       'About 200 emergency admissions in two years in an average LSOA, inflated 1.5 times for repeat admissions',
  'Mental health indicator',               'add',   0.15,   0,       'One fifth of the spread of the published composite score',
  'Children and young people sub-domain',  'add',   0.20,   0,       'About a quarter of the spread of the published sub-domain score (pupil data not public)',
  'Connectivity score',                    'add',   2,      0.5,     'Model error of 2 points on a 0 to 100 score',
  'Housing affordability components',      'logit', 0.20,   0.5,     'Model error; half shared, as the model works at housing market area level',
  'Homelessness (both indicators)',        'log',   0.15,   1,       'Supplied at local authority level, so the whole error is shared',
  'Broadband speed',                       'add',   0.10,   0,       'Small measurement error in the published score',
  'Patient-to-GP ratio',                   'log',   0.05,   0,       'Error in sharing practice figures out to LSOAs',
  'Housing in poor condition',             'logit', 0.30,   0.5,     'Model error (national survey scaled down to dwellings); half shared',
  'Housing energy performance',            'add',   1,      0,       'Imputation for the 40% of homes without a valid EPC',
  'Housing lacking private outdoor space', 'add',   2,      0,       'Imputation of implausible values',
  'Air quality',                           'log',   0.10,   0.5,     'Model error on a 1 km grid; half shared',
  'Noise',                                 'logit', 0.30,   0.5,     'Model error; half shared',
  'Population denominators',               'log',   0.03,   0.5,     'About 2% error in local authority totals (ONS publishes intervals of this order) and 2% within; applied to Income and Employment rates'
)

full <- cached('15_full_mc', depends = c(this_script, 'code/imd_uncertainty/06_rare_event_reliability.R',
                                         'code/imd_uncertainty/11_road_casualties.R', 'code/imd_uncertainty/12_census_indicators.R'),
               key = n_draws_full, expr = {

  source('code/imd_uncertainty/06_rare_event_reliability.R', local = TRUE)
  source('code/imd_uncertainty/11_road_casualties.R', local = TRUE)
  source('code/imd_uncertainty/12_census_indicators.R', local = TRUE)

  f7 <- read_csv(get_iod_file('file7'), show_col_types = FALSE)
  iod <- load_iod_ranks()
  N <- nrow(iod)
  lsoa <- iod$lsoa
  lad_index <- as.integer(factor(iod$lad))
  n_lads <- max(lad_index)
  w <- set_names(domains$weight, domains$domain)

  ind <- list(
    crime = load_underlying('IoD25 Crime Domain'), health = load_underlying('IoD25 Health Domain'),
    barriers = load_underlying('IoD25 Barriers Domain'), living = load_underlying('IoD25 Living Env Domain')
  )
  stopifnot(all(map_lgl(ind, ~ identical(.x[['LSOA code (2021)']], lsoa))))

  # Published score untied by published rank: the base each draw's change is added to
  base_of <- function(score_name, rank_name) untie_by_rank(f7[[score_name]], f7[[rank_name]])
  rank_name <- function(x) paste0(x, ' Rank (where 1 is most deprived)')
  base <- list(
    crime = base_of('Crime Score', rank_name('Crime')),
    health = base_of('Health Deprivation and Disability Score', rank_name('Health Deprivation and Disability')),
    cyp = base_of('Children and Young People Sub-domain Score', rank_name('Children and Young People Sub-domain')),
    skills = base_of('Adult Skills Sub-domain Score', rank_name('Adult Skills Sub-domain')),
    geog = base_of('Geographical Barriers Sub-domain Score', rank_name('Geographical Barriers Sub-domain')),
    wider = base_of('Wider Barriers Sub-domain Score', rank_name('Wider Barriers Sub-domain')),
    indoors = base_of('Indoors Sub-domain Score', rank_name('Indoors Sub-domain')),
    outdoors = base_of('Outdoors Sub-domain Score', rank_name('Outdoors Sub-domain'))
  )
  zero <- list(crime = build_crime(ind$crime), health = build_health(ind$health), wider = build_wider_barriers(ind$barriers),
               indoors = build_indoors(ind$living), outdoors = build_outdoors(ind$living))

  # STANDARD ERRORS----

  # Income and Employment: as 07 (own model)
  count_domains <- load_count_domains() %>% mutate(r_for_var = coalesce(r, 5), size = pmax(size, r_for_var))
  ie_sd <- count_domains %>%
    group_by(domain) %>%
    group_modify(~ tibble(lsoa = .x$lsoa, sd = sqrt(shrink_iod(.x$r_for_var, .x$size, .x$lad)$post_var))) %>%
    ungroup()
  sd_inc <- ie_sd$sd[ie_sd$domain == 'Income'][match(lsoa, ie_sd$lsoa[ie_sd$domain == 'Income'])]
  sd_emp <- ie_sd$sd[ie_sd$domain == 'Employment'][match(lsoa, ie_sd$lsoa[ie_sd$domain == 'Employment'])]
  centre_inc <- qlogis(pmin(pmax(untie_by_rank(iod$income_score, iod$income_rank, bounds = c(0, 1)), 1e-9), 1 - 1e-9))
  centre_emp <- qlogis(pmin(pmax(untie_by_rank(iod$employment_score, iod$employment_rank, bounds = c(0, 1)), 1e-9), 1 - 1e-9))

  # Crime: posterior SEs from 06 (logit scale, close to relative error for rare rates)
  crime_map <- c(
    'Violence with injury' = "Violence with injury, rate per 1,000 'at-risk population'",
    'Violence without injury' = "Violence without injury, rate per 1,000 'at-risk population'",
    'Stalking and harassment' = "Stalking and harassment, rate per 1,000 'at-risk population'",
    'Theft' = "Theft, rate per 1,000 'at-risk population'",
    'Criminal damage' = "Criminal damage, rate per 1,000 'at-risk population'",
    'Public order and weapons' = "Public order and Possession of weapons, rate per 1,000 'at-risk population'",
    'Anti-social behaviour' = "Anti-Social Behaviour, rate per 1,000 'at-risk population'"
  )
  crime_se <- map(c(annual = 'Annual average count', pooled = 'Counts pooled over all years'), function(sc) {
    out <- map(crime_map, function(col) NULL)
    for (nm in names(crime_map)) {
      x <- rare_inverted %>% filter(indicator == nm, scenario == sc)
      out[[crime_map[[nm]]]] <- x$se_post[match(lsoa, x$lsoa)]
    }
    out <- out[crime_map]
    # Burglary: invert with Census households standing in for 'at-risk properties' (which also count
    # non-residential properties, so this overstates the error a little)
    burg <- ind$crime[["Burglary, rate per 1,000 'at-risk properties'"]] / 1000
    hh <- census$households[match(lsoa, census$lsoa)]
    size <- if (sc == 'Annual average count') hh else hh * 6
    out[["Burglary, rate per 1,000 'at-risk properties'"]] <- sqrt(invert_shrinkage(burg, size, iod$lad)$post_var)
    out
  })

  over_se <- list(
    rooms = census_errors$se_logit[census_errors$indicator == 'Overcrowding, rooms'][match(lsoa, census_errors$lsoa[census_errors$indicator == 'Overcrowding, rooms'])],
    bedrooms = census_errors$se_logit[census_errors$indicator == 'Overcrowding, bedrooms'][match(lsoa, census_errors$lsoa[census_errors$indicator == 'Overcrowding, bedrooms'])],
    skills = census_errors$se_logit[census_errors$indicator == 'Adult skills'][match(lsoa, census_errors$lsoa[census_errors$indicator == 'Adult skills'])]
  )
  road_se <- road_errors$se_log[match(lsoa, road_errors$lsoa)]
  stopifnot(!anyNA(unlist(crime_se)), !anyNA(unlist(over_se)), !anyNA(road_se))

  # Layer 3 health errors from the assumed counts
  h <- ind$health
  health_se <- list(
    cidr = 1 / sqrt(150 * h[['Comparative illness and disability ratio indicator']] / 100),
    ypll = sqrt(1.5) / sqrt(20 * h[['Years of potential life lost indicator']] / median(h[['Years of potential life lost indicator']])),
    acute = sqrt(1.5) / sqrt(200 * h[['Acute morbidity indicator']] / 100)
  )

  # PERTURBATION HELPERS----

  # A normal draw per LSOA with a given share of its variance common to its local authority
  shared_z <- function(shared) {
    if (shared == 0) return(rnorm(N))
    sqrt(shared) * rnorm(n_lads)[lad_index] + sqrt(1 - shared) * rnorm(N)
  }
  a_err <- function(item) as.list(assumed_errors[assumed_errors$item == item, ])
  perturb <- function(x, scale, sd, z) {
    switch(scale,
           log = x * exp(sd * z),
           logit = plogis(qlogis(pmin(pmax(x, 1e-4), 1 - 1e-4)) + sd * z),
           add = x + sd * z)
  }
  perturb_assumed <- function(x, item) { e <- a_err(item); perturb(x, e$scale, e$sd, shared_z(e$shared)) }

  # Road casualties: zero rates get a floor of half the smallest published non-zero rate before perturbing,
  # and the zero-noise outdoors score is rebuilt with the same floor
  road_col <- 'Road traffic casualties involving injury to pedestrians and cyclists'
  floor_rate <- min(ind$living[[road_col]][ind$living[[road_col]] > 0]) / 2
  living_floored <- ind$living
  living_floored[[road_col]] <- pmax(living_floored[[road_col]], floor_rate)
  zero$outdoors_floored <- build_outdoors(living_floored)
  zero$affordability <- build_housing_affordability(ind$barriers)

  # ONE DRAW----

  draw_once <- function(layer, crime_reading) {
    l2 <- layer >= 2; l3 <- layer >= 3

    # Income and Employment, with shared denominator error in layer 3
    zi <- rnorm(N); ze <- rnorm(N)
    inc <- centre_inc + sd_inc * zi
    emp <- centre_emp + sd_emp * ze
    if (l3) {
      e <- a_err('Population denominators')
      dz <- shared_z(e$shared) * e$sd
      inc <- qlogis(pmin(plogis(inc) / exp(dz), 1 - 1e-9))
      emp <- qlogis(pmin(plogis(emp) / exp(dz), 1 - 1e-9))
    }
    rk <- list(income = rank(-inc, ties.method = 'random'), employment = rank(-emp, ties.method = 'random'))

    # Crime
    if (l2) {
      cr <- ind$crime
      for (v in names(crime_weights)) cr[[v]] <- cr[[v]] * exp(crime_se[[crime_reading]][[v]] * rnorm(N))
      rk$crime <- rank(-(base$crime + (build_crime(cr) - zero$crime)), ties.method = 'first')
    } else rk$crime <- iod$crime_rank

    # Health
    if (l3) {
      hh <- ind$health
      hh[['Comparative illness and disability ratio indicator']] <- hh[['Comparative illness and disability ratio indicator']] * exp(health_se$cidr * rnorm(N))
      hh[['Years of potential life lost indicator']] <- hh[['Years of potential life lost indicator']] * exp(health_se$ypll * rnorm(N))
      hh[['Acute morbidity indicator']] <- hh[['Acute morbidity indicator']] * exp(health_se$acute * rnorm(N))
      hh[['Mental health indicator']] <- perturb_assumed(hh[['Mental health indicator']], 'Mental health indicator')
      rk$health <- rank(-(base$health + (build_health(hh) - zero$health)), ties.method = 'first')
    } else rk$health <- iod$health_rank

    # Education: children and young people (assumed) and adult skills (Census)
    if (l2) {
      cyp <- if (l3) perturb_assumed(base$cyp, 'Children and young people sub-domain') else base$cyp
      skills <- plogis(qlogis(pmin(pmax(base$skills, 1e-6), 1 - 1e-6)) + over_se$skills * rnorm(N))
      rk$education <- rank(-combine_subdomains(cyp, skills, 0.5), ties.method = 'first')
    } else rk$education <- iod$education_rank

    # Barriers
    if (l2) {
      b <- ind$barriers
      b[['Household overcrowding indicator (rooms)']] <- perturb(b[['Household overcrowding indicator (rooms)']], 'logit', 1, over_se$rooms * rnorm(N))
      b[['Household overcrowding indicator (bedrooms)']] <- perturb(b[['Household overcrowding indicator (bedrooms)']], 'logit', 1, over_se$bedrooms * rnorm(N))
      geog <- base$geog
      if (l3) {
        geog <- base$geog - (perturb_assumed(b[['Connectivity Score']], 'Connectivity score') - b[['Connectivity Score']])
        b[['Owner-occupation affordability (component of housing affordability indicator)']] <- perturb_assumed(b[['Owner-occupation affordability (component of housing affordability indicator)']], 'Housing affordability components')
        b[['Private rental affordability (component of housing affordability indicator)']] <- perturb_assumed(b[['Private rental affordability (component of housing affordability indicator)']], 'Housing affordability components')
        # The published affordability item plus the change in its rebuild (the rebuild itself differs a little
        # from File 8 because of rounding)
        b[['Housing affordability indicator']] <- ind$barriers[['Housing affordability indicator']] + (build_housing_affordability(b) - zero$affordability)
        # Homelessness is supplied at local authority level: one draw per authority for each of the two indicators
        b[['Core homelessness rate (% of households)']] <- perturb_assumed(b[['Core homelessness rate (% of households)']], 'Homelessness (both indicators)')
        b[['Homelessness indicator (rate per 1,000 households)']] <- perturb_assumed(b[['Homelessness indicator (rate per 1,000 households)']], 'Homelessness (both indicators)')
        b[['Digital Connectivity (Broadband download and upload speeds)']] <- perturb_assumed(b[['Digital Connectivity (Broadband download and upload speeds)']], 'Broadband speed')
        b[['Patient-to-GP Ratio']] <- perturb_assumed(b[['Patient-to-GP Ratio']], 'Patient-to-GP ratio')
      }
      wider <- base$wider + (build_wider_barriers(b) - zero$wider)
      rk$barriers <- rank(-combine_subdomains(geog, wider, 0.5), ties.method = 'first')
    } else rk$barriers <- iod$barriers_rank

    # Living environment
    if (l2) {
      lv <- living_floored
      lv[[road_col]] <- lv[[road_col]] * exp(road_se * rnorm(N))
      indoors <- base$indoors
      if (l3) {
        lv[['Housing in poor condition indicator']] <- perturb_assumed(lv[['Housing in poor condition indicator']], 'Housing in poor condition')
        lv[['Housing energy performance deprivation Score']] <- perturb_assumed(lv[['Housing energy performance deprivation Score']], 'Housing energy performance')
        lv[['Housing lacking private outdoor space deprivation score']] <- perturb_assumed(lv[['Housing lacking private outdoor space deprivation score']], 'Housing lacking private outdoor space')
        lv[['Air quality indicator']] <- perturb_assumed(lv[['Air quality indicator']], 'Air quality')
        lv[['Noise pollution']] <- perturb_assumed(lv[['Noise pollution']], 'Noise')
        indoors <- base$indoors + (build_indoors(lv) - zero$indoors)
      }
      outdoors <- base$outdoors + (build_outdoors(lv) - zero$outdoors_floored)
      rk$living <- rank(-combine_subdomains(indoors, outdoors, 0.7), ties.method = 'first')
    } else rk$living <- iod$living_rank

    score <- as.vector(sapply(domains$domain, function(d) exp_transform(rk[[d]])) %*% w)
    imd <- rank(-score, ties.method = 'first')
    m <- lad_measures_fast(lad_index, iod$pop, score, imd, n_lads)
    list(imd = imd, domain_ranks = rk, lad_ranks = rank_lad_measures(m), lad_avg_score = m[, 'avg_score'])
  }

  # RUN EACH LAYER----

  layers <- tribble(
    ~layer, ~crime_reading, ~label,
    1, 'annual', '1. Income and Employment',
    2, 'annual', '2. Plus open-data chance error (crime: annual average reading)',
    2, 'pooled', '2b. As 2, crime: pooled reading',
    3, 'annual', '3. Plus assumed errors for everything else'
  )

  decile_breaks <- tapply(iod$imd_rank, iod$imd_decile, max)
  decile_of_rank <- function(rk) findInterval(rk - 1, decile_breaks) + 1
  probe_ranks <- round(seq(1, N - 5200, length.out = 300))
  gaps <- c(seq(25, 500, 25), seq(600, 2000, 100), seq(2250, 5000, 250))
  published_lad <- load_lad_summaries_all()
  lad_codes <- levels(factor(iod$lad))
  pub_lad_rank <- sapply(names(lad_measure_labels), function(m) published_lad[[paste0('rank_', m)]][match(lad_codes, published_lad$lad)])
  pub_lad_value <- sapply(names(lad_measure_labels), function(m) published_lad[[m]][match(lad_codes, published_lad$lad)])

  # Zero-noise check: with every random draw set to zero, layer 3's machinery must give back the published
  # ranking. Do it by giving draw_once (and shared_z) an rnorm that returns zeros, then removing it
  env <- environment(draw_once)
  assign('rnorm', function(n, ...) numeric(n), envir = env)
  d0 <- draw_once(3, 'annual')
  rm('rnorm', envir = env)
  # Where File 7 gives two LSOAs the same rank, the simulation has to put one of them a place lower, so
  # count those ties alongside
  zero_check <- tibble(domain = c(domains$domain, 'IMD'),
                       mismatches = c(map_int(domains$domain, ~ sum(d0$domain_ranks[[.x]] != iod[[paste0(.x, '_rank')]])),
                                      sum(d0$imd != iod$imd_rank)),
                       tied_published_ranks = c(map_int(domains$domain, ~ sum(duplicated(iod[[paste0(.x, '_rank')]]))),
                                                sum(duplicated(iod$imd_rank))))

  results <- pmap(layers, function(layer, crime_reading, label) {
    set.seed(30000 + layer * 10 + (crime_reading == 'pooled'))
    imd_draws <- matrix(0L, N, n_draws_full)
    dom_q <- map(set_names(domains$domain), ~ matrix(0L, N, n_draws_full))
    lad_r <- array(0L, c(n_lads, 5, n_draws_full), dimnames = list(NULL, names(lad_measure_labels), NULL))
    lad_avg_score <- matrix(0, n_lads, n_draws_full)
    for (k in seq_len(n_draws_full)) {
      d <- draw_once(layer, crime_reading)
      imd_draws[, k] <- d$imd
      for (dm in domains$domain) dom_q[[dm]][, k] <- d$domain_ranks[[dm]]
      lad_r[, , k] <- d$lad_ranks
      lad_avg_score[, k] <- d$lad_avg_score
    }
    q <- row_quantiles(imd_draws, c(0.05, 0.5, 0.95))
    p_top10 <- rowMeans(imd_draws <= n_most_deprived_10)
    lsoa_out <- tibble(layer = label, lsoa, imd_rank = iod$imd_rank, imd_decile = iod$imd_decile,
                       rank_q05 = q[, 1], rank_median = q[, 2], rank_q95 = q[, 3], width_90 = q[, 3] - q[, 1],
                       p_most_deprived_10 = p_top10,
                       deciles_spanned = decile_of_rank(q[, 3]) - decile_of_rank(q[, 1]) + 1)
    domain_out <- imap_dfr(dom_q, function(m, dm) {
      qq <- row_quantiles(m, c(0.05, 0.95))
      tibble(layer = label, domain = dm, median_width_90 = median(qq[, 2] - qq[, 1]), share_moved = mean(qq[, 2] > qq[, 1]))
    })
    sep <- separation_curves(imd_draws, iod$imd_rank, probe_ranks, gaps) %>% mutate(layer = label)
    lad_out <- imap_dfr(set_names(names(lad_measure_labels)), function(measure, i) {
      rk <- matrix(lad_r[, measure, ], nrow = n_lads)
      qq <- row_quantiles(rk, c(0.05, 0.5, 0.95))
      pub_rank <- pub_lad_rank[, measure]
      pub_value <- pub_lad_value[, measure]
      ord <- order(pub_rank)
      p_hold <- map_dbl(seq_len(length(ord) - 1), ~ mean(rk[ord[.x], ] < rk[ord[.x + 1], ]))
      tibble(layer = label, lad = lad_codes, measure = measure, published_rank = pub_rank, published_value = pub_value,
             rank_q05 = qq[, 1], rank_median = qq[, 2], rank_q95 = qq[, 3], width_90 = qq[, 3] - qq[, 1],
             next_pair_holds_95 = c(p_hold >= 0.95, NA)[order(ord)])
    })
    rm(imd_draws, dom_q, lad_r); gc()
    list(lsoa = lsoa_out, domain = domain_out, separation = sep, lad = lad_out, lad_avg_score = lad_avg_score)
  })

  list(
    zero_check = zero_check,
    lsoa = map_dfr(results, 'lsoa'),
    domain = map_dfr(results, 'domain'),
    separation = map_dfr(results, 'separation'),
    lad = map_dfr(results, 'lad'),
    # Simulated local authority average scores (authorities x draws) for each layer, for 16_lad_confidence_sets.R
    lad_avg_score_draws = set_names(map(results, 'lad_avg_score'), layers$label),
    lad_codes = lad_codes,
    layer_labels = layers$label
  )
})


# RESULTS FOR THE REPORT----

full_zero_check <- full$zero_check
full_zero_check

full_layer_labels <- full$layer_labels
full_lsoa_summary <- full$lsoa %>%
  group_by(layer) %>%
  summarise(
    median_width_90 = median(width_90),
    median_width_decile1 = median(width_90[imd_decile == 1]),
    median_width_decile10 = median(width_90[imd_decile == 10]),
    share_spanning_2plus_deciles = mean(deciles_spanned >= 2),
    share_spanning_3plus_deciles = mean(deciles_spanned >= 3),
    published_top10_below_95 = sum(imd_rank <= n_most_deprived_10 & p_most_deprived_10 < 0.95),
    uncertain_top10_status = sum(p_most_deprived_10 > 0.05 & p_most_deprived_10 < 0.95),
    .groups = 'drop'
  ) %>%
  mutate(layer = factor(layer, levels = full_layer_labels)) %>%
  arrange(layer)
full_lsoa_summary

full_domain_summary <- full$domain %>% mutate(layer = factor(layer, levels = full_layer_labels))

full_lsoa_width_by_rank <- full$lsoa %>%
  mutate(band_mid = (ceiling(imd_rank / 500) - 0.5) * 500) %>%
  group_by(layer, band_mid) %>%
  summarise(median_width = median(width_90), q25 = quantile(width_90, 0.25), q75 = quantile(width_90, 0.75), .groups = 'drop') %>%
  mutate(layer = factor(layer, levels = full_layer_labels))

full_separation_by_position <- full$separation %>%
  mutate(position = cut(probe_rank, c(0, 3375, 10000, 20000, Inf), labels = c('Most deprived 10%', '10% to 30%', '30% to 60%', 'Least deprived 40%'))) %>%
  group_by(layer, position, probe_rank) %>%
  summarise(gap_needed_95 = gap_needed(gap, p_order_holds), .groups = 'drop') %>%
  group_by(layer, position) %>%
  summarise(median_gap_needed = median(gap_needed_95, na.rm = TRUE), never_reached = sum(is.na(gap_needed_95)), .groups = 'drop') %>%
  mutate(layer = factor(layer, levels = full_layer_labels)) %>%
  arrange(layer, position)
full_separation_by_position

full_lad_summary <- full$lad %>%
  filter(!(measure %in% c('prop_10', 'extent') & published_value == 0)) %>%
  group_by(layer, measure) %>%
  summarise(lads = n(), median_width_90 = median(width_90), max_width_90 = max(width_90),
            adjacent_pairs_separable_95 = mean(next_pair_holds_95, na.rm = TRUE), .groups = 'drop') %>%
  mutate(layer = factor(layer, levels = full_layer_labels), measure = factor(measure, levels = names(lad_measure_labels))) %>%
  arrange(layer, measure)
full_lad_summary

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
full$lsoa %>%
  select(layer, lsoa, imd_rank, rank_q05, rank_median, rank_q95, p_most_deprived_10) %>%
  mutate(p_most_deprived_10 = round(p_most_deprived_10, 3)) %>%
  write_csv(file.path(output_dir, 'lsoa_imd_rank_ranges_by_layer.csv'))
full$lad %>%
  select(layer, lad, measure, published_rank, rank_q05, rank_median, rank_q95) %>%
  write_csv(file.path(output_dir, 'lad_rank_ranges_by_layer.csv'))
