# Model F (round 2, test T1): the Rice and Venables (2023) engine with supply chains.
#
# N places, S sectors. As Model C/D (functions_rv2023.R), plus intermediate inputs:
#   unit cost   p_is = w_is^gL_s r_i^gT_s prod_k P_ik^G[k,s] / a_is        (fixed-price inputs, at price 1, take
#               the rest of the cost: capital gC_s and imports, taxes and inputs from the held-fixed sectors gM_s)
#   price index P_js^(1-sigma) = p_js^(1-sigma) + tau_s sum_{i != j} p_is^(1-sigma)   (Armington, trade cost t_s)
#   spending    E_js = beta_s M_j + sum_k G[s,k] rev_jk        (households, and other sectors' inputs, both
#               bought at the same local price index, so intermediates face the same trade costs)
#   demand      x_is = p_is^-sigma [ (1 - tau_s) E_is / P_is^(1-sigma) + tau_s sum_j E_js / P_js^(1-sigma) ]
#               + exports phi_s (q p_is)^-sigma tau_s     (phi_s scales the rest of the world's demand by sector)
#   labour      L_is = gL_s rev_is / w_is;  land  r_i^(1+eta) = alpha M_i + sum_s gT_s rev_is
#   trade       exports pay for households' imports (beta0 M) and all fixed-price inputs. Two closures:
#               q_fixed = NULL (Rice and Venables): the import price is fixed at 1 and the foreign-demand
#               shifter q balances trade at every step. That leaves the domestic price level against the
#               import price undetermined (labour demand is homogeneous of degree zero in it), so a gain in
#               exporters can't show up as cheaper imports. q_fixed = a number: foreign demand is fixed, the
#               domestic wage and price level against world prices is set by equilibrium, and trade balances
#               by Walras's law (mf_solve reports the gap). Model F's experiments use q_fixed.
#   income      y_is = w_is + land rent (shared nationally, or to local residents); utility as in (3)
#   mobility    Frechet across place-sectors (vartheta), or immobile between places (workers choose a sector)
# With G = 0, gC = gM = 0 and gT = 1 - gL this is Model C/D.

mf_spec <- function(N, S, a, t_s, gL, gT, G, gC = rep(0, S), gM = rep(0, S), sigma = 10, eta = 1, alpha = 0.25,
                    beta0 = 0.1875, beta_s = NULL, vartheta = 50, mobility = c('frechet', 'immobile'),
                    rent = c('national', 'local'), L = N, L_i = NULL, kappa = 0, exports = TRUE, sectors = NULL,
                    phi = rep(1, S), q_fixed = NULL) {
  mobility <- match.arg(mobility); rent <- match.arg(rent)
  if (is.null(beta_s)) beta_s <- rep((1 - alpha - beta0) / S, S)
  G <- as.matrix(G)
  stopifnot(length(t_s) == S, all(dim(a) == c(N, S)), all(dim(G) == c(S, S)),
            abs(alpha + beta0 + sum(beta_s) - 1) < 1e-9,
            max(abs(gL + gT + colSums(G) + gC + gM - 1)) < 1e-9, all(colSums(G) < 1))
  if (mobility == 'immobile' && is.null(L_i)) L_i <- rep(L / N, N)
  list(N = N, S = S, a = a, t_s = t_s, tau = t_s^(1 - sigma), gL = gL, gT = gT, G = G, gC = gC, gM = gM,
       sigma = sigma, eta = eta, alpha = alpha, beta0 = beta0, beta_s = beta_s, vartheta = vartheta,
       mobility = mobility, rent = rent, L = L, L_i = L_i, kappa = kappa, exports = exports, sectors = sectors, phi = phi,
       q_fixed = q_fixed)
}

# Evaluate at given wages. Prices solve their own fixed point (each sector's cost depends on the local
# price indices of its inputs); spending and revenues solve theirs (each sector's sales depend on other
# sectors' purchases); then rents, incomes and labour supply move by damped passes, as in rv_evaluate().
mf_evaluate <- function(w, state, sp, passes = 8) {
  N <- sp$N; S <- sp$S; sig <- sp$sigma
  tau_m <- matrix(sp$tau, N, S, byrow = TRUE); beta_m <- matrix(sp$beta_s, N, S, byrow = TRUE)
  gL_m <- matrix(sp$gL, N, S, byrow = TRUE); gT_m <- matrix(sp$gT, N, S, byrow = TRUE)
  phi_m <- matrix(sp$phi, N, S, byrow = TRUE)
  fixed_share <- sp$gC + sp$gM
  r <- state$r; M <- state$M; rebate <- state$rebate; Ls <- state$Ls; lp <- state$log_p; rev <- state$rev
  mu <- 1 / (1 + sp$vartheta * sp$alpha / (1 + sp$eta))
  for (k in seq_len(passes)) {
    a_eff <- if (sp$kappa > 0) sp$a * (pmax(Ls, 1e-12) / matrix(colMeans(Ls), N, S, byrow = TRUE))^sp$kappa else sp$a
    base <- gL_m * log(w) + gT_m * log(r) - log(a_eff)
    for (j in 1:60) {                                       # prices: a contraction, since inputs < 100% of cost
      pp <- exp((1 - sig) * lp)
      P1 <- (1 - tau_m) * pp + tau_m * matrix(colSums(pp), N, S, byrow = TRUE)
      logP <- log(P1) / (1 - sig)
      lp_new <- base + logP %*% sp$G
      d <- max(abs(lp_new - lp)); lp <- lp_new
      if (d < 1e-12) break
    }
    p <- exp(lp); pp <- p^(1 - sig)
    P1 <- (1 - tau_m) * pp + tau_m * matrix(colSums(pp), N, S, byrow = TRUE)
    logP <- log(P1) / (1 - sig)
    q <- NA_real_
    for (j in 1:200) {                                      # spending and revenues
      E <- beta_m * M + rev %*% t(sp$G)
      EP <- E / P1
      dom <- p^(-sig) * ((1 - tau_m) * EP + tau_m * matrix(colSums(EP), N, S, byrow = TRUE))
      if (sp$exports) {
        if (is.null(sp$q_fixed)) {
          imports <- sp$beta0 * sum(M) + sum(rev %*% fixed_share)
          q <- (sum(phi_m * tau_m * pp) / imports)^(1 / sig)
        } else q <- sp$q_fixed
        ex <- (q * p)^(-sig) * tau_m * phi_m
      } else ex <- 0
      rev_new <- p * (dom + ex)
      d <- max(abs(log(rev_new) - log(rev))); rev <- rev_new
      if (d < 1e-11) break
    }
    r_target <- (sp$alpha * M + rowSums(gT_m * rev))^(1 / (1 + sp$eta))
    r <- r^(1 - mu) * r_target^mu
    rent_val <- r^(1 + sp$eta)
    log_e <- sp$alpha * log(r) + as.vector(logP %*% sp$beta_s)
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
    Ls <- if (sp$rent == 'local') exp((1 - mu) * log(Ls) + mu * log_Ls) else exp(log_Ls)
    M <- M^(1 - mu) * rowSums(y * Ls)^mu
  }
  Ld <- gL_m * rev / w
  list(p = p, log_p = lp, P = exp(logP), logP = logP, E = E, x = dom + ex, ex = ex, rev = rev, Ld = Ld, Ls = Ls,
       log_Ls = log_Ls, r = r, M = M, rebate = rebate, y = y, q = q, log_u = log_u, log_e = log_e, a_eff = a_eff)
}

mf_solve <- function(sp, start = NULL, damp = 0.7, tol = 1e-8, max_iter = 4000, verbose = FALSE) {
  N <- sp$N; S <- sp$S
  E_s <- rv_elasticity(sp$t_s, sp$sigma, N)$E
  el_m <- matrix(1 + sp$gL * (E_s - 1), N, S, byrow = TRUE)
  w <- if (is.null(start)) matrix(1, N, S) else start$w
  state <- if (is.null(start)) {
    Ls0 <- if (sp$mobility == 'frechet') matrix(sp$L / (N * S), N, S) else matrix(sp$L_i / S, N, S)
    list(r = rep(1, N), M = rowSums(Ls0), rebate = 0, Ls = Ls0, log_p = matrix(0, N, S),
         rev = matrix(sum(Ls0) / (N * S * mean(sp$gL)), N, S))
  } else start[c('r', 'M', 'rebate', 'Ls', 'log_p', 'rev')]
  for (it in seq_len(max_iter)) {
    ev <- mf_evaluate(w, state, sp)
    state <- ev[c('r', 'M', 'rebate', 'Ls', 'log_p', 'rev')]
    gap <- log(ev$Ld) - ev$log_Ls
    err <- max(abs(gap))
    if (verbose && it %% 100 == 0) message('iter ', it, ' max log gap ', signif(err, 3))
    if (!is.finite(err)) stop('mf_solve diverged at iteration ', it)
    if (err < tol) break
    slope <- el_m + sp$vartheta * w / ev$y * pmax(1 - sp$kappa * (el_m - 1) / mean(sp$gL), 0.05)
    w <- w * exp(pmax(pmin(damp * gap / slope, 0.2), -0.2))
  }
  ev$w <- w; ev$iterations <- it; ev$max_gap <- err
  ev$income_gap <- max(abs(log(ev$M) - log(rowSums(ev$y * ev$Ls))))
  ev$converged <- err < tol && ev$income_gap < 1e-6
  ev$trade_gap <- if (sp$exports) (sum(ev$p * ev$ex) - sp$beta0 * sum(ev$M) - sum(ev$rev %*% (sp$gC + sp$gM))) / sum(ev$M) else 0
  ev
}

# Outcomes of a solution. The lenses (plan T8):
#   real    real income per resident: utility (income over the local cost of living), and for the nation the
#           Frechet welfare index (sum u^vartheta)^(1/vartheta), which counts the value of choice
#   official workplace GVA per worker, nominal: wages, land rent paid by firms and capital costs, over jobs
# Land: rent income, and its share of residents' income.
mf_outcomes <- function(sol, sp) {
  L_i <- rowSums(sol$Ls)
  inputs <- colSums(sp$G) + sp$gM
  gva <- sol$rev * matrix(1 - inputs, sp$N, sp$S, byrow = TRUE)
  rent_val <- sol$r^(1 + sp$eta)
  u <- exp(sol$log_u)
  lw <- sp$vartheta * sol$log_u
  places <- tibble(place = seq_len(sp$N), L = L_i, u = rowSums(u * sol$Ls) / L_i,
                   y = rowSums(sol$y * sol$Ls) / L_i, w = rowSums(sol$w * sol$Ls) / L_i,
                   gva_per_worker = rowSums(gva) / L_i, rent = rent_val, r = sol$r,
                   cost_of_living = exp(rowSums(sol$log_e * sol$Ls) / L_i))
  national <- tibble(
    welfare = if (sp$mobility == 'frechet') exp((max(lw) + log(sum(exp(lw - max(lw))))) / sp$vartheta) else NA_real_,
    welfare_immobile = if (sp$mobility == 'immobile')
      exp(sum(sp$L_i * apply(lw, 1, function(z) (max(z) + log(sum(exp(z - max(z))))) / sp$vartheta)) / sum(sp$L_i)) else NA_real_,
    u_mean = sum(u * sol$Ls) / sum(sol$Ls), gva_per_worker = sum(gva) / sum(sol$Ls), gdp = sum(gva),
    rent_total = sum(rent_val), wage_bill = sum(sol$w * sol$Ls), q = sol$q,
    cv_gva_per_worker = sd(places$gva_per_worker) / mean(places$gva_per_worker), cv_u = sd(places$u) / mean(places$u))
  list(places = places, national = national, emp = sol$Ls, gva = gva)
}

# Calibrate Model F from T2's sector groups (outputs/t2_groups.csv, t2_group_coefficients.csv).
#   sectors   the 17 market groups: the providential group is held fixed (its inputs to market sectors
#             count as fixed-price inputs, its demand is left out), real estate becomes the model's land
#             (firms' purchases of it are land costs), imputed rent and households as employers are left out
#   G[k, s]   domestic inputs from group k per £ of group s's output
#   gL        compensation of employees / output
#   gT        the local fixed factor ("land and buildings"): theta_land x (GVA - compensation) / output,
#             plus purchases from real estate. Default theta_land = 1, as in Rice and Venables, whose only
#             factors are labour and land: all non-labour value added is a local factor owned by residents,
#             and its supply elasticity eta decides how far it behaves like land (low) or capital (high)
#   gC        the rest of non-labour value added, if theta_land < 1: capital rented abroad at a fixed price
#   gM        the rest: imported inputs, taxes on products, inputs from the held-fixed and left-out groups
#   beta_s    households' spending shares: each group's domestic final demand (households, government,
#             investment), scaled to 1 - alpha - beta0
#   t_s       by market reach: export share 20%+ -> t_trade, households 50%+ of sales -> t_local, otherwise t_b2b
mf_calibrate <- function(groups, coefs, theta_land = 1, t_trade = 1.3, t_b2b = 1.5, t_local = 2.0,
                         alpha = 0.25, beta0 = 0.1875) {
  held <- c('public_providential', 'excluded', 'real_estate')
  sec <- groups %>% filter(!group %in% held) %>% arrange(match(group, io_group_labels$group))
  ids <- sec$group
  cf <- coefs %>% filter(from %in% c(ids, 'real_estate'), to %in% ids)
  G <- matrix(0, length(ids), length(ids), dimnames = list(ids, ids))
  x <- cf %>% filter(from %in% ids)
  G[cbind(x$from, x$to)] <- x$domestic
  cost <- coefs %>% distinct(to, compensation, gva) %>% filter(to %in% ids)
  cost <- cost[match(ids, cost$to), ]
  re <- cf %>% filter(from == 'real_estate')
  re_share <- re$domestic[match(ids, re$to)]
  nonlab <- cost$gva - cost$compensation
  stopifnot(all(nonlab > 0))
  gL <- cost$compensation; gT <- theta_land * nonlab + re_share; gC <- (1 - theta_land) * nonlab
  gM <- 1 - gL - gT - gC - colSums(G)
  stopifnot(all(gM >= 0))
  fd <- sec$fd_households + sec$fd_government + sec$fd_investment
  beta_s <- (1 - alpha - beta0) * fd / sum(fd)
  t_s <- ifelse(sec$export_share >= 0.2, t_trade, ifelse(sec$household_share >= 0.5, t_local, t_b2b))
  list(sectors = ids, names = sec$group_name, limit = sec$limit, foundational = sec$foundational,
       G = G, gL = gL, gT = gT, gC = gC, gM = gM, beta_s = beta_s, t_s = t_s, alpha = alpha, beta0 = beta0,
       export_share = sec$export_share, b2b_share = sec$b2b_share, household_share = sec$household_share,
       output = sec$output, domar = sec$domar, domar_net = sec$domar_net, employees = sec$employees)
}

# A spec from a calibration, N places and productivities a (N x S). supply_chains = FALSE moves the domestic
# input shares into fixed-price inputs: the same cost shares, but no links between sectors at home.
mf_from_cal <- function(cal, a, supply_chains = TRUE, ...) {
  S <- length(cal$sectors)
  G <- if (supply_chains) cal$G else matrix(0, S, S)
  gM <- if (supply_chains) cal$gM else cal$gM + colSums(cal$G)
  mf_spec(nrow(a), S, a, cal$t_s, gL = cal$gL, gT = cal$gT, G = G, gC = cal$gC, gM = gM, alpha = cal$alpha,
          beta0 = cal$beta0, beta_s = cal$beta_s, sectors = cal$sectors, ...)
}

# Rest-of-world demand scales phi_s, so that in a run with equal productivity everywhere each sector's share
# of exports matches the input-output tables. (The level of exports is set by the trade balance.)
mf_calibrate_exports <- function(cal, N, iters = 30, tol = 1e-6, ...) {
  S <- length(cal$sectors); a1 <- matrix(1, N, S)
  target <- cal$export_share * cal$output / sum(cal$export_share * cal$output)
  phi <- rep(1, S); st <- NULL
  for (k in seq_len(iters)) {
    sp <- mf_from_cal(cal, a1, phi = phi, ...)
    so <- mf_solve(sp, start = st); st <- so
    sh <- colSums(so$p * so$ex) / sum(so$p * so$ex)
    if (max(abs(log(sh / target))) < tol) break
    phi <- phi * (target / sh)
  }
  list(phi = phi, solution = so, spec = sp, iterations = k, max_log_gap = max(abs(log(sh / target))))
}
