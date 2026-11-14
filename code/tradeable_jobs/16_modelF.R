# Round 2, test T1 (Model F), with T7, T8 and the Model F half of T9: the Rice and Venables engine with
# supply chains, calibrated on T2's sector groups, run under the broad benchmark (people mobile between
# places, Frechet) and the narrow one (people immobile between places, choosing sectors within them).
#
# Checks: with no intermediates it reproduces Model C/D; with one closed place, gains follow Domar weights.
# Experiments (each on R draws of place-by-sector productivity, sd 0.2 as Rice and Venables):
#   E1 national  +5% productivity in one group, in every place; with supply chains on and off
#   E2 local     +5% in one group, in the lagging place only (lowest real income at the start)
#   E3 proxies   P1 frontier push, P2 long-tail catch-up, P3 upstream, P4 local services, P7 lower trade
#                costs for local services, P9 more elastic land, and P4 with P9
# Closure: foreign demand is held at its calibrated level (q_fixed), so the wage and price level against
# world prices is set by equilibrium and trade balances by Walras's law. Rice and Venables's own closure
# (q balancing trade with the import price fixed) leaves that level undetermined; see functions_modelF.R.
# Outcomes: real income (welfare and mean utility), the official lens (nominal GVA per worker), the
# improved group's jobs, land's share of the gain, dispersion across places, the lagging place's own gain
# and the share of the gain that lands elsewhere, nominal wages there (C9), and its tradables' unit costs (C8).

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_uk.R')
source('code/tradeable_jobs/functions_io.R')
source('code/tradeable_jobs/functions_rv2023.R')
source('code/tradeable_jobs/functions_modelF.R')

mf_N <- 12; mf_R <- 3; mf_shock <- 0.05
mf_deps <- c('code/tradeable_jobs/functions_modelF.R', 'code/tradeable_jobs/functions_rv2023.R', 'code/tradeable_jobs/16_modelF.R',
             file.path(tj_output_dir, 't2_groups.csv'), file.path(tj_output_dir, 't2_group_coefficients.csv'))

mf <- tj_cached('modelF', {
  gr <- read_csv(file.path(tj_output_dir, 't2_groups.csv'), show_col_types = FALSE)
  cf <- read_csv(file.path(tj_output_dir, 't2_group_coefficients.csv'), show_col_types = FALSE)
  cal <- mf_calibrate(gr, cf)
  S <- length(cal$sectors)
  ce <- mf_calibrate_exports(cal, mf_N)
  phi <- ce$phi
  q0 <- ce$solution$q        # foreign demand held at its calibrated level in every experiment (see functions_modelF.R)

  # CHECKS ----
  # 1. No intermediates: the same as the round 1 engine
  set.seed(3); a5 <- rv_draw_a(6, 5, 0.2); ts5 <- c(1.1, 1.3, 1.5, 1.8, 2.2)
  r0 <- rv_solve(rv_spec(6, 5, ts5, a5, gamma = 0.9))
  f0 <- mf_solve(mf_spec(6, 5, a5, ts5, gL = rep(0.9, 5), gT = rep(0.1, 5), G = matrix(0, 5, 5)))
  # 2. Hulten: one closed place, the calibrated input-output structure, fixed land and labour
  hspec <- function(a) mf_spec(1, S, matrix(a, 1, S), cal$t_s, gL = cal$gL, gT = 1 - cal$gL - colSums(cal$G), G = cal$G,
                               eta = 0, beta0 = 0, beta_s = cal$beta_s / sum(cal$beta_s) * (1 - cal$alpha), exports = FALSE,
                               mobility = 'immobile', L = 1, L_i = 1)
  hb <- mf_solve(hspec(rep(1, S))); hw <- mf_outcomes(hb, hspec(rep(1, S)))$national$welfare_immobile
  hgdp <- sum(hb$w * hb$Ls) + sum(hb$r)
  hulten <- tibble(sector = cal$sectors, domar = colSums(hb$rev) / hgdp,
                   model = sapply(seq_len(S), function(s) {
                     a <- rep(1, S); a[s] <- exp(1e-4); sp <- hspec(a)
                     (log(mf_outcomes(mf_solve(sp, start = hb), sp)$national$welfare_immobile) - log(hw)) / 1e-4
                   }))
  checks <- tibble(
    check = c('Model F with no intermediates against the round 1 engine: max |log wage gap|',
              'Hulten, one closed place: max |gain - Domar weight|', 'Export calibration: max |log gap| in export shares',
              'Calibrated output shares: correlation with the input-output tables'),
    value = c(max(abs(log(r0$w) - log(f0$w))), max(abs(hulten$model - hulten$domar)), ce$max_log_gap,
              cor(colSums(ce$solution$rev) / sum(ce$solution$rev), cal$output / sum(cal$output))))

  # EXPERIMENTS ---- (mf_run_draw() in functions_modelF.R; draws, mobility settings and supply chains in parallel)
  dem <- list(phi = phi, q0 = q0, P_ref = NULL, eps_c = 1, eps_i = 1, sigma_x = NULL)
  tasks <- expand_grid(seed = 100 + seq_len(mf_R), mob = c('frechet', 'immobile'), chains = c(TRUE, FALSE))
  runs <- bind_rows(parallel::mclapply(seq_len(nrow(tasks)), function(k)
    mf_run_draw(cal, dem, tasks$seed[k], tasks$mob[k], tasks$chains[k], N = mf_N, shock = mf_shock),
    mc.cores = min(nrow(tasks), max(1, parallel::detectCores() - 2))))
  checks <- bind_rows(checks, tibble(check = 'Largest trade imbalance in any run (share of income; zero by Walras with fixed foreign demand)',
                                     value = max(abs(runs$trade_gap), na.rm = TRUE)))
  list(cal = cal, phi = phi, q0 = q0, checks = checks, hulten = hulten, runs = runs,
       sectors = tibble(group = cal$sectors, group_name = cal$names, limit = cal$limit, foundational = cal$foundational,
                        t_s = cal$t_s, gL = cal$gL, gT = cal$gT, inputs_domestic = colSums(cal$G), gM = cal$gM,
                        beta_s = cal$beta_s, phi = phi))
}, depends = mf_deps)

# Summaries across draws
mf_runs <- mf$runs
mf_e1 <- mf_runs %>% filter(experiment == 'E1 national') %>%
  group_by(group, mobility, supply_chains) %>%
  summarise(across(c(d_welfare, d_u_mean, d_gva_pw, hulten, d_group_jobs, land_share, d_cv_u, d_cv_gva), mean),
            converged = all(converged), .groups = 'drop')
mf_e2 <- mf_runs %>% filter(experiment == 'E2 local') %>%
  group_by(group, mobility, supply_chains) %>%
  summarise(across(c(d_welfare, lag_d_u, lag_d_gva_pw, lag_d_wage, lag_d_pop, lag_d_rent, lag_d_tradable_cost, lag_gain_share,
                     others_d_u, land_share), mean), converged = all(converged), .groups = 'drop')
mf_e3 <- mf_runs %>% filter(grepl('^P', experiment)) %>%
  group_by(experiment, mobility) %>%
  summarise(across(any_of(c('d_welfare', 'd_u_mean', 'd_gva_pw', 'hulten', 'points', 'land_share', 'd_cv_u', 'd_cv_gva',
                            'lag_d_u', 'lag_gain_share')), ~ mean(.x, na.rm = TRUE)), converged = all(converged), .groups = 'drop')
# T8: does the official lens (nominal GVA per worker) disagree in sign with real income?
mf_lens <- mf_runs %>% filter(experiment %in% c('E1 national', 'E2 local'), supply_chains) %>%
  mutate(gva_lens = if_else(experiment == 'E1 national', d_gva_pw, lag_d_gva_pw),
         real_lens = if_else(experiment == 'E1 national', d_welfare, lag_d_u)) %>%
  group_by(experiment, group, mobility) %>%
  summarise(gva_lens = mean(gva_lens), real_lens = mean(real_lens), .groups = 'drop') %>%
  mutate(disagree = sign(gva_lens) != sign(real_lens))

tj_write(mf$checks, 'mf_checks.csv')
tj_write(mf$sectors, 'mf_sectors.csv')
tj_write(mf_runs, 'mf_runs.csv')
tj_write(mf_e1, 'mf_e1_national.csv')
tj_write(mf_e2, 'mf_e2_local.csv')
tj_write(mf_e3, 'mf_e3_proxies.csv')
tj_write(mf_lens, 'mf_lens.csv')
