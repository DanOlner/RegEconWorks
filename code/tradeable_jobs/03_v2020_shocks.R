# Model A shocks (Venables 2020 sections 3 to 5): import competition, an export boom in one tradable
# sector, and fiscal contraction under two financing assumptions.

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_v2020.R')
shock_deps <- c('code/tradeable_jobs/functions_v2020.R', 'code/tradeable_jobs/03_v2020_shocks.R')

# One row per city type plus economy totals, for a solved economy
describe <- function(sol, label) {
  wide <- sol$cities %>% select(type, count, L, w, u, R) %>%
    pivot_wider(names_from = type, values_from = c(count, L, w, u, R), names_sep = '_')
  bind_cols(tibble(case = label, pN = sol$pN, P = sol$P), wide, sol$totals)
}

# IMPORT COMPETITION (C3, C4) ----
# Some type-T cities lose their tradable sector. Start points: X (50%) and an interior point (40%).
# The last case pushes the economy past E, where new tradables should start in type-N cities.
v2020_import <- tj_cached('v2020_import', {
  spec <- cm_spec()
  cases <- tribble(~from, ~to,
                   50, 40,
                   40, 35,
                   40, 30,
                   40, 20)
  bind_rows(lapply(seq_len(nrow(cases)), function(i) {
    before <- cm_solve(c(T = cases$from[i], N = 100 - cases$from[i]), spec)
    after  <- cm_adjust(c(T = cases$to[i], N = 100 - cases$to[i]), spec)
    re_entered <- if (nrow(after$moves)) sum(after$moves$cities[after$moves$to == 'T']) else 0
    bind_rows(describe(before, 'before'), describe(after, 'after')) %>%
      mutate(shock = sprintf('%d%% to %d%% type-T', cases$from[i], cases$to[i]),
             re_entered_T = c(0, re_entered), .before = 1)
  }))
}, depends = shock_deps)

# EXPORT BOOM IN ONE TRADABLE SECTOR (C5) ----
# Two tradable sectors, 'old' (O) and 'new' (W), each with localisation economies; spending shares
# theta_O = theta_W = 0.25, theta_N = 0.5. Raise the world price of W (or of both) step by step, letting
# cities switch whenever a lone firm would gain (cm_adjust), starting from an interior equilibrium.
v2020_boom <- tj_cached('v2020_boom', {
  boom_spec <- function(pO, pW) cm_spec(types = list(O = cm_type('T', p = pO), W = cm_type('T', p = pW), N = cm_type('N')))
  run_path <- function(prices, start) {
    counts <- start; out <- list()
    for (k in seq_len(nrow(prices))) {
      spec <- boom_spec(prices$pO[k], prices$pW[k])
      sol <- cm_adjust(counts, spec)
      counts <- sol$counts
      out[[k]] <- describe(sol, 'path') %>% mutate(pO = prices$pO[k], pW = prices$pW[k], .before = 1)
    }
    bind_rows(out)
  }
  start <- cm_adjust(c(O = 20, W = 20, N = 60), boom_spec(1, 1))$counts
  steps <- seq(1, 1.4, by = 0.0025)
  bind_rows(
    run_path(tibble(pO = 1, pW = steps), start) %>% mutate(boom = 'new sector only', .before = 1),
    run_path(tibble(pO = steps, pW = steps), start) %>% mutate(boom = 'both tradable sectors', .before = 1))
}, depends = shock_deps)

# FISCAL CONTRACTION (C7) ----
# G falls from 0 (real units of the composite good). Start at 40% type-T. 'external' is the paper's set-up
# (no tax: a cut in G is a surplus sent abroad); 'balanced' finances G with a lump-sum tax on workers.
# Report in units of the price index (P = 1), so pT / P is the exchange rate, as in Venables (2020) Fig. 3.
# The same run with G rising instead (more public spending on non-tradables) tests C13: does adding
# non-tradable demand push marginal tradable cities into non-tradables?
v2020_fiscal <- tj_cached('v2020_fiscal', {
  bind_rows(lapply(c(-1, 1), function(direction) {
    G_path <- seq(0, 25 * direction, by = 0.5 * direction)
    bind_rows(lapply(c('external', 'balanced'), function(fin) {
      counts <- c(T = 40, N = 60); out <- list()
      for (k in seq_along(G_path)) {
        spec <- cm_spec(G = G_path[k], financing = fin)
        sol <- cm_adjust(counts, spec)
        counts <- sol$counts
        cT <- sol$cities[sol$cities$type == 'T', ]; cN <- sol$cities[sol$cities$type == 'N', ]
        out[[k]] <- tibble(direction = if (direction < 0) 'contraction' else 'expansion', financing = fin,
                           G = G_path[k], MT = counts[['T']],
                           exchange_rate = spec$types$T$p / sol$P, wT_real = cT$w / sol$P, wN_real = cN$w / sol$P,
                           u = cN$u, uT_plus_rT = cT$u + cT$r_pc, uN_plus_rN = cN$u + cN$r_pc,
                           LT = cT$L, LN = cN$L, emp_T = cT$count * cT$L, emp_N = cN$count * cN$L,
                           U = sol$totals$U, rent_share = sol$totals$rent_share)
      }
      bind_rows(out)
    }))
  }))
}, depends = shock_deps)

# Where regime 2 starts (contraction: type-N cities begin switching to tradables), and where expansion
# starts pushing type-T cities into non-tradables
v2020_fiscal_regimes <- v2020_fiscal %>% group_by(direction, financing) %>%
  summarise(cities_start_switching_at_G = if (any(abs(MT - 40) > 1e-6)) G[which(abs(MT - 40) > 1e-6)[1]] else NA_real_,
            MT_at_end = last(MT), .groups = 'drop')
# Export boom: where old-sector cities start switching, and what they switch to
v2020_boom_summary <- v2020_boom %>% group_by(boom) %>%
  summarise(first_O_exit_at_pW = if (any(count_O < 20 - 1e-6, na.rm = TRUE)) min(pW[count_O < 20 - 1e-6], na.rm = TRUE) else NA_real_,
            O_gone_at_pW = if (any(is.na(count_O) | count_O < 1e-6)) min(pW[is.na(count_O) | count_O < 1e-6]) else NA_real_,
            N_cities_max = max(count_N), N_cities_end = last(count_N), W_cities_end = last(count_W), .groups = 'drop')

tj_write(v2020_import, 'v2020_import_competition.csv')
tj_write(v2020_boom, 'v2020_export_boom.csv')
tj_write(v2020_fiscal, 'v2020_fiscal.csv')
print(v2020_import %>% select(shock, case, re_entered_T, count_T, w_T, w_N, L_T, L_N, R_T, R_N, u_N, U, rent_share, popshare_N), width = 200)
print(v2020_fiscal_regimes)
print(v2020_boom_summary)
