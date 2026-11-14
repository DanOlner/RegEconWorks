# Model F closure sensitivity: the national experiments (E1) under Rice and Venables's own trade closure,
# where the import price is fixed and a foreign-demand shifter q balances trade at every step, against
# the closure 16_modelF.R uses (foreign demand fixed, the UK wage and price level against world prices set
# by equilibrium). In theirs, a productivity gain in an export sector is absorbed by weaker foreign demand
# for all UK exports, so little of it shows up as cheaper imports.
# One draw of productivities, people mobile, supply chains on.

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_uk.R')
source('code/tradeable_jobs/functions_io.R')
source('code/tradeable_jobs/functions_rv2023.R')
source('code/tradeable_jobs/functions_modelF.R')

mf_closure <- tj_cached('modelF_closure', {
  gr <- read_csv(file.path(tj_output_dir, 't2_groups.csv'), show_col_types = FALSE)
  cf <- read_csv(file.path(tj_output_dir, 't2_group_coefficients.csv'), show_col_types = FALSE)
  cal <- mf_calibrate(gr, cf); S <- length(cal$sectors); N <- 12
  ce <- mf_calibrate_exports(cal, N); q0 <- ce$solution$q
  set.seed(101); a0 <- rv_draw_a(N, S, 0.2)
  bind_rows(lapply(c('Foreign demand fixed (Model F)', 'Rice and Venables: q balances trade'), function(cl) {
    mk <- function(a) mf_from_cal(cal, a, phi = ce$phi, q_fixed = if (grepl('fixed', cl)) q0 else NULL)
    s0 <- mf_solve(mk(a0)); o0 <- mf_outcomes(s0, mk(a0)); dom <- colSums(s0$rev) / o0$national$gdp
    bind_rows(lapply(seq_len(S), function(g) {
      a1 <- a0; a1[, g] <- a1[, g] * 1.05
      s1 <- mf_solve(mk(a1), start = s0); o1 <- mf_outcomes(s1, mk(a1))
      tibble(closure = cl, group = cal$sectors[g], converged = s1$converged,
             d_welfare = log(o1$national$welfare) - log(o0$national$welfare), hulten = dom[g] * log(1.05),
             export_share = cal$export_share[g])
    }))
  }))
}, depends = c('code/tradeable_jobs/functions_modelF.R', 'code/tradeable_jobs/16b_modelF_closure.R',
               file.path(tj_output_dir, 't2_groups.csv'), file.path(tj_output_dir, 't2_group_coefficients.csv')))

# The policy proxies P1-P4 under both closures (same draw, people mobile and immobile)
mf_closure_proxies <- tj_cached('modelF_closure_proxies', {
  gr <- read_csv(file.path(tj_output_dir, 't2_groups.csv'), show_col_types = FALSE)
  cf <- read_csv(file.path(tj_output_dir, 't2_group_coefficients.csv'), show_col_types = FALSE)
  cal <- mf_calibrate(gr, cf); S <- length(cal$sectors); N <- 12
  ce <- mf_calibrate_exports(cal, N); q0 <- ce$solution$q
  upstream <- cal$sectors %in% c('wholesale_motor', 'transport', 'admin_support', 'utilities', 'construction')
  local_g <- cal$sectors %in% c('retail', 'hospitality', 'arts_personal')
  frontier <- cal$limit == 'Tradable frontier'
  set.seed(101); a0 <- rv_draw_a(N, S, 0.2)
  prox <- list()
  a1 <- a0; for (g in which(frontier)) { top <- order(a0[, g], decreasing = TRUE)[1:2]; a1[top, g] <- a1[top, g] * 1.10 }; prox[['P1 frontier push']] <- a1
  a1 <- a0; for (g in seq_len(S)) { m <- median(a0[, g]); lo <- a0[, g] < m; a1[lo, g] <- a0[lo, g] + 0.5 * (m - a0[lo, g]) }; prox[['P2 long tail']] <- a1
  a1 <- a0; a1[, upstream] <- a1[, upstream] * 1.05; prox[['P3 upstream']] <- a1
  a1 <- a0; a1[, local_g] <- a1[, local_g] * 1.05; prox[['P4 local services']] <- a1
  bind_rows(lapply(c('Foreign demand fixed (Model F)', 'Rice and Venables: q balances trade'), function(cl) {
    bind_rows(lapply(c('frechet', 'immobile'), function(mob) {
      mk <- function(a) mf_from_cal(cal, a, phi = ce$phi, q_fixed = if (grepl('fixed', cl)) q0 else NULL, mobility = mob)
      s0 <- mf_solve(mk(a0)); o0 <- mf_outcomes(s0, mk(a0))
      wel <- function(o) if (mob == 'frechet') o$national$welfare else o$national$welfare_immobile
      bind_rows(lapply(names(prox), function(nm) {
        s1 <- mf_solve(mk(prox[[nm]]), start = s0)
        tibble(closure = cl, mobility = mob, proxy = nm, converged = s1$converged,
               d_welfare = log(wel(mf_outcomes(s1, mk(prox[[nm]])))) - log(wel(o0)),
               points = sum(s0$Ls * log(prox[[nm]] / a0)) / sum(s0$Ls))
      }))
    }))
  })) %>% mutate(gain_per_point = d_welfare / points) %>%
    group_by(closure, mobility) %>% mutate(breakeven_vs_P1 = gain_per_point / gain_per_point[proxy == 'P1 frontier push']) %>% ungroup()
}, depends = c('code/tradeable_jobs/functions_modelF.R', 'code/tradeable_jobs/16b_modelF_closure.R',
               file.path(tj_output_dir, 't2_groups.csv'), file.path(tj_output_dir, 't2_group_coefficients.csv')))

tj_write(mf_closure, 'mf_closure_sensitivity.csv')
tj_write(mf_closure_proxies, 'mf_closure_proxies.csv')
