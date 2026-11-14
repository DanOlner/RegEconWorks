# Model F with demand calibrated to T6. T6 found that, across UK industries 1997-2019, hours fall when
# output per hour rises: by 0.54 log points per log point in business-to-business industries, 0.34 in local
# services and 0.14 in tradables (stacked five-year differences). Model F's default demand (Cobb-Douglas for
# households and for firms' inputs, foreign demand as elastic as demand between places, sigma = 10) has no
# group losing jobs. Here:
#   1. a grid over households' substitution between sectors (eps_c), firms' substitution between inputs
#      (eps_i) and foreign demand's price elasticity (sigma_x). For each, the model's own-jobs response to a
#      5% national gain in each group (one draw, people mobile), averaged by market reach, against T6's
#      estimates, weighted by their standard errors. Division bias pushes T6's slopes towards -1, so the
#      calibrated setting is, if anything, at the low-elasticity end.
#   2. Model F's experiments (16_modelF.R's set, supply chains on) and T10's break-even ratios with the
#      calibrated demand, against the default.

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_uk.R')
source('code/tradeable_jobs/functions_io.R')
source('code/tradeable_jobs/functions_rv2023.R')
source('code/tradeable_jobs/functions_modelF.R')
source('code/tradeable_jobs/16_modelF.R')
source('code/tradeable_jobs/17_t6_own_jobs.R')

md_deps <- c('code/tradeable_jobs/functions_modelF.R', 'code/tradeable_jobs/21_modelF_demand.R',
             file.path(tj_output_dir, 't2_groups.csv'), file.path(tj_output_dir, 't2_group_coefficients.csv'))
md_cores <- max(1, parallel::detectCores() - 2)

md_targets <- t6$regs %>% filter(sample == 'Stacked 5-year differences, slope by reach', grepl(':d_oph', term)) %>%
  transmute(reach = sub('^reach(.*):d_oph$', '\\1', term), target = estimate, se)

md_grid <- tj_cached('modelF_demand_grid', {
  gr <- read_csv(file.path(tj_output_dir, 't2_groups.csv'), show_col_types = FALSE)
  cf <- read_csv(file.path(tj_output_dir, 't2_group_coefficients.csv'), show_col_types = FALSE)
  cal <- mf_calibrate(gr, cf)
  reach <- c(`1.3` = 'tradable', `1.5` = 'business to business', `2` = 'local services')[as.character(cal$t_s)]
  grid <- expand_grid(eps_c = c(0.3, 0.5, 0.7, 1), eps_i = c(0.2, 0.5, 1), sigma_x = c(2, 4, 10))
  bind_rows(parallel::mclapply(seq_len(nrow(grid)), function(k) {
    g <- grid[k, ]
    dem <- mf_calibrate_demand(cal, mf_N, eps_c = g$eps_c, eps_i = g$eps_i, sigma_x = g$sigma_x)
    r <- mf_run_draw(cal, dem, 101, 'frechet', TRUE, N = mf_N, shock = mf_shock, proxies = FALSE, local = FALSE)
    r %>% mutate(reach = reach[match(group, cal$sectors)], own_elasticity = d_group_jobs / log(1 + mf_shock)) %>%
      group_by(reach) %>% summarise(model = mean(own_elasticity), converged = all(converged), .groups = 'drop') %>%
      mutate(eps_c = g$eps_c, eps_i = g$eps_i, sigma_x = g$sigma_x, export_calibration_gap = dem$max_log_gap)
  }, mc.cores = md_cores))
}, depends = c(md_deps, 'code/tradeable_jobs/17_t6_own_jobs.R'))

md_fit <- md_grid %>% left_join(md_targets, by = 'reach') %>%
  group_by(eps_c, eps_i, sigma_x) %>%
  summarise(distance = sum(((model - target) / se)^2), converged = all(converged), .groups = 'drop') %>% arrange(distance)
md_best <- md_fit %>% filter(converged) %>% slice(1)

md <- tj_cached('modelF_demand_runs', {
  gr <- read_csv(file.path(tj_output_dir, 't2_groups.csv'), show_col_types = FALSE)
  cf <- read_csv(file.path(tj_output_dir, 't2_group_coefficients.csv'), show_col_types = FALSE)
  cal <- mf_calibrate(gr, cf)
  dem <- mf_calibrate_demand(cal, mf_N, eps_c = md_best$eps_c, eps_i = md_best$eps_i, sigma_x = md_best$sigma_x)
  tasks <- expand_grid(seed = 100 + seq_len(mf_R), mob = c('frechet', 'immobile'))
  runs <- bind_rows(parallel::mclapply(seq_len(nrow(tasks)), function(k)
    mf_run_draw(cal, dem, tasks$seed[k], tasks$mob[k], TRUE, N = mf_N, shock = mf_shock), mc.cores = md_cores))
  # the same setting under Rice and Venables's closure (q balancing trade), proxies only, one draw
  dem_rv <- dem; dem_rv$q0 <- NULL
  rv <- bind_rows(parallel::mclapply(c('frechet', 'immobile'), function(mob)
    mf_run_draw(cal, dem_rv, 101, mob, TRUE, N = mf_N, shock = mf_shock, groups = FALSE), mc.cores = 2))
  list(dem = dem, runs = runs, rv = rv)
}, depends = c(md_deps, 'code/tradeable_jobs/17_t6_own_jobs.R'), key = unlist(md_best[c('eps_c', 'eps_i', 'sigma_x')]))

# Summaries: the calibrated setting against the default (16_modelF.R)
md_runs <- bind_rows(mf_runs %>% filter(supply_chains) %>% mutate(demand = 'Default (Cobb-Douglas, sigma_x 10)'),
                     md$runs %>% mutate(demand = 'Calibrated to T6'))
md_e1 <- md_runs %>% filter(experiment == 'E1 national') %>% group_by(demand, group, mobility) %>%
  summarise(across(c(d_welfare, d_gva_pw, hulten, d_group_jobs, land_share), mean), .groups = 'drop')
md_e2 <- md_runs %>% filter(experiment == 'E2 local') %>% group_by(demand, group, mobility) %>%
  summarise(across(c(d_welfare, lag_d_u, lag_d_gva_pw, lag_d_wage, lag_gain_share, lag_d_group_jobs, lag_d_tradable_cost), mean),
            .groups = 'drop')
md_lens <- md_runs %>% filter(experiment == 'E2 local') %>% group_by(demand, group, mobility) %>%
  summarise(gva = mean(lag_d_gva_pw), real = mean(lag_d_u), .groups = 'drop') %>% mutate(disagree = sign(gva) != sign(real))
pp <- function(r) r %>% filter(grepl('^P[1-4] ', experiment)) %>% mutate(gain_per_point = d_welfare / points)
md_breakeven <- bind_rows(
  pp(md_runs) %>% mutate(closure = 'Foreign demand fixed (Model F)'),
  pp(md$rv %>% mutate(demand = 'Calibrated to T6')) %>% mutate(closure = 'Rice and Venables: q balances trade')) %>%
  group_by(demand, closure, mobility, seed) %>%
  mutate(breakeven = gain_per_point / gain_per_point[grepl('^P1 ', experiment)]) %>%
  group_by(demand, closure, experiment, mobility) %>%
  summarise(d_welfare = mean(d_welfare), points = mean(points), gain_per_point = mean(gain_per_point),
            breakeven = mean(breakeven), breakeven_min = min(breakeven), breakeven_max = max(breakeven), .groups = 'drop')
md_jobs_local <- md_runs %>% filter(experiment == 'E2 local', mobility == 'immobile') %>%
  group_by(demand, group) %>% summarise(lag_d_group_jobs = mean(lag_d_group_jobs), lag_d_u = mean(lag_d_u), .groups = 'drop')

tj_write(md_grid, 'md_grid.csv'); tj_write(md_fit, 'md_fit.csv')
tj_write(md_e1, 'md_e1_national.csv'); tj_write(md_e2, 'md_e2_local.csv'); tj_write(md_breakeven, 'md_breakeven.csv')
