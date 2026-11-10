# Rebuild the Census-based indicators from open Census 2021 tables
# - Household overcrowding (rooms and bedrooms, in the wider barriers sub-domain): the share of households
#   with an occupancy rating of -1 or less (technical report 4.8.12-13). Census tables TS053 (rooms) and TS052
#   (bedrooms) give the counts and the number of households, so no reverse engineering is needed
# - Adult skills (the adult skills sub-domain, 6.75% of the IMD): built from a special Census table that isn't
#   published, so only the denominator can be approximated, from Census TS007A (people aged 25 to 66:
#   the 25-29 to 60-64 bands plus 2/5 of the 65-69 band). The count then comes from the published rate
# Both get a posterior standard error from the shrinkage step (local authority parents), for 15_full_mc.R.
# Census counts carry small disclosure-control perturbations, ignored here
# Used in docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd
source('code/imd_uncertainty/functions.R')

iod <- load_iod_ranks()
barriers <- load_underlying('IoD25 Barriers Domain')
education <- load_underlying('IoD25 Education Domain')

ts053 <- get_census_lsoa('ts053')
ts052 <- get_census_lsoa('ts052')
ts007a <- get_census_lsoa('ts007a')

census <- tibble(lsoa = iod$lsoa, lad = iod$lad) %>%
  left_join(transmute(ts053, lsoa = `geography code`, households = `Occupancy rating for rooms: Total: All households`,
                      rooms_r = `Occupancy rating for rooms: Occupancy rating of rooms: -1` + `Occupancy rating for rooms: Occupancy rating of rooms: -2 or less`), by = 'lsoa') %>%
  left_join(transmute(ts052, lsoa = `geography code`,
                      bedrooms_r = `Occupancy rating for bedrooms: Occupancy rating of bedrooms: -1` + `Occupancy rating for bedrooms: Occupancy rating of bedrooms: -2 or less`), by = 'lsoa') %>%
  left_join(transmute(ts007a, lsoa = `geography code`,
                      pop_25_66 = `Age: Aged 25 to 29 years` + `Age: Aged 30 to 34 years` + `Age: Aged 35 to 39 years` + `Age: Aged 40 to 44 years` +
                        `Age: Aged 45 to 49 years` + `Age: Aged 50 to 54 years` + `Age: Aged 55 to 59 years` + `Age: Aged 60 to 64 years` +
                        0.4 * `Age: Aged 65 to 69 years`), by = 'lsoa') %>%
  mutate(
    rooms_published = barriers[['Household overcrowding indicator (rooms)']][match(lsoa, barriers[['LSOA code (2021)']])],
    bedrooms_published = barriers[['Household overcrowding indicator (bedrooms)']][match(lsoa, barriers[['LSOA code (2021)']])],
    skills_published = education[['Adult skills and English language proficiency indicator']][match(lsoa, education[['LSOA code (2021)']])]
  )
stopifnot(!anyNA(census$households), !anyNA(census$pop_25_66))


# OVERCROWDING: REBUILD AND SHRINKAGE----

overcrowding <- bind_rows(
  census %>% transmute(component = 'Rooms', lsoa, lad, r = rooms_r, size = households, published = rooms_published),
  census %>% transmute(component = 'Bedrooms', lsoa, lad, r = bedrooms_r, size = households, published = bedrooms_published)
) %>%
  group_by(component) %>%
  group_modify(~ bind_cols(.x, shrink_iod(.x$r, .x$size, .x$lad))) %>%
  ungroup() %>%
  mutate(raw_rate = r / size, pull_published = qlogis(pmax(published, 0.0005)) - m, pull_rebuilt = m_shrunk - m)

overcrowding_check <- overcrowding %>%
  group_by(component) %>%
  summarise(
    median_households = median(size),
    median_count = median(r),
    cor_raw_vs_published = cor(raw_rate, published),
    share_raw_within_rounding = mean(abs(raw_rate - published) <= 0.0005 + 1e-9),
    share_rebuilt_within_rounding = mean(abs(rate_shrunk - published) <= 0.0005 + 1e-9),
    cor_pulls = cor(pull_published, pull_rebuilt),
    median_w = median(w),
    median_se_logit = median(sqrt(post_var)),
    .groups = 'drop'
  )
overcrowding_check


# ADULT SKILLS: APPROXIMATE DENOMINATOR, COUNT FROM THE PUBLISHED RATE----

# Run the shrinkage backwards with the approximate denominator to recover the count and its posterior error
adult_skills <- census %>%
  transmute(lsoa, lad, size = pop_25_66, published = skills_published) %>%
  bind_cols(invert_shrinkage(.$published, .$size, .$lad) %>% select(r_recovered, w, post_var, converged))

adult_skills_check <- adult_skills %>%
  summarise(median_denominator = median(size), median_count = median(r_recovered), median_w = median(w),
            median_se_logit = median(sqrt(post_var)), groups_converged = mean(converged))
adult_skills_check

# For 15_full_mc.R: logit-scale centres (published values, untied) and posterior standard errors
census_errors <- bind_rows(
  overcrowding %>% transmute(indicator = paste('Overcrowding,', tolower(component)), lsoa, se_logit = sqrt(post_var)),
  adult_skills %>% transmute(indicator = 'Adult skills', lsoa, se_logit = sqrt(post_var))
)
