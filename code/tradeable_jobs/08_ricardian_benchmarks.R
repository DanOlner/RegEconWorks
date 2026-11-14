# Model D: the Ricardian benchmarks (plan part 3, steps 1, 3, 5 and 6).
#   A. R1, Dornbusch-Fischer-Samuelson: V2020's experiments between two countries with immobile labour
#   B. The RV2023 engine with switches, to see which ingredient each claim needs. Narrow Ricardian
#      benchmark (R0-R2) = immobile labour between places; broad (R3) = mobile labour plus land.
#   C. Agglomeration added to the RV2023 engine: multiple equilibria (C2) and whether a temporary shock
#      removes a sector for good (C3), as in Krugman (1987) and V2020

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_dfs.R')
source('code/tradeable_jobs/functions_rv2023.R')
bm_deps <- c('code/tradeable_jobs/functions_dfs.R', 'code/tradeable_jobs/functions_rv2023.R',
             'code/tradeable_jobs/08_ricardian_benchmarks.R')

# A. DFS ----
dfs_z <- (seq_len(4000) - 0.5) / 4000
dfs_a <- rep(1, length(dfs_z))
dfs_as <- exp(1.5 * (0.5 - dfs_z))   # Home's comparative advantage in low z; symmetric at the start
dfs_results <- tj_cached('dfs_results', {
  shocked <- dfs_as; shocked[dfs_z < 0.2] <- shocked[dfs_z < 0.2] * 0.6     # Foreign catches up in Home's best exports
  boom <- dfs_a; boom[dfs_z > 0.25 & dfs_z < 0.35] <- 0.7                    # Home productivity jumps in a few goods
  bind_rows(
    dfs_solve(dfs_a, dfs_as) %>% mutate(case = 'Baseline'),
    dfs_solve(dfs_a, shocked) %>% mutate(case = 'Import competition: Foreign 40% more productive in Home\'s top 20% of exports'),
    dfs_solve(dfs_a, dfs_as) %>% mutate(case = 'Shock reversed (static model, unique equilibrium: back to baseline)'),
    dfs_solve(boom, dfs_as) %>% mutate(case = 'Boom: Home 30% more productive in 10% of goods'),
    dfs_solve(dfs_a, dfs_as, Tr = 0.1) %>% mutate(case = 'Transfer abroad of 10% of Home income (fiscal contraction analogue)'),
    dfs_solve(dfs_a, dfs_as, g = 1) %>% mutate(case = 'No trade costs (no non-traded goods)')
  ) %>% relocate(case)
}, depends = bm_deps)

# B. RV2023 ENGINE WITH SWITCHES ----
bm_N <- 300; bm_S <- 50; bm_t <- seq(1, 4, length.out = bm_S)
bm_variants <- list(
  'RV2023 as published (R3: Ricardian, trade costs vary, land, mobile labour)' = list(),
  'No variation in tradability (every t_s = 2.5)'          = list(t_s = rep(2.5, bm_S)),
  'Free trade in every sector (every t_s = 1)'             = list(t_s = rep(1, bm_S)),
  'Land supply nearly elastic (eta = 50)'                  = list(eta = 50),
  'No land (alpha ~ 0, gamma = 1)'                         = list(alpha = 1e-6, gamma = 1, beta_s = rep((1 - 1e-6 - 0.1875) / bm_S, bm_S)),
  'Perfect mobility (vartheta = 1000)'                     = list(vartheta = 1000),
  'Immobile labour, land kept (R0-R2 plus land)'           = list(mobility = 'immobile'),
  'Immobile labour, no land (R0-R2: plain Ricardian)'      = list(mobility = 'immobile', alpha = 1e-6, gamma = 1, beta_s = rep((1 - 1e-6 - 0.1875) / bm_S, bm_S)),
  'Near-homogeneous goods (sigma = 30)'                    = list(sigma = 30),
  'No Ricardian differences (every a_is = 1)'              = list(no_ricardian = TRUE)
)

bm_run <- function(label, args, seed) {
  set.seed(seed)
  a <- rv_draw_a(bm_N, bm_S, 0.2)
  if (isTRUE(args$no_ricardian)) a[] <- 1
  args$no_ricardian <- NULL
  t_s <- if (is.null(args$t_s)) bm_t else args$t_s; args$t_s <- NULL
  sp <- do.call(rv_spec, c(list(N = bm_N, S = bm_S, t_s = t_s, a = a), args))
  sol <- rv_solve(sp, max_iter = 30000)
  pl <- rv_places(sol)
  lw <- log(pl$w / mean(pl$w)); lu <- log(pl$u / mean(pl$u))
  # Ricardian advantage by tradability: mean productivity in the most and least tradable thirds of
  # sectors (by the published trade costs, so the same sectors in every variant)
  top <- bm_t <= quantile(bm_t, 1 / 3); bottom <- bm_t >= quantile(bm_t, 2 / 3)
  TA <- rowMeans(a[, top, drop = FALSE]) - 1; NA_adv <- rowMeans(a[, bottom, drop = FALSE]) - 1
  phys <- rowSums(sol$Ls * a) / rowSums(sol$Ls)     # employment-weighted physical productivity
  sx <- rv_sparsity(sol$Ls)
  # no spread in sparsity (e.g. identical places) means nothing to regress on
  r2 <- function(v) if (!all(is.finite(v)) || sd(v) < 1e-12) NA_real_ else summary(lm(lw ~ v))$adj.r.squared
  fit <- if (sd(TA) > 0) coef(lm(lw ~ TA + NA_adv)) else c(NA, NA, NA)
  fit_u <- if (sd(TA) > 0) coef(lm(lu ~ TA + NA_adv)) else c(NA, NA, NA)
  tibble(variant = label, seed = seed, converged = sol$converged,
         sd_log_wage = sd(lw), sd_log_utility = sd(lu), sd_log_population = sd(log(pl$L)),
         wage_on_tradable_advantage = fit[2], wage_on_nontradable_advantage = fit[3],
         utility_on_tradable_advantage = fit_u[2], utility_on_nontradable_advantage = fit_u[3],
         cor_wage_physical_productivity = if (sd(phys) > 1e-12) cor(lw, log(phys)) else NA_real_,
         R2_wage_on_SB_SD = r2(sx$SB_SD), R2_wage_on_SB_SK = r2(sx$SB_SK))
}

bm_rv_runs <- tj_cached('bm_rv_runs', bind_rows(lapply(names(bm_variants), function(v)
  bind_rows(lapply(1:5, function(seed) bm_run(v, bm_variants[[v]], seed))))), depends = bm_deps)

bm_rv_summary <- bm_rv_runs %>% group_by(variant) %>%
  summarise(runs = n(), all_converged = all(converged), across(sd_log_wage:R2_wage_on_SB_SK, ~ mean(.x, na.rm = TRUE)), .groups = 'drop') %>%
  arrange(match(variant, names(bm_variants)))

# C. AGGLOMERATION: MULTIPLE EQUILIBRIA AND HYSTERESIS ----
# Smaller economy (50 places, 10 sectors) so each case solves quickly. For each strength of agglomeration
# kappa: (i) solve from an even start and from a start tilted towards one random place per sector; if
# the answers differ there is more than one equilibrium. (ii) Take the most tradable sector's largest
# place, cut its productivity by 20%, re-solve, restore it, re-solve: does the sector come back?
bm_agglom <- tj_cached('bm_agglom', {
  N <- 50; S <- 10; t_s <- seq(1, 4, length.out = S)
  set.seed(7); a <- rv_draw_a(N, S, 0.1)
  solve_or_null <- function(...) tryCatch(rv_solve(..., damp = 0.3, max_iter = 60000), error = function(e) NULL)
  bind_rows(lapply(c(0, 0.01, 0.025, 0.04), function(kappa) {
    sp <- rv_spec(N, S, t_s = t_s, a = a, kappa = kappa)
    even <- solve_or_null(sp)
    if (is.null(even)) return(tibble(kappa = kappa, converged = FALSE))
    set.seed(11)
    tilt_Ls <- matrix(sp$L / (N * S), N, S); for (s in 1:S) tilt_Ls[sample(N, 1), s] <- tilt_Ls[1, s] * 8
    tilted <- solve_or_null(sp, start = list(w = matrix(1, N, S), r = rep(1, N), M = rowSums(tilt_Ls), rebate = 0,
                                             Ls = tilt_Ls * sp$L / sum(tilt_Ls)))
    s_star <- 1; i_star <- which.max(even$Ls[, s_star])
    a_shock <- a; a_shock[i_star, s_star] <- a[i_star, s_star] * 0.8
    shocked <- solve_or_null(rv_spec(N, S, t_s = t_s, a = a_shock, kappa = kappa), start = even)
    restored <- if (is.null(shocked)) NULL else solve_or_null(sp, start = shocked)
    if (is.null(tilted) || is.null(restored)) return(tibble(kappa = kappa, converged = FALSE))
    tibble(kappa = kappa, converged = all(even$converged, tilted$converged, shocked$converged, restored$converged),
           max_log_diff_even_vs_tilted = max(abs(log(even$Ls) - log(tilted$Ls))),
           sector_share_of_place_before = even$Ls[i_star, s_star] / sum(even$Ls[, s_star]),
           after_shock = shocked$Ls[i_star, s_star] / sum(shocked$Ls[, s_star]),
           after_restoring = restored$Ls[i_star, s_star] / sum(restored$Ls[, s_star]),
           place_wage_before = rv_places(even)$w[i_star] / mean(rv_places(even)$w),
           place_wage_after_restoring = rv_places(restored)$w[i_star] / mean(rv_places(restored)$w))
  }))
}, depends = bm_deps)

tj_write(dfs_results, 'benchmark_dfs.csv')
tj_write(bm_rv_runs, 'benchmark_rv_engine_runs.csv')
tj_write(bm_rv_summary, 'benchmark_rv_engine.csv')
tj_write(bm_agglom, 'benchmark_agglomeration_hysteresis.csv')
print(as.data.frame(dfs_results %>% mutate(across(where(is.numeric), ~ round(.x, 3)))))
print(as.data.frame(bm_rv_summary %>% mutate(across(where(is.numeric), ~ round(.x, 3)))))
print(as.data.frame(bm_agglom %>% mutate(across(where(is.numeric), ~ round(.x, 4)))))
