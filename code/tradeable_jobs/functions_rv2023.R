# Model C: Rice and Venables (2023), and Model D: the same engine with switches for the Ricardian
# benchmarks of the plan (part 3, step 1).
#
# N places, S sectors. Place-sector productivity a_is (Ricardian), Armington varieties by place with
# elasticity sigma, sector trade cost t_s (tradability tau_s = t_s^(1 - sigma)), Cobb-Douglas costs with
# labour share gamma, land supply K = r^eta, upper-level Cobb-Douglas spending (land alpha, imports beta0,
# sectors beta_s). Equation numbers are the paper's:
#   (1) p_is   = w_is^gamma r_i^(1 - gamma) / a_is
#   (2) P_js^(1-sigma) = p_js^(1-sigma) + tau_s sum_{i != j} p_is^(1-sigma)
#   (5) x_is   = p_is^-sigma beta_s sum_j M_j tau_ijs P_js^(sigma-1) + (q p_is)^-sigma tau_s
#   (6) L_is   = gamma p_is x_is / w_is
#   (7) r_i    = [alpha M_i + (1 - gamma) sum_s p_is x_is]^(1 / (1 + eta))
#   (8) y_is   = w_is + sum_i r_i^(1 + eta) / L         (rent = 'national'; 'local' gives it to residents)
#   (3) u_is   = y_is / (r_i^alpha p0^beta0 prod_s P_is^beta_s)
#   (9) pi_is  = u_is^vartheta / sum u^vartheta,  labour supply pi_is L     (mobility = 'frechet')
#   (4) the exchange rate q balances trade. The paper writes export value as sum tau_s (q p_is)^(1-sigma);
#       the value in domestic currency of the export demand in (5) is q^-sigma sum tau_s p_is^(1-sigma),
#       which is what is used here (plan 2.4 item 12).
# Switches (Model D):
#   mobility = 'frechet' (paper), 'immobile' (fixed L_i; workers choose sector within their place),
#   rent = 'national' or 'local', exports on/off (off when beta0 = 0), agglomeration kappa:
#   effective productivity a_is (L_is / Lbar_s)^kappa, firms taking it as given.

rv_spec <- function(N, S, t_s, a, sigma = 10, eta = 1, alpha = 0.25, beta0 = 0.1875, beta_s = NULL,
                    gamma = 0.9, vartheta = 50, mobility = c('frechet', 'immobile'), rent = c('national', 'local'),
                    L = N, L_i = NULL, kappa = 0) {
  mobility <- match.arg(mobility); rent <- match.arg(rent)
  if (is.null(beta_s)) beta_s <- rep((1 - alpha - beta0) / S, S)
  stopifnot(length(t_s) == S, all(dim(a) == c(N, S)), abs(alpha + beta0 + sum(beta_s) - 1) < 1e-9)
  if (mobility == 'immobile' && is.null(L_i)) L_i <- rep(L / N, N)
  list(N = N, S = S, t_s = t_s, tau = t_s^(1 - sigma), a = a, sigma = sigma, eta = eta, alpha = alpha,
       beta0 = beta0, beta_s = beta_s, gamma = gamma, vartheta = vartheta, mobility = mobility, rent = rent,
       L = L, L_i = L_i, kappa = kappa)
}

# Evaluate the model at given wages. Labour supply is the one the current wages imply (eq. 9), with rents,
# incomes and the rent rebate brought into line with it by damped passes (more people raise rents, which
# raises the cost of living and pushes people away: a strong negative feedback when vartheta is large,
# hence the damping). state carries r, M, rebate and Ls between calls as warm starts.
rv_evaluate <- function(w, state, sp, passes = 8) {
  N <- sp$N; S <- sp$S; sig <- sp$sigma
  tau_m <- matrix(sp$tau, N, S, byrow = TRUE); beta_m <- matrix(sp$beta_s, N, S, byrow = TRUE)
  r <- state$r; M <- state$M; rebate <- state$rebate; Ls <- state$Ls
  mu <- 1 / (1 + sp$vartheta * sp$alpha / (1 + sp$eta))
  for (k in seq_len(passes)) {
    a_eff <- if (sp$kappa > 0) sp$a * (pmax(Ls, 1e-12) / matrix(colMeans(Ls), N, S, byrow = TRUE))^sp$kappa else sp$a
    p  <- w^sp$gamma * r^(1 - sp$gamma) / a_eff
    pp <- p^(1 - sig)
    P1 <- (1 - tau_m) * pp + tau_m * matrix(colSums(pp), N, S, byrow = TRUE)     # P_js^(1 - sigma)
    MP <- M / P1                                                                  # M_j P_js^(sigma - 1)
    dom <- p^(-sig) * beta_m * ((1 - tau_m) * MP + tau_m * matrix(colSums(MP), N, S, byrow = TRUE))
    if (sp$beta0 > 0) {
      q <- (sum(tau_m * pp) / (sp$beta0 * sum(M)))^(1 / sig)                     # trade balance
      ex <- (q * p)^(-sig) * tau_m
    } else { q <- NA_real_; ex <- 0 }
    x <- dom + ex
    rev <- p * x
    r_target <- (sp$alpha * M + (1 - sp$gamma) * rowSums(rev))^(1 / (1 + sp$eta))
    r <- r^(1 - mu) * r_target^mu
    rent_val <- r^(1 + sp$eta)
    P <- P1^(1 / (1 - sig))
    log_e <- sp$alpha * log(r) + as.vector(log(P) %*% sp$beta_s)                  # p0 = 1
    if (sp$rent == 'national') { rebate <- sum(rent_val) / sp$L; y <- w + rebate
    } else y <- w + rent_val / pmax(rowSums(Ls), 1e-12)
    log_u <- log(y) - log_e
    lu <- sp$vartheta * log_u
    log_Ls <- if (sp$mobility == 'frechet') {
      log(sp$L) + lu - (max(lu) + log(sum(exp(lu - max(lu)))))
    } else {
      mx <- apply(lu, 1, max)
      log(sp$L_i) + lu - (mx + log(rowSums(exp(lu - mx))))
    }
    # With rent paid to local residents, rent per resident depends on the population itself (and is huge
    # wherever the population is briefly tiny), so the population follows its target gradually
    Ls <- if (sp$rent == 'local') exp((1 - mu) * log(Ls) + mu * log_Ls) else exp(log_Ls)
    M <- M^(1 - mu) * rowSums(y * Ls)^mu
  }
  Ld <- sp$gamma * rev / w
  list(p = p, P = P, x = x, ex = ex, rev = rev, Ld = Ld, Ls = Ls, log_Ls = log_Ls, r = r, M = M,
       rebate = rebate, y = y, q = q, log_u = log_u, a_eff = a_eff)
}

# Solve: wages move with log excess demand (log Ld - log Ls), divided by the slope of excess demand in
# log w: the demand elasticity (about 1 + gamma (E_s - 1), eq. 11) plus the supply response
# vartheta * w / y. Rents and incomes are re-solved each step inside rv_evaluate.
rv_solve <- function(sp, start = NULL, damp = 0.7, tol = 1e-8, max_iter = 5000, verbose = FALSE) {
  N <- sp$N; S <- sp$S
  el_m <- matrix(1 + sp$gamma * (rv_elasticity(sp$t_s, sp$sigma, N)$E - 1), N, S, byrow = TRUE)
  w <- if (is.null(start)) matrix(1, N, S) else start$w
  state <- if (is.null(start)) {
    Ls0 <- if (sp$mobility == 'frechet') matrix(sp$L / (N * S), N, S) else matrix(sp$L_i / S, N, S)
    list(r = rep(1, N), M = rowSums(Ls0), rebate = 0, Ls = Ls0)
  } else start[c('r', 'M', 'rebate', 'Ls')]
  for (it in seq_len(max_iter)) {
    ev <- rv_evaluate(w, state, sp)
    state <- ev[c('r', 'M', 'rebate', 'Ls')]
    gap <- log(ev$Ld) - ev$log_Ls
    err <- max(abs(gap))
    if (verbose && it %% 100 == 0) message('iter ', it, ' max log gap ', signif(err, 3))
    if (!is.finite(err)) stop('rv_solve diverged at iteration ', it)
    if (err < tol) break
    # With agglomeration, more workers raise productivity, cut the price and raise demand, so labour
    # demand rises with supply at rate about kappa (E_s - 1): the supply response is offset by that much
    slope <- el_m + sp$vartheta * w / ev$y * pmax(1 - sp$kappa * (el_m - 1) / sp$gamma, 0.05)
    w <- w * exp(pmax(pmin(damp * gap / slope, 0.2), -0.2))
  }
  ev$w <- w; ev$iterations <- it; ev$max_gap <- err
  # final consistency of incomes and rents with the supply
  ev$income_gap <- max(abs(log(ev$M) - log(rowSums(ev$y * ev$Ls))))
  ev$converged <- err < tol && ev$income_gap < 1e-6
  # Walras check: exports should equal imports (beta0 * total income)
  ev$trade_gap <- if (sp$beta0 > 0) (sum(ev$p * ev$ex) - sp$beta0 * sum(ev$M)) / sum(ev$M) else 0
  ev
}

# Place summaries: employment, employment-weighted wage, rent, utility, sectoral concentration
rv_places <- function(sol) {
  L_i <- rowSums(sol$Ls)
  tibble(place = seq_along(L_i), L = L_i, w = rowSums(sol$w * sol$Ls) / L_i, r = sol$r,
         u = rowSums(exp(sol$log_u) * sol$Ls) / L_i,
         cv_sector_emp = apply(sol$Ls, 1, function(z) sd(z) / mean(z)))
}

# Sector sparsity (plan 2.2): for each sector, the SD and skewness across places of q_is = s_is - x_i,
# where s_is is the place's share of sector employment and x_i its share of all employment. Sparsity
# bias of a place: employment-share weighted mean of the sector measures.
rv_sparsity <- function(emp) {
  s <- sweep(emp, 2, colSums(emp), '/')
  x <- rowSums(emp) / sum(emp)
  qd <- s - x
  SD <- apply(qd, 2, sd); SK <- apply(qd, 2, tj_skew)
  lam <- emp / rowSums(emp)
  list(SD = SD, SK = SK, SB_SD = as.vector(lam %*% SD), SB_SK = as.vector(lam %*% SK))
}

# Demand elasticity by tradability, eq. (11)
rv_elasticity <- function(t_s, sigma, N) {
  tau <- t_s^(1 - sigma); mu <- 1 / (1 + (N - 1) * tau)
  tibble(t_s = t_s, tau = tau, mu = mu, E = sigma - (sigma - 1) * mu * (mu + (1 - mu) * tau))
}

# Comparative statics, eq. (13): proportional wage change in one place for small productivity changes
rv_wage_response <- function(a_hat, t_s, sigma, N, alpha, eta, beta_s) {
  el <- rv_elasticity(t_s, sigma, N)
  psi <- alpha / (1 + eta) * (el$E - 1) / sum(beta_s * (1 - el$mu)) - el$mu
  sum(beta_s * a_hat * psi) / (1 + sum(beta_s * psi))
}

# Draw Ricardian productivities a_is = 1 + normal(0, sd) / scale_s, truncated to [0.5, 1.5] by redrawing.
# scale_s = t_s gives the paper's Table 2a columns 3-4 (smaller shocks in more tradable... sectors with
# lower trade costs get the larger shocks, since t_s is smallest there)
rv_draw_a <- function(N, S, sd, scale_by = rep(1, S)) {
  sc <- matrix(scale_by, N, S, byrow = TRUE)
  z <- matrix(rnorm(N * S, 0, sd), N, S) / sc
  bad <- abs(z) > 0.5
  while (any(bad)) { z[bad] <- rnorm(sum(bad), 0, sd) / sc[bad]; bad <- abs(z) > 0.5 }
  1 + z
}
