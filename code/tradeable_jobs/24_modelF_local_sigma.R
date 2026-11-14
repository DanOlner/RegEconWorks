# Model F with a lower elasticity between places for local services. Section 16 of the round 2 report found
# that with Rice and Venables's single elasticity (10), a place that alone improves its everyday services
# draws customers from every other place: its retail jobs rise ~12% and it keeps more than the whole national
# gain. Hairdressers and cafes are unlikely to be that price-sensitive across ITL1 borders. Here the local
# services (households 50%+ of sales, exports under 20%) get an elasticity of 3, with their trade costs moved
# so that the share bought from other places is unchanged; everything else is the demand calibrated to T6
# (21_modelF_demand.R). The experiments and break-even ratios are rerun and compared.

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_uk.R')
source('code/tradeable_jobs/functions_io.R')
source('code/tradeable_jobs/functions_rv2023.R')
source('code/tradeable_jobs/functions_modelF.R')
source('code/tradeable_jobs/21_modelF_demand.R')

ls_sigma_local <- 3

ls <- tj_cached('modelF_local_sigma', {
  gr <- read_csv(file.path(tj_output_dir, 't2_groups.csv'), show_col_types = FALSE)
  cf <- read_csv(file.path(tj_output_dir, 't2_group_coefficients.csv'), show_col_types = FALSE)
  cal <- mf_calibrate(gr, cf)
  dem <- mf_calibrate_demand(cal, mf_N, eps_c = md_best$eps_c, eps_i = md_best$eps_i, sigma_x = md_best$sigma_x,
                             sigma_local = ls_sigma_local)
  tasks <- expand_grid(seed = 100 + seq_len(mf_R), mob = c('frechet', 'immobile'))
  runs <- bind_rows(parallel::mclapply(seq_len(nrow(tasks)), function(k)
    mf_run_draw(cal, dem, tasks$seed[k], tasks$mob[k], TRUE, N = mf_N, shock = mf_shock), mc.cores = md_cores))
  list(dem = dem, runs = runs, local = cal$sectors[cal$household_share >= 0.5 & cal$export_share < 0.2])
}, depends = c('code/tradeable_jobs/functions_modelF.R', 'code/tradeable_jobs/24_modelF_local_sigma.R'),
   key = c(unlist(md_best[c('eps_c', 'eps_i', 'sigma_x')]), ls_sigma_local))

ls_runs <- bind_rows(md$runs %>% mutate(variant = 'Calibrated demand, elasticity between places 10'),
                     ls$runs %>% mutate(variant = paste0('Calibrated demand, local services ', ls_sigma_local)))
ls_e2 <- ls_runs %>% filter(experiment == 'E2 local') %>% group_by(variant, group, mobility) %>%
  summarise(across(c(d_welfare, lag_d_u, lag_gain_share, lag_d_group_jobs, lag_d_gva_pw), mean), .groups = 'drop')
ls_e1 <- ls_runs %>% filter(experiment == 'E1 national') %>% group_by(variant, group, mobility) %>%
  summarise(across(c(d_welfare, hulten, d_group_jobs), mean), .groups = 'drop')
ls_breakeven <- ls_runs %>% filter(grepl('^P[1-4] ', experiment)) %>% mutate(gain_per_point = d_welfare / points) %>%
  group_by(variant, mobility, seed) %>% mutate(breakeven = gain_per_point / gain_per_point[grepl('^P1 ', experiment)]) %>%
  group_by(variant, experiment, mobility) %>% summarise(breakeven = mean(breakeven), d_welfare = mean(d_welfare), .groups = 'drop')
ls_local_type <- ls_runs %>% filter(experiment == 'E2 local') %>%
  mutate(points = lag_emp_share * log(1 + mf_shock), type = ifelse(group %in% ls$local, 'local services', 'other')) %>%
  group_by(variant, mobility, type, seed) %>% summarise(local_gain_per_point = sum(lag_d_u) / sum(points), .groups = 'drop') %>%
  group_by(variant, mobility, type) %>% summarise(local_gain_per_point = mean(local_gain_per_point), .groups = 'drop')

tj_write(ls_e2, 'ls_e2_local.csv'); tj_write(ls_e1, 'ls_e1_national.csv'); tj_write(ls_breakeven, 'ls_breakeven.csv')
