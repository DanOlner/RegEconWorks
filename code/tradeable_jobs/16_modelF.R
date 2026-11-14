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

  # EXPERIMENTS ----
  tradable <- cal$t_s == min(cal$t_s)
  upstream <- cal$sectors %in% c('wholesale_motor', 'transport', 'admin_support', 'utilities', 'construction')
  local_g <- cal$sectors %in% c('retail', 'hospitality', 'arts_personal')
  frontier <- cal$limit == 'Tradable frontier'

  one_draw <- function(seed) {
    set.seed(seed); a0 <- rv_draw_a(mf_N, S, 0.2)
    out <- list()
    for (mob in c('frechet', 'immobile')) {
      for (chains in c(TRUE, FALSE)) {
        mk <- function(a, ...) mf_from_cal(cal, a, supply_chains = chains, phi = phi, mobility = mob, q_fixed = q0, ...)
        sp0 <- mk(a0); s0 <- mf_solve(sp0); o0 <- mf_outcomes(s0, sp0)
        wel <- function(o) if (mob == 'frechet') o$national$welfare else o$national$welfare_immobile
        lag <- which.min(o0$places$u)
        dom0 <- colSums(s0$rev) / o0$national$gdp
        inc0 <- o0$national$wage_bill + o0$national$rent_total
        res <- function(sp1, s1, label, group = NA, where = 'all places', hulten_pred = NA) {
          o1 <- mf_outcomes(s1, sp1)
          gi <- if (is.na(group)) NA else match(group, cal$sectors)
          money0 <- o0$places$L * o0$places$y; dlu <- log(o1$places$u) - log(o0$places$u)
          gain_i <- money0 * dlu
          inc1 <- o1$national$wage_bill + o1$national$rent_total
          tibble(experiment = label, group = group, where = where, mobility = mob, supply_chains = chains, seed = seed,
                 converged = s1$converged, trade_gap = s1$trade_gap,
                 d_welfare = log(wel(o1)) - log(wel(o0)),
                 d_u_mean = log(o1$national$u_mean) - log(o0$national$u_mean),
                 d_gva_pw = log(o1$national$gva_per_worker) - log(o0$national$gva_per_worker),
                 hulten = hulten_pred,
                 d_group_jobs = if (is.na(gi)) NA else log(sum(s1$Ls[, gi])) - log(sum(s0$Ls[, gi])),
                 land_share = (o1$national$rent_total - o0$national$rent_total) / (inc1 - inc0),
                 d_cv_u = o1$national$cv_u - o0$national$cv_u,
                 d_cv_gva = o1$national$cv_gva_per_worker - o0$national$cv_gva_per_worker,
                 lag_d_u = dlu[lag],
                 lag_d_gva_pw = log(o1$places$gva_per_worker[lag]) - log(o0$places$gva_per_worker[lag]),
                 lag_d_wage = log(o1$places$w[lag]) - log(o0$places$w[lag]),
                 lag_d_pop = log(o1$places$L[lag]) - log(o0$places$L[lag]),
                 lag_d_rent = log(o1$places$rent[lag]) - log(o0$places$rent[lag]),
                 lag_d_tradable_cost = mean(s1$log_p[lag, tradable] - s0$log_p[lag, tradable]),
                 lag_gain_share = gain_i[lag] / sum(gain_i),
                 others_d_u = sum((money0 * dlu)[-lag]) / sum(money0[-lag]))
        }
        rows <- list()
        # E1 national and E2 local, group by group
        for (g in seq_len(S)) {
          a1 <- a0; a1[, g] <- a1[, g] * (1 + mf_shock)
          sp1 <- mk(a1); rows[[length(rows) + 1]] <- res(sp1, mf_solve(sp1, start = s0), 'E1 national', cal$sectors[g],
                                                          hulten_pred = dom0[g] * log(1 + mf_shock))
          a2 <- a0; a2[lag, g] <- a2[lag, g] * (1 + mf_shock)
          sp2 <- mk(a2); rows[[length(rows) + 1]] <- res(sp2, mf_solve(sp2, start = s0), 'E2 local', cal$sectors[g], 'lagging place',
                                                          hulten_pred = s0$rev[lag, g] / o0$national$gdp * log(1 + mf_shock))
        }
        if (chains) {
          # E3 policy proxies
          prox <- list()
          a1 <- a0; for (g in which(frontier)) { top <- order(a0[, g], decreasing = TRUE)[1:2]; a1[top, g] <- a1[top, g] * 1.10 }
          prox[['P1 frontier push: +10% in the top 2 places of each frontier group']] <- a1
          a1 <- a0; for (g in seq_len(S)) { m <- median(a0[, g]); lo <- a0[, g] < m; a1[lo, g] <- a0[lo, g] + 0.5 * (m - a0[lo, g]) }
          prox[['P2 long tail: places below the median close half the gap, every group']] <- a1
          a1 <- a0; a1[, upstream] <- a1[, upstream] * (1 + mf_shock); prox[['P3 upstream: +5% in the business-to-business groups']] <- a1
          a1 <- a0; a1[, local_g] <- a1[, local_g] * (1 + mf_shock); prox[['P4 local services: +5% in retail, hospitality, personal']] <- a1
          for (nm in names(prox)) {
            a1 <- prox[[nm]]; sp1 <- mk(a1)
            hp <- sum(s0$rev * log(a1 / a0)) / o0$national$gdp
            rows[[length(rows) + 1]] <- res(sp1, mf_solve(sp1, start = s0), nm, hulten_pred = hp) %>%
              mutate(points = sum(s0$Ls * log(a1 / a0)) / sum(s0$Ls))
          }
          ts7 <- cal$t_s; ts7[local_g] <- 1.7
          sp7 <- mf_spec(mf_N, S, a0, ts7, gL = cal$gL, gT = cal$gT, G = cal$G, gC = cal$gC, gM = cal$gM, alpha = cal$alpha,
                         beta0 = cal$beta0, beta_s = cal$beta_s, phi = phi, mobility = mob, q_fixed = q0)
          rows[[length(rows) + 1]] <- res(sp7, mf_solve(sp7, start = s0), 'P7 lower trade costs for local services (t 2.0 to 1.7)')
          sp9 <- mk(a0, eta = 3)
          s9 <- mf_solve(sp9, start = s0)
          rows[[length(rows) + 1]] <- res(sp9, s9, 'P9 more elastic land (eta 1 to 3)')
          a1 <- a0; a1[, local_g] <- a1[, local_g] * (1 + mf_shock)
          # P4 under elastic land, measured against the elastic-land baseline
          sp49 <- mk(a1, eta = 3); s49 <- mf_solve(sp49, start = s9)
          o9 <- mf_outcomes(s9, sp9); o49 <- mf_outcomes(s49, sp49)
          rows[[length(rows) + 1]] <- tibble(experiment = 'P4 with P9: local services +5%, land eta 3', mobility = mob, supply_chains = TRUE,
                                             seed = seed, converged = s49$converged,
                                             d_welfare = log(wel(o49)) - log(wel(o9)),
                                             land_share = (o49$national$rent_total - o9$national$rent_total) /
                                               ((o49$national$wage_bill + o49$national$rent_total) - (o9$national$wage_bill + o9$national$rent_total)))
        }
        out[[paste(mob, chains)]] <- bind_rows(rows) %>% mutate(lag_place = lag)
      }
    }
    bind_rows(out)
  }
  runs <- bind_rows(lapply(seq_len(mf_R), function(r) one_draw(100 + r)))
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
