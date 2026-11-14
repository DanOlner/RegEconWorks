# Step 3 of the plan: Venables (2018 intro, 2020 footnote 12) says comparative advantage can't rescue a
# place inside a country because costs can't fall far enough: labour is mobile and immobile factors are a
# small share of costs. Put numbers on both sides.
#   A. In Model A, the cost gap a lone tradable firm has to overcome in a type-N city, against the wage
#      gap the model can sustain between city types
#   B. In the UK data, how much cheaper are low-wage areas once sector mix is removed (the area
#      differential)? Add land and property costs using the rent-earnings elasticity Rice and Venables
#      estimate (2.27). Compare with the productivity premium an established cluster would need to keep
#      a firm from moving, for a range of agglomeration elasticities from the literature.

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_v2020.R')
lev_deps <- c('code/tradeable_jobs/functions_v2020.R', 'code/tradeable_jobs/10_leverage.R')

# A. Model A: at points across the equilibrium set, the first-mover gap q(LT)/q(0) - 1 and the wage gap
# between type-T and type-N cities. At E they are equal by definition; inside the set the wage gap is
# smaller than the productivity gap, which is why no lone firm moves.
lev_model_a <- tj_cached('lev_model_a', {
  spec <- cm_spec(); b <- cm_bounds(spec)
  bind_rows(lapply(seq(b[['E']], b[['X']], length.out = 6), function(MT) {
    s <- cm_solve(c(T = MT, N = 100 - MT), spec)
    cT <- s$cities[s$cities$type == 'T', ]; cN <- s$cities[s$cities$type == 'N', ]
    tibble(share_T = MT / 100, first_mover_gap_pct = 100 * (cT$w / spec$types$T$p - 1),
           wage_gap_T_over_N_pct = 100 * (cT$w / cN$w - 1),
           rent_per_resident_ratio = cT$r_pc / cN$r_pc)
  }))
}, depends = lev_deps)

# B. UK: area differentials from the replication (run 09_uk_sparsity.R first)
uk_areas_out <- read_csv(file.path(tj_output_dir, 'uk_areas.csv'), show_col_types = FALSE)
w_bar <- with(uk_areas_out, sum(w_i * L_i) / sum(L_i))
lev_uk_areas <- uk_areas_out %>%
  transmute(area, area_name, london, w_i,
            wage_gap_pct = 100 * (w_i / w_bar - 1),                 # all of it, including sector mix
            same_sector_wage_gap_pct = 100 * area_diff / w_bar)      # the area differential: same jobs, cheaper place
lev_uk_summary <- lev_uk_areas %>% summarise(
  areas = n(),
  median_same_sector_gap_pct = median(same_sector_wage_gap_pct),
  bottom_quartile_mean_same_sector_gap_pct = mean(same_sector_wage_gap_pct[same_sector_wage_gap_pct <= quantile(same_sector_wage_gap_pct, 0.25)]),
  lowest_same_sector_gap_pct = min(same_sector_wage_gap_pct),
  london_mean_same_sector_gap_pct = mean(same_sector_wage_gap_pct[london]))

# Cost saving for a firm moving from an average-cost place to a bottom-quartile place, as a % of unit
# costs: labour share x wage saving + property share x property saving. Property costs move 2.27 times
# as much as earnings (Rice and Venables, Table A6), capped at 90%.
gap_bq <- -lev_uk_summary$bottom_quartile_mean_same_sector_gap_pct
lev_cost_saving <- expand_grid(labour_share = c(0.5, 0.7, 0.9), property_share = c(0.05, 0.1)) %>%
  mutate(wage_saving_pct = gap_bq, property_saving_pct = pmin(2.27 * gap_bq, 90),
         unit_cost_saving_pct = labour_share * wage_saving_pct + property_share * property_saving_pct)

# Productivity premium of an established cluster over a lone entrant, (size ratio)^elasticity - 1, for
# agglomeration elasticities around the range in Combes and Gobillon (2015), and for the premium in
# Venables' own calibration (Model A at E)
lev_premium <- expand_grid(elasticity = c(0.02, 0.04, 0.06, 0.08), cluster_size_ratio = c(10, 100, 1000)) %>%
  mutate(cluster_premium_pct = 100 * (cluster_size_ratio^elasticity - 1))

tj_write(lev_model_a, 'leverage_model_a.csv')
tj_write(lev_uk_areas, 'leverage_uk_areas.csv')
tj_write(lev_cost_saving, 'leverage_cost_saving.csv')
tj_write(lev_premium, 'leverage_cluster_premium.csv')
print(lev_model_a); print(lev_uk_summary); print(lev_cost_saving); print(lev_premium %>% pivot_wider(names_from = cluster_size_ratio, values_from = cluster_premium_pct, names_prefix = 'size_ratio_'))
