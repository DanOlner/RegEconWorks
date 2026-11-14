# Equilibrium solvers for strong agglomeration and multiple equilibria (functions_solvers.R), tested on a
# case with a known answer, and a scan of where multiple equilibria start.
#
# Test case: two identical places, two identical tradable sectors (Model F with no supply chains, labour
# share 0.8, land 0.2, trade cost 1.1, elasticity 10 between places), agglomeration kappa = 0.3, mobility
# vartheta = 50, foreign demand held at its level in the symmetric equilibrium. Theory: a symmetric
# equilibrium (each place half of each sector), unstable when agglomeration is strong, and two mirror-image
# equilibria with each place specialised in one sector, stable.
# Each method is run and what it finds is recorded:
#   the model's own solver (mf_solve), from its default start and from asymmetric starts;
#   hill climbing (damped best responses, adaptive step) from 24 random starts;
#   residual search (Nelder-Mead on |log F(x) - log x|^2, then Newton) from the same starts;
#   brute force (every allocation on a grid of step 1/20, local minima polished both ways).
# Bifurcation scan: the largest real eigenvalue of the adjustment dynamics at the symmetric equilibrium,
# over agglomeration (kappa) and mobility (vartheta): positive means it is unstable and other equilibria exist.

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_uk.R')
source('code/tradeable_jobs/functions_io.R')
source('code/tradeable_jobs/functions_rv2023.R')
source('code/tradeable_jobs/functions_modelF.R')
source('code/tradeable_jobs/functions_solvers.R')

sv_deps <- c('code/tradeable_jobs/functions_modelF.R', 'code/tradeable_jobs/functions_solvers.R', 'code/tradeable_jobs/27_solvers.R')
sv_cores <- max(1, parallel::detectCores() - 2)
sv_test_spec <- function(kappa = 0.3, vartheta = 50, t = 1.1, fix_q = TRUE) {
  sp <- mf_spec(2, 2, matrix(1, 2, 2), c(t, t), gL = c(0.8, 0.8), gT = c(0.2, 0.2), G = matrix(0, 2, 2),
                kappa = kappa, vartheta = vartheta, L = 2)
  if (fix_q) sp$q_fixed <- mf_solve(sp)$q
  sp
}
sv_fmt <- function(m) paste(sprintf('%.3f', as.vector(m)), collapse = ' ')

sv_test <- tj_cached('solvers_test', {
  set.seed(1)
  sp <- sv_test_spec(); pr <- sv_problem(sp)
  # the model's own solver
  d0 <- tryCatch(mf_solve(sp, max_iter = 20000), error = function(e) NULL)
  direct <- tibble(start = 'default (even)', converged = !is.null(d0) && d0$converged, x = if (is.null(d0)) NA else sv_fmt(d0$Ls / sum(d0$Ls)))
  for (x0 in sv_random_x(2, 2, 6)) {
    st <- list(w = matrix(1, 2, 2), r = rep(1, 2), M = rowSums(x0 * 2), rebate = 0, Ls = x0 * 2, log_p = matrix(0, 2, 2), rev = matrix(1, 2, 2))
    d <- tryCatch(mf_solve(sp, start = st, max_iter = 20000), error = function(e) NULL)
    direct <- bind_rows(direct, tibble(start = sv_fmt(x0), converged = !is.null(d) && d$converged,
                                       x = if (is.null(d)) NA else sv_fmt(d$Ls / sum(d$Ls))))
  }
  starts <- sv_random_x(2, 2, 24)
  hc <- parallel::mclapply(starts, function(x0) { f <- sv_hill_climb(pr, x0); if (!is.null(f)) f$method <- 'hill climb'; f }, mc.cores = sv_cores)
  rs <- parallel::mclapply(starts, function(x0) { f <- sv_residual_search(pr, sv_z_of_x(x0)); if (!is.null(f)) f$method <- 'residual search'; f }, mc.cores = sv_cores)
  bf <- sv_brute_force(pr, steps = 20)
  methods <- list(`Hill climb` = hc, `Residual search` = rs, `Brute force` = bf$found)
  all_eq <- sv_cluster(c(hc, rs, bf$found), pr)
  found_by <- bind_rows(lapply(names(methods), function(m) {
    e <- sv_cluster(methods[[m]], pr)
    tibble(method = m, starts = if (m == 'Brute force') bf$local_minima else length(starts),
           converged = sum(!vapply(methods[[m]], is.null, TRUE)), equilibria_found = nrow(e),
           stable_found = sum(e$stable), unstable_found = sum(!e$stable))
  }))
  list(direct = direct, found_by = found_by, equilibria = all_eq %>% mutate(x = vapply(x, sv_fmt, '')),
       grid_points = bf$grid_points, local_minima = bf$local_minima)
}, depends = sv_deps)

sv_bifurcation <- tj_cached('solvers_bifurcation', {
  grid <- expand_grid(vartheta = c(10, 50, 200), kappa = c(0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5))
  bind_rows(parallel::mclapply(seq_len(nrow(grid)), function(i) {
    sp <- sv_test_spec(grid$kappa[i], grid$vartheta[i], fix_q = FALSE); pr <- sv_problem(sp)
    st <- tryCatch(sv_stability(pr, sv_z_of_x(matrix(0.25, 2, 2))), error = function(e) list(max_real = NA))
    tibble(vartheta = grid$vartheta[i], kappa = grid$kappa[i], sym_max_real_eigen = st$max_real)
  }, mc.cores = sv_cores))
}, depends = sv_deps)

tj_write(sv_test$direct, 'solvers_direct.csv')
tj_write(sv_test$found_by, 'solvers_found_by.csv')
tj_write(sv_test$equilibria %>% select(-any_of('gva_per_worker')), 'solvers_test_equilibria.csv')
tj_write(sv_bifurcation, 'solvers_bifurcation.csv')

# THE FULL MODEL ----
# The best-calibrated Model F (demand fitted to T6, elasticity 3 between places for local services;
# 24_modelF_local_sigma.R), one productivity draw, people mobile, agglomeration raised from 0 to 0.3.
#   continuation  each step solved by fixed-step hill climbing from the last step's equilibrium
#   multi-start   at 0.1, 0.2 and 0.3: eight starts, the continuation equilibrium's allocation scrambled
#                 (log shares + normal noise, sd 1.5), each hill-climbed; distinct equilibria kept, with a
#                 perturbation test of stability (no eigenvalues: 215 dimensions)
#   policies      at 0.3, the four proxies (P1-P4 as in mf_run_draw) from each distinct equilibrium: the new
#                 equilibrium reached by hill climbing from the old one, and the welfare gain per point
sv_full <- tj_cached('solvers_full_model', {
  ls_cache <- readRDS(file.path(tj_cache_dir, 'modelF_local_sigma.rds'))$value
  dem <- ls_cache$dem
  gr <- read_csv(file.path(tj_output_dir, 't2_groups.csv'), show_col_types = FALSE)
  cf <- read_csv(file.path(tj_output_dir, 't2_group_coefficients.csv'), show_col_types = FALSE)
  cal <- mf_calibrate(gr, cf); S <- length(cal$sectors); N <- 12
  set.seed(101); a0 <- rv_draw_a(N, S, 0.2)
  mk <- function(k, a = a0) mf_from_cal(cal, a, phi = dem$phi, q_fixed = dem$q0, eps_c = dem$eps_c, eps_i = dem$eps_i,
                                        sigma_x = dem$sigma_x, P_ref = dem$P_ref, sigma_local = dem$sigma_local, kappa = k)
  hc <- function(pr, x) sv_hill_climb(pr, x, lambda = 0.05, tol = 1e-8, max_iter = 3000, monotone = FALSE)
  welfare_of <- function(pr, x) { pr$reset(); xs <- pmax(x, sv_floor); s <- pr$inner(xs / sum(xs)); lw <- pr$sp$vartheta * s$log_u
    exp((max(lw) + log(sum(exp(lw - max(lw))))) / pr$sp$vartheta) }
  # the model's own solver along the path
  kappas <- c(0.02, 0.04, 0.06, 0.08, 0.1, 0.12, 0.15, 0.2, 0.25, 0.3)
  direct <- bind_rows(parallel::mclapply(kappas, function(k) {
    d <- tryCatch(mf_solve(mk(k), max_iter = 8000), error = function(e) NULL)
    tibble(kappa = k, direct_converged = !is.null(d) && d$converged)
  }, mc.cores = sv_cores))
  s0 <- mf_solve(mk(0)); x0 <- s0$Ls / sum(s0$Ls)
  path <- sv_continuation(mk, kappas, x0, lambda = 0.05, tol = 1e-8, max_iter = 3000)
  cont <- bind_rows(lapply(path, function(p) tibble(kappa = p$value, continuation_converged = !is.null(p$found),
                                                    iterations = if (is.null(p$found)) NA else p$found$iterations,
                                                    welfare = if (is.null(p$found)) NA else welfare_of(p$pr, p$found$x))))
  multi <- list(); eqs <- list()
  for (k in c(0.1, 0.2, 0.3)) {
    pth <- Filter(function(p) abs(p$value - k) < 1e-9, path)[[1]]
    pr <- pth$pr; xc <- pth$found$x
    set.seed(7); starts <- lapply(1:8, function(i) { y <- as.vector(xc) * exp(rnorm(length(xc), 0, 1.5)); matrix(y / sum(y), N, S) })
    fs <- parallel::mclapply(starts, function(s) { f <- hc(pr, s); if (!is.null(f)) f$method <- 'hill climb'; f }, mc.cores = sv_cores)
    found <- c(list(c(pth$found, list(method = 'continuation'))), fs)
    set.seed(11)
    cl <- sv_cluster(found, pr, eigen = FALSE, tries = 3, lambda = 0.05, tol = 1e-8, max_iter = 3000, monotone = FALSE) %>%
      mutate(welfare = vapply(x, function(xx) welfare_of(pr, xx), 0),
             max_share_gap = vapply(x, function(xx) max(abs(as.vector(xx) - as.vector(xc))), 0),
             biggest_move = vapply(x, function(xx) { d <- xx - xc; i <- which.max(abs(d)); r <- (i - 1) %% N + 1; c <- (i - 1) %/% N + 1
               sprintf('place %d, %s: %+.3f', r, cal$sectors[c], d[i]) }, ''))
    multi[[as.character(k)]] <- cl %>% mutate(kappa = k, starts = length(starts), converged = sum(!vapply(fs, is.null, TRUE)))
    eqs[[as.character(k)]] <- list(pr = pr, x = cl$x)
  }
  # policies from each equilibrium at kappa = 0.3
  frontier <- cal$limit == 'Tradable frontier'
  upstream <- cal$sectors %in% c('wholesale_motor', 'transport', 'admin_support', 'utilities', 'construction')
  local_g <- cal$sectors %in% c('retail', 'hospitality', 'arts_personal')
  prox <- list()
  a1 <- a0; for (g in which(frontier)) { top <- order(a0[, g], decreasing = TRUE)[1:2]; a1[top, g] <- a1[top, g] * 1.10 }; prox[['P1 frontier push']] <- a1
  a1 <- a0; for (g in seq_len(S)) { m <- median(a0[, g]); lo <- a0[, g] < m; a1[lo, g] <- a0[lo, g] + 0.5 * (m - a0[lo, g]) }; prox[['P2 long tail']] <- a1
  a1 <- a0; a1[, upstream] <- a1[, upstream] * 1.05; prox[['P3 upstream']] <- a1
  a1 <- a0; a1[, local_g] <- a1[, local_g] * 1.05; prox[['P4 local services']] <- a1
  e3 <- eqs[['0.3']]
  tasks <- expand_grid(eq = seq_along(e3$x), proxy = names(prox))
  pol <- bind_rows(parallel::mclapply(seq_len(nrow(tasks)), function(i) {
    x_eq <- e3$x[[tasks$eq[i]]]; a1 <- prox[[tasks$proxy[i]]]
    pr1 <- sv_problem(mk(0.3, a1)); f <- hc(pr1, x_eq)
    if (is.null(f)) return(tibble(eq = tasks$eq[i], proxy = tasks$proxy[i], converged = FALSE))
    tibble(eq = tasks$eq[i], proxy = tasks$proxy[i], converged = TRUE,
           d_welfare = log(welfare_of(pr1, f$x)) - log(welfare_of(e3$pr, x_eq)),
           points = sum(x_eq * log(a1 / a0)), moved = max(abs(as.vector(f$x) - as.vector(x_eq))))
  }, mc.cores = sv_cores)) %>%
    group_by(eq) %>% mutate(gain_per_point = d_welfare / points,
                            breakeven = gain_per_point / gain_per_point[proxy == 'P1 frontier push']) %>% ungroup()
  list(direct = direct, continuation = cont, multi = bind_rows(multi) %>% mutate(x = NULL), policies = pol)
}, depends = c(sv_deps, file.path(tj_cache_dir, 'modelF_local_sigma.rds')))

tj_write(sv_full$direct %>% left_join(sv_full$continuation, by = 'kappa'), 'solvers_full_path.csv')
tj_write(sv_full$multi, 'solvers_full_equilibria.csv')
tj_write(sv_full$policies, 'solvers_full_policies.csv')
