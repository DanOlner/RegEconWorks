# Strong agglomeration over many productivity draws. Section 18 of the round 2 report found, for one draw of
# place-by-sector productivity, up to four stable equilibria at agglomeration 0.3, and that the long-tail
# proxy's break-even depended on which one the economy started in (it can tip the economy into another).
# This repeats that for six draws, to see how common multiple equilibria and policy-driven switches are, and
# whether switching favours broad catch-up or the frontier push.
#
# For each draw (the best-calibrated Model F: demand fitted to T6, elasticity 3 between places for local
# services; people mobile):
#   continuation  agglomeration 0 to 0.3, each step from the last step's equilibrium (functions_solvers.R)
#   multi-start   at 0.3, six starts scrambling the continuation equilibrium; distinct equilibria kept, with a
#                 perturbation test of stability (two tries)
#   policies      the four proxies from each stable equilibrium: the equilibrium reached by hill climbing from
#                 it, the welfare gain per point, and whether the economy switched (some place-sector's share
#                 of all workers moved by more than 1 point)
# Draws run in parallel, one per core. Script 27 does the same for draw 101 in more detail.

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_uk.R')
source('code/tradeable_jobs/functions_io.R')
source('code/tradeable_jobs/functions_rv2023.R')
source('code/tradeable_jobs/functions_modelF.R')
source('code/tradeable_jobs/functions_solvers.R')

sd_seeds <- 101:106; sd_kappa <- 0.3; sd_starts <- 6; sd_switch <- 0.01

sd_one_draw <- function(seed, cal, dem) {
  S <- length(cal$sectors); N <- 12
  set.seed(seed); a0 <- rv_draw_a(N, S, 0.2)
  mk <- function(k, a = a0) mf_from_cal(cal, a, phi = dem$phi, q_fixed = dem$q0, eps_c = dem$eps_c, eps_i = dem$eps_i,
                                        sigma_x = dem$sigma_x, P_ref = dem$P_ref, sigma_local = dem$sigma_local, kappa = k)
  hc <- function(pr, x) sv_hill_climb(pr, x, lambda = 0.05, tol = 1e-8, max_iter = 3000, monotone = FALSE)
  welfare_of <- function(pr, x) { pr$reset(); xs <- pmax(x, sv_floor); s <- pr$inner(xs / sum(xs)); lw <- pr$sp$vartheta * s$log_u
    exp((max(lw) + log(sum(exp(lw - max(lw))))) / pr$sp$vartheta) }
  s0 <- mf_solve(mk(0)); x0 <- s0$Ls / sum(s0$Ls)
  path <- sv_continuation(mk, c(seq(0.02, 0.1, 0.02), 0.12, 0.15, 0.2, 0.25, sd_kappa), x0, lambda = 0.05, tol = 1e-8, max_iter = 3000)
  last <- path[[length(path)]]
  if (is.null(last$found) || abs(last$value - sd_kappa) > 1e-9)
    return(list(summary = tibble(seed = seed, continuation_converged = FALSE)))
  pr <- last$pr; xc <- last$found$x
  set.seed(seed + 1000)
  starts <- lapply(seq_len(sd_starts), function(i) { y <- as.vector(xc) * exp(rnorm(length(xc), 0, 1.5)); matrix(y / sum(y), N, S) })
  fs <- lapply(starts, function(s) { f <- hc(pr, s); if (!is.null(f)) f$method <- 'hill climb'; f })
  cl <- sv_cluster(c(list(c(last$found, list(method = 'continuation'))), fs), pr, eigen = FALSE, tries = 2,
                   lambda = 0.05, tol = 1e-8, max_iter = 3000, monotone = FALSE)
  eq <- cl %>% mutate(welfare = vapply(x, function(xx) welfare_of(pr, xx), 0),
                      max_share_gap = vapply(x, function(xx) max(abs(as.vector(xx) - as.vector(xc))), 0))
  frontier <- cal$limit == 'Tradable frontier'
  upstream <- cal$sectors %in% c('wholesale_motor', 'transport', 'admin_support', 'utilities', 'construction')
  local_g <- cal$sectors %in% c('retail', 'hospitality', 'arts_personal')
  prox <- list()
  a1 <- a0; for (g in which(frontier)) { top <- order(a0[, g], decreasing = TRUE)[1:2]; a1[top, g] <- a1[top, g] * 1.10 }; prox[['P1 frontier push']] <- a1
  a1 <- a0; for (g in seq_len(S)) { m <- median(a0[, g]); lo <- a0[, g] < m; a1[lo, g] <- a0[lo, g] + 0.5 * (m - a0[lo, g]) }; prox[['P2 long tail']] <- a1
  a1 <- a0; a1[, upstream] <- a1[, upstream] * 1.05; prox[['P3 upstream']] <- a1
  a1 <- a0; a1[, local_g] <- a1[, local_g] * 1.05; prox[['P4 local services']] <- a1
  stable_ids <- which(eq$stable)
  pol <- bind_rows(lapply(stable_ids, function(e) bind_rows(lapply(names(prox), function(nm) {
    # (take the starting welfare first: inside tibble(), a column named eq would mask the table eq)
    x_eq <- eq$x[[e]]; w_eq <- eq$welfare[e]; pr1 <- sv_problem(mk(sd_kappa, prox[[nm]])); f <- hc(pr1, x_eq)
    if (is.null(f)) return(tibble(seed = seed, eq = e, proxy = nm, converged = FALSE))
    tibble(seed = seed, eq = e, proxy = nm, converged = TRUE,
           d_welfare = log(welfare_of(pr1, f$x)) - log(w_eq), points = sum(x_eq * log(prox[[nm]] / a0)),
           moved = max(abs(as.vector(f$x) - as.vector(x_eq))))
  })))) %>% mutate(switched = moved > sd_switch)
  list(summary = tibble(seed = seed, continuation_converged = TRUE, starts = sd_starts,
                        starts_converged = sum(!vapply(fs, is.null, TRUE)), equilibria = nrow(eq), stable = sum(eq$stable),
                        welfare_min = min(eq$welfare), welfare_max = max(eq$welfare), max_share_gap = max(eq$max_share_gap)),
       equilibria = eq %>% mutate(seed = seed, x = NULL), policies = pol)
}

sd_runs <- tj_cached('strong_agglomeration_draws', {
  dem <- readRDS(file.path(tj_cache_dir, 'modelF_local_sigma.rds'))$value$dem
  gr <- read_csv(file.path(tj_output_dir, 't2_groups.csv'), show_col_types = FALSE)
  cf <- read_csv(file.path(tj_output_dir, 't2_group_coefficients.csv'), show_col_types = FALSE)
  cal <- mf_calibrate(gr, cf)
  parallel::mclapply(sd_seeds, function(s) tryCatch(sd_one_draw(s, cal, dem), error = function(e) list(summary = tibble(seed = s, error = conditionMessage(e)))),
                     mc.cores = min(length(sd_seeds), max(1, parallel::detectCores() - 2)))
}, depends = c('code/tradeable_jobs/functions_io.R', 'code/tradeable_jobs/functions_rv2023.R', 'code/tradeable_jobs/functions_modelF.R',
               'code/tradeable_jobs/functions_solvers.R', file.path(tj_cache_dir, 'modelF_local_sigma.rds')),
   # keyed on the draw's code and settings rather than this whole script, so editing the summaries below doesn't
   # rerun the draws (about an hour). scipen is fixed because it changes how deparse() writes numbers such as
   # 1e-8, and the report sets it.
   key = c(local({ op <- options(scipen = 0); on.exit(options(op)); deparse(sd_one_draw) }), sd_seeds, sd_kappa, sd_starts, sd_switch))

sd_summary <- bind_rows(lapply(sd_runs, `[[`, 'summary'))
sd_equilibria <- bind_rows(lapply(sd_runs, `[[`, 'equilibria')) %>% group_by(seed) %>%
  mutate(welfare_vs_best = welfare / max(welfare) - 1) %>% ungroup()
sd_policies <- bind_rows(lapply(sd_runs, `[[`, 'policies')) %>%
  filter(converged) %>% group_by(seed, eq) %>%
  mutate(gain_per_point = d_welfare / points, breakeven = gain_per_point / gain_per_point[proxy == 'P1 frontier push']) %>% ungroup() %>%
  left_join(sd_equilibria %>% select(seed, eq = equilibrium, start_welfare_vs_best = welfare_vs_best), by = c('seed', 'eq'))
# (counts last: summarise() replaces a column as soon as it is named, so naming `switched` first would break the rest)
sd_by_proxy <- sd_policies %>% group_by(proxy) %>%
  summarise(cases = n(), share_switched = mean(switched), draws_switched = n_distinct(seed[switched]),
            breakeven_mean = mean(breakeven), breakeven_min = min(breakeven), breakeven_max = max(breakeven),
            breakeven_if_switched = if (any(switched)) mean(breakeven[switched]) else NA_real_,
            breakeven_if_not = if (any(!switched)) mean(breakeven[!switched]) else NA_real_,
            gain_per_point_if_switched = if (any(switched)) mean(gain_per_point[switched]) else NA_real_,
            gain_per_point_if_not = if (any(!switched)) mean(gain_per_point[!switched]) else NA_real_,
            moved_max = max(moved), n_switched = sum(switched), .groups = 'drop')

tj_write(sd_summary, 'strong_agglomeration_draws_summary.csv')
tj_write(sd_equilibria, 'strong_agglomeration_draws_equilibria.csv')
tj_write(sd_policies, 'strong_agglomeration_draws_policies.csv')
tj_write(sd_by_proxy, 'strong_agglomeration_draws_by_proxy.csv')
