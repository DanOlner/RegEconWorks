# Rebuild the road casualty indicator from DfT's open STATS19 data
# The IoD 2025 indicator (technical report 4.9.26 to 4.9.30): pedestrian and cyclist casualties in reported
# road traffic collisions, 2019 to 2023, weighted 1 for slight, 2 for serious and 3 for fatal, using DfT's
# severity-adjusted data; collisions within 100 m of an LSOA boundary split equally between the areas either
# side; denominator = residents (excluding prisoners) plus the non-resident workplace population; shrunk.
# The source is open, so the counts don't need to be reverse engineered (06 does that, and breaks down here
# because the counts are so small).
#
# Approximations, flagged in the write-up:
# - Severity: fatal = 3; otherwise 2 x DfT's probability of 'serious' plus 1 x its probability of 'slight'
# - The 100 m split: each casualty is shared equally between every LSOA within 100 m of the collision
#   (found by intersecting a 100 m buffer, drawn with 16 segments, with the boundaries; a test on 500
#   collisions agreed with an exact distance query for 99.6%, and runs in about a minute instead of hours)
# - Workplace population: BRES 2023 employment by LSOA (open, rounded) stands in for the non-resident
#   workplace population. It also counts residents who work locally, so it overstates the denominator a little
# - Residents: the File 6 mid-2022 population, which includes prisoners
# Results are cached. Used in docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd and 15_full_mc.R
source('code/imd_uncertainty/functions.R')

this_script <- 'code/imd_uncertainty/11_road_casualties.R'
years <- 2019:2023

# The allocation of casualties to LSOAs is slow and uses none of the method code, so its cache ignores
# changes to functions.R (it still reruns if this script changes, or with options(imd.refresh = TRUE))
road <- cached('11_road_casualties', depends = this_script, track_functions = FALSE, expr = {

  # CASUALTIES AND LOCATIONS----

  # DfT publishes single-year files only from 2021, so read 2019 to 2023 from the all-years files
  read_stats19 <- function(table, cols) {
    data.table::fread(get_stats19(table, '1979-latest-published-year'), select = cols, showProgress = FALSE) %>%
      as_tibble() %>%
      filter(collision_year %in% years)
  }

  casualties <- read_stats19('casualty', c('collision_index', 'collision_year', 'casualty_class', 'casualty_type', 'casualty_severity',
                                           'casualty_adjusted_severity_serious', 'casualty_adjusted_severity_slight')) %>%
    # Pedestrians (casualty class 3) and pedal cyclists (casualty type 1)
    filter(casualty_class == 3 | casualty_type == 1) %>%
    mutate(
      adj_serious = suppressWarnings(as.numeric(casualty_adjusted_severity_serious)),
      adj_slight = suppressWarnings(as.numeric(casualty_adjusted_severity_slight)),
      weight = case_when(
        casualty_severity == 1 ~ 3,
        !is.na(adj_serious) & !is.na(adj_slight) & adj_serious >= 0 & adj_slight >= 0 ~ 2 * adj_serious + adj_slight,
        casualty_severity == 2 ~ 2,
        TRUE ~ 1
      )
    )

  collisions <- read_stats19('collision', c('collision_index', 'collision_year', 'location_easting_osgr', 'location_northing_osgr')) %>%
    mutate(across(starts_with('location'), ~ suppressWarnings(as.numeric(.x))))

  casualty_points <- casualties %>%
    inner_join(collisions, by = c('collision_index', 'collision_year')) %>%
    filter(!is.na(location_easting_osgr), !is.na(location_northing_osgr))

  # SHARE EACH CASUALTY BETWEEN THE LSOAS WITHIN 100 M----

  # Work out the LSOAs near each collision once, then share each of its casualties between them
  lsoas <- get_lsoa_boundaries()
  collision_points <- distinct(casualty_points, collision_index, collision_year, location_easting_osgr, location_northing_osgr)
  pts <- sf::st_as_sf(collision_points, coords = c('location_easting_osgr', 'location_northing_osgr'), crs = 27700)
  near <- sf::st_intersects(sf::st_buffer(pts, 100, nQuadSegs = 4), lsoas)
  k <- lengths(near)

  collision_lsoas <- tibble(collision = rep(seq_along(near), k), lsoa_index = unlist(near)) %>%
    mutate(collision_index = collision_points$collision_index[collision], collision_year = collision_points$collision_year[collision],
           share = 1 / k[collision], lsoa = lsoas$LSOA21CD[lsoa_index]) %>%
    select(collision_index, collision_year, lsoa, share)

  shares <- casualty_points %>%
    select(collision_index, collision_year, weight) %>%
    inner_join(collision_lsoas, by = c('collision_index', 'collision_year'), relationship = 'many-to-many') %>%
    mutate(contribution = weight * share)

  by_lsoa <- shares %>%
    group_by(lsoa) %>%
    summarise(weighted_count = sum(contribution), sum_sq = sum(contribution^2), casualties = sum(share), .groups = 'drop')

  k_by_casualty <- k[match(paste(casualty_points$collision_index, casualty_points$collision_year),
                           paste(collision_points$collision_index, collision_points$collision_year))]
  location_summary <- tibble(
    casualties_in_years = nrow(casualties),
    with_location = nrow(casualty_points),
    in_england = sum(k_by_casualty > 0),
    split_between_lsoas = sum(k_by_casualty > 1),
    mean_weight = mean(casualty_points$weight[k_by_casualty > 0])
  )

  list(by_lsoa = by_lsoa, location_summary = location_summary)
})

location_summary <- road$location_summary
location_summary


# DENOMINATOR AND RATES----

iod <- load_iod_ranks()
living <- load_underlying('IoD25 Living Env Domain')
bres <- get_bres_lsoa(2023)

road_lsoa <- iod %>%
  select(lsoa, lad, pop) %>%
  left_join(bres, by = 'lsoa') %>%
  left_join(road$by_lsoa, by = 'lsoa') %>%
  mutate(
    across(c(weighted_count, sum_sq, casualties), ~ coalesce(.x, 0)),
    employment = coalesce(employment, 0),
    at_risk = pop + employment,
    published = living[['Road traffic casualties involving injury to pedestrians and cyclists']][match(lsoa, living[['LSOA code (2021)']])],
    # Annual rate per 1,000 at-risk people, before shrinkage
    raw_rate = 1000 * weighted_count / length(years) / at_risk,
    raw_rate_residents = 1000 * weighted_count / length(years) / pop
  )


# DOES THE PUBLISHED INDICATOR LOOK SHRUNK?----

# Shrinkage as Appendix C describes pulls every LSOA towards its parent group, so an LSOA with no casualties
# should come out above zero. Shrink the rebuilt counts both ways (pooled over five years, or the annual
# average) and compare each with the published values, alongside the unshrunk rate.
# Severity weighting makes the count more variable than a plain count; the shrinkage here treats the
# weighted count as a count, as the report's formula would
shrunk_pooled <- shrink_iod(road_lsoa$weighted_count, road_lsoa$at_risk * length(years), road_lsoa$lad)
shrunk_annual <- shrink_iod(road_lsoa$weighted_count / length(years), road_lsoa$at_risk, road_lsoa$lad)

road_lsoa <- road_lsoa %>%
  mutate(rate_shrunk_pooled = 1000 * shrunk_pooled$rate_shrunk, rate_shrunk_annual = 1000 * shrunk_annual$rate_shrunk,
         w_pooled = shrunk_pooled$w, w_annual = shrunk_annual$w, post_var_pooled = shrunk_pooled$post_var, post_var_annual = shrunk_annual$post_var)

road_fit <- tibble(
  candidate = c('Unshrunk rate (residents + workplace)', 'Unshrunk rate (residents only)', 'Shrunk, counts pooled over 5 years', 'Shrunk, annual average count'),
  values = list(road_lsoa$raw_rate, road_lsoa$raw_rate_residents, road_lsoa$rate_shrunk_pooled, road_lsoa$rate_shrunk_annual)
) %>%
  mutate(
    rank_correlation = map_dbl(values, ~ cor(.x, road_lsoa$published, method = 'spearman')),
    correlation = map_dbl(values, ~ cor(.x, road_lsoa$published)),
    # Among LSOAs with no casualties at all, the share whose candidate value rounds to 0.000
    zero_lsoas_at_zero = map_dbl(values, ~ mean(round(.x[road_lsoa$weighted_count == 0], 3) == 0))
  ) %>%
  select(-values)
road_fit

road_zero_check <- road_lsoa %>%
  summarise(
    lsoas = n(),
    published_zero = sum(published == 0),
    rebuilt_no_casualties = sum(weighted_count == 0),
    published_zero_and_no_casualties = sum(published == 0 & weighted_count == 0),
    median_ratio_published_to_raw = median(published[raw_rate > 0] / raw_rate[raw_rate > 0]),
    median_weighted_count = median(weighted_count),
    share_under_1 = mean(weighted_count < 1),
    median_casualties = median(casualties)
  )
road_zero_check

# For 15_full_mc.R: each LSOA's error on the log scale for the road casualty rate. With the indicator looking
# unshrunk (see road_fit), use the plain count error: the variance of a weighted Poisson count is the sum of
# the squared contributions, so the relative SE is sqrt(sum_sq) / weighted_count. For LSOAs with no casualties,
# use the error of half a casualty at the median weight
road_errors <- road_lsoa %>%
  transmute(lsoa, published, weighted_count,
            se_log = if_else(weighted_count > 0, sqrt(sum_sq) / weighted_count, sqrt(1.3^2 * 0.5) / (1.3 * 0.5)))
