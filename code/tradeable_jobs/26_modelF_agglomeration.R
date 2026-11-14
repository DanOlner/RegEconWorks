# Model F with agglomeration: productivity in a place-sector rises with its employment, a_eff = a (L_is /
# mean L_s)^kappa, firms taking it as given (as round 1's engine). Round 1's solver couldn't handle kappa 0.04
# or more; Model F solves at 0.02 and 0.03. The setting is the best calibrated one: demand fitted to T6
# (21_modelF_demand.R) and an elasticity of 3 between places for local services (24_modelF_local_sigma.R).
# Questions: does agglomeration favour the frontier push (it concentrates where tradables already cluster),
# and does it change how much of a local gain stays local?

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_uk.R')
source('code/tradeable_jobs/functions_io.R')
source('code/tradeable_jobs/functions_rv2023.R')
source('code/tradeable_jobs/functions_modelF.R')
source('code/tradeable_jobs/24_modelF_local_sigma.R')

ag_kappas <- c(0.02, 0.03)

ag <- tj_cached('modelF_agglomeration', {
  gr <- read_csv(file.path(tj_output_dir, 't2_groups.csv'), show_col_types = FALSE)
  cf <- read_csv(file.path(tj_output_dir, 't2_group_coefficients.csv'), show_col_types = FALSE)
  cal <- mf_calibrate(gr, cf)
  tasks <- expand_grid(kappa = ag_kappas, seed = 100 + seq_len(mf_R), mob = c('frechet', 'immobile'))
  bind_rows(parallel::mclapply(seq_len(nrow(tasks)), function(k) {
    dem <- ls$dem; dem$kappa <- tasks$kappa[k]
    mf_run_draw(cal, dem, tasks$seed[k], tasks$mob[k], TRUE, N = mf_N, shock = mf_shock) %>% mutate(kappa = tasks$kappa[k])
  }, mc.cores = md_cores))
}, depends = c('code/tradeable_jobs/functions_modelF.R', 'code/tradeable_jobs/26_modelF_agglomeration.R'),
   key = c(unlist(md_best[c('eps_c', 'eps_i', 'sigma_x')]), ls_sigma_local, ag_kappas))

ag_runs <- bind_rows(ls$runs %>% mutate(kappa = 0), ag)
ag_breakeven <- ag_runs %>% filter(grepl('^P[1-4] ', experiment)) %>% mutate(gain_per_point = d_welfare / points) %>%
  group_by(kappa, mobility, seed) %>% mutate(breakeven = gain_per_point / gain_per_point[grepl('^P1 ', experiment)]) %>%
  group_by(kappa, experiment, mobility) %>%
  summarise(d_welfare = mean(d_welfare), gain_per_point = mean(gain_per_point), breakeven = mean(breakeven), .groups = 'drop')
ag_e2 <- ag_runs %>% filter(experiment == 'E2 local') %>% group_by(kappa, group, mobility) %>%
  summarise(across(c(d_welfare, lag_d_u, lag_gain_share, lag_d_group_jobs), mean), converged = all(converged), .groups = 'drop')
ag_e2_type <- ag_e2 %>% mutate(type = ifelse(group %in% ls$local, 'local services', 'other groups')) %>%
  group_by(kappa, mobility, type) %>% summarise(mean_gain_share = mean(lag_gain_share), .groups = 'drop')

tj_write(ag_breakeven, 'ag_breakeven.csv'); tj_write(ag_e2, 'ag_e2_local.csv')
