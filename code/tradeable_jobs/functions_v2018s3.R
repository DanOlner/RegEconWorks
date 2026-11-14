# Model B: Venables (2018) section 3. Two tradable sectors (A, B) with localisation economies, one
# non-tradable sector (N), two factors: L (less skilled) and K (skilled). Cities specialise: type A, B
# or N, with counts M_A, M_B, M_N = M - M_A - M_B. Equation numbers are the paper's.
#   (6) x_i = q_i(x_i) X_i(L_i, K_i), X_i = L_i^lambda_i K_i^(1 - lambda_i), q_T(x) = 1 + 0.1 x, q_N = 1
#   (7) w_i = p_i q_i dX_i/dL_i, r_i = p_i q_i dX_i/dK_i   (firms take q as given)
#   (8) M_N p_N x_N (1 - theta_N) = theta_N (M_A p_A x_A + M_B p_B x_B)
#       P = p_N^theta_N p_A^theta_A p_B^theta_B
#   (9) w_i / P - b (L_i + K_i) and r_i / P - b (L_i + K_i) equal across city types (mobility)
#   (10) sum_i M_i L_i = L, sum_i M_i K_i = K
#   real rent per city R_i = b (L_i + K_i)^2 / 2
#   (12) no lone firm gains by starting another sector: p_j <= c_j(J) / q_j(0) for every city type J != j,
#        with c_j(J) the Cobb-Douglas unit cost of sector j at city J's factor prices
# Parameters (appendix): L = K = 50, M = 100, theta = 1/3 each, b = 0.25, lambda_A = 0.25,
# lambda_N = 0.5, lambda_B = 0.75, q(x) = 1 + 0.1 x, p_A = p_B = 1 at the start.

mb_params <- function(L = 50, K = 50, M = 100, theta = c(N = 1/3, A = 1/3, B = 1/3), b = 0.25,
                      lambda = c(A = 0.25, B = 0.75, N = 0.5), q_slope = 0.1, p = c(A = 1, B = 1)) {
  list(L = L, K = K, M = M, theta = theta, b = b, lambda = lambda, q_slope = q_slope, p = p)
}

mb_unit_cost <- function(lambda, w, r) (w / lambda)^lambda * (r / (1 - lambda))^(1 - lambda)

# A city of a given type with inputs Lc, Kc
mb_city <- function(type, Lc, Kc, pN, par) {
  lam <- par$lambda[[type]]
  X <- Lc^lam * Kc^(1 - lam)
  if (type == 'N') { x <- X; price <- pN } else {
    if (par$q_slope * X >= 1) return(NULL)
    x <- X / (1 - par$q_slope * X); price <- par$p[[type]]
  }
  q <- x / X
  list(x = x, q = q, price = price, w = price * q * lam * X / Lc, r = price * q * (1 - lam) * X / Kc)
}

# Plain Newton-Raphson with a numerical Jacobian and step halving
mb_newton <- function(f, z, tol = 1e-11, max_iter = 200) {
  fz <- f(z)
  for (it in seq_len(max_iter)) {
    if (all(is.finite(fz)) && max(abs(fz)) < tol) break
    h <- 1e-7
    J <- vapply(seq_along(z), function(k) { zz <- z; zz[k] <- zz[k] + h; (f(zz) - fz) / h }, numeric(length(z)))
    dz <- tryCatch(solve(J, -fz), error = function(e) NULL)
    if (is.null(dz)) break
    step <- 1
    repeat {
      zn <- z + step * dz; fn <- f(zn)
      if (all(is.finite(fn)) && sum(fn^2) < sum(fz^2)) break
      step <- step / 2
      if (step < 1e-10) break
    }
    if (step < 1e-10) break
    z <- zn; fz <- fn
  }
  list(z = z, f = fz, converged = all(is.finite(fz)) && max(abs(fz)) < tol * 100)
}

# Solve for given counts c(A =, B =, N =). Unknowns: log L_i, log K_i for each type present, log p_N,
# and the two common utilities.
mb_solve <- function(counts, par, start = NULL) {
  types <- c('A', 'B', 'N')[c(counts[['A']], counts[['B']], counts[['N']]) > 1e-9]
  nt <- length(types)
  unpack <- function(z) list(L = setNames(exp(z[1:nt]), types), K = setNames(exp(z[nt + 1:nt]), types),
                             pN = exp(z[2 * nt + 1]), uL = z[2 * nt + 2], uK = z[2 * nt + 3])
  P_of <- function(pN) pN^par$theta[['N']] * par$p[['A']]^par$theta[['A']] * par$p[['B']]^par$theta[['B']]
  resid <- function(z) {
    v <- unpack(z); P <- P_of(v$pN)
    out <- numeric(0); val <- c(A = 0, B = 0, N = 0)
    for (ty in types) {
      cty <- mb_city(ty, v$L[[ty]], v$K[[ty]], v$pN, par)
      if (is.null(cty)) return(rep(NA_real_, length(z)))
      size <- v$L[[ty]] + v$K[[ty]]
      out <- c(out, cty$w / P - par$b * size - v$uL, cty$r / P - par$b * size - v$uK)
      val[[ty]] <- cty$price * cty$x
    }
    c(out,
      (sum(counts[types] * v$L) - par$L) / par$L,
      (sum(counts[types] * v$K) - par$K) / par$K,
      log(counts[['N']] * val[['N']] * (1 - par$theta[['N']])) -
        log(par$theta[['N']] * (counts[['A']] * val[['A']] + counts[['B']] * val[['B']])))
  }
  z0 <- if (!is.null(start) && identical(start$types, types)) start$z else
    c(log(rep(par$L / par$M, nt)), log(rep(par$K / par$M, nt)), 0, 0.5, 0.5)
  sol <- mb_newton(resid, z0)
  if (!sol$converged) return(NULL)
  v <- unpack(sol$z); P <- P_of(v$pN)
  cities <- bind_rows(lapply(types, function(ty) {
    cty <- mb_city(ty, v$L[[ty]], v$K[[ty]], v$pN, par)
    tibble(type = ty, count = counts[[ty]], L = v$L[[ty]], K = v$K[[ty]], w = cty$w, r = cty$r,
           x = cty$x, q = cty$q, R = par$b * (v$L[[ty]] + v$K[[ty]])^2 / 2)
  }))
  U <- sum(cities$count * (cities$L * v$uL + cities$K * v$uK + cities$R))
  list(counts = counts, types = types, z = sol$z, pN = v$pN, P = P, uL = v$uL, uK = v$uK, cities = cities,
       U_total = U, rent_total = sum(cities$count * cities$R))
}

# Gains to a lone firm of sector j in a city of type J (positive = the deviation pays), eq. (12)
mb_entry_gaps <- function(sol, par) {
  price <- c(A = par$p[['A']], B = par$p[['B']], N = sol$pN)
  expand_grid(city = sol$types, sector = c('A', 'B', 'N')) %>% filter(city != sector) %>%
    rowwise() %>%
    mutate(gap = price[[sector]] - mb_unit_cost(par$lambda[[sector]], sol$cities$w[sol$cities$type == city],
                                               sol$cities$r[sol$cities$type == city])) %>%
    ungroup()
}

# Move to an equilibrium by switching cities whose factor prices make another sector profitable,
# as in Model A's cm_adjust (Venables 2018 section 3.3: the equilibrium is "dragged" by the boundary)
mb_adjust <- function(counts, par, start = NULL, tol = 1e-9, max_moves = 40) {
  moves <- tibble()
  sol <- mb_solve(counts, par, start)
  for (iter in seq_len(max_moves)) {
    if (is.null(sol)) stop('Model B: no solution at ', paste(round(counts, 3), collapse = ' '))
    g <- mb_entry_gaps(sol, par) %>% filter(gap > tol) %>% arrange(desc(gap))
    if (!nrow(g)) return(c(sol, list(moves = moves)))
    from <- g$city[1]; to <- g$sector[1]
    gap_after <- function(x) {
      cc <- counts; cc[from] <- cc[from] - x; cc[to] <- cc[to] + x
      if (cc[[from]] < 1e-9) return(-1)
      s <- mb_solve(cc, par, sol); if (is.null(s)) return(NA_real_)
      gg <- mb_entry_gaps(s, par); gg$gap[gg$city == from & gg$sector == to]
    }
    xs <- seq(0, counts[[from]], length.out = 81)[-1]
    gx <- vapply(xs, gap_after, numeric(1))
    j <- which(!is.na(gx) & gx <= 0)[1]
    x <- if (is.na(j)) counts[[from]] else
      uniroot(function(x) { v <- gap_after(x); if (is.na(v)) -1 else v },
              c(if (j == 1) 0 else xs[j - 1], xs[j]), tol = 1e-10)$root
    counts[from] <- counts[from] - x; counts[to] <- counts[to] + x
    counts[counts < 1e-7] <- 0
    moves <- bind_rows(moves, tibble(from = from, to = to, cities = x))
    sol <- mb_solve(counts, par, sol)
  }
  stop('mb_adjust did not settle')
}

# The point without coordination failure: factor prices equal in every city type (so every sector is
# equally profitable everywhere). Solve for (M_A, M_B).
mb_no_coordination_failure <- function(par, guess = c(33.33, 33.33)) {
  f <- function(m) {
    s <- mb_solve(c(A = m[1], B = m[2], N = par$M - m[1] - m[2]), par)
    if (is.null(s)) return(c(NA, NA))
    cw <- setNames(s$cities$w, s$cities$type); cr <- setNames(s$cities$r, s$cities$type)
    c(log(cw[['A']] / cw[['N']]), log(cr[['B']] / cr[['N']]))
  }
  sol <- mb_newton(f, guess, tol = 1e-10)
  if (!sol$converged) return(NULL)
  sol$z
}
