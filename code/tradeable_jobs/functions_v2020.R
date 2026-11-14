# Model A: the one-factor city model of Venables (2020) and Venables (2018) section 2, written generally
# enough to run the ablations in the plan (step 4).
#
# Cities come in "types". Each type makes one sector: a tradable at a fixed world price p_k, or the
# non-tradable, sold on one national market at endogenous price pN. Productivity is q_k(L), with q_k(0) = 1;
# in the papers tradables have q(L) = 1 + 0.15 L and non-tradables q = 1. All cities of a type are
# identical. Wages are w_k = p_k q_k(L_k).
#
# Equations, for given counts of each type (Venables 2020 numbering):
#   (2) full employment       sum_k M_k L_k = L                    (perfect mobility)
#       or immobile labour    L_k = L / M for every city
#   (3) non-tradables market  sum_{k in N} M_k L_k w_k = theta (Y - Tax) + G P,   Y = sum_k M_k L_k w_k
#       G is real net government spending on non-tradables. financing = 'external' (the paper: no tax,
#       so G < 0 is a surplus sent abroad) or 'balanced' (lump-sum tax Tax = G P on all workers)
#   (4) price index           P = pN^theta prod_T p_k^theta_k,  theta_k sum to 1 - theta
#   (5) mobility              w_k - b P L_k = v for every type (perfect mobility only)
# Utility u_k = (w_k - b P L_k - Tax / L) / P; real rent per city R_k = b L_k^2 / 2 (linear city).
#
# Equilibrium needs, beyond (2)-(5), that no single small firm gains by starting another sector in a
# city of another type: p_j q_j(0) <= w_k for every type k and sector j != k (Venables 2018 eq. 12 in
# one-factor form). cm_entry_gaps() reports p_j q_j(0) - w_k; a positive gap is a profitable deviation.

cm_type <- function(kind = c('T', 'N'), p = 1, slope = if (kind[1] == 'T') 0.15 else 0, q = NULL, theta_k = NA) {
  kind <- match.arg(kind)
  linear <- is.null(q)
  if (linear) q <- local({ s <- slope; function(L) 1 + s * L })
  list(kind = kind, p = if (kind == 'N') NA_real_ else p, slope = if (linear) slope else NA_real_,
       q = q, linear = linear, theta_k = theta_k)
}

cm_spec <- function(L = 100, M = 100, theta = 0.5, b = 0.3, G = 0,
                    financing = c('external', 'balanced'), mobility = c('perfect', 'immobile'),
                    types = list(T = cm_type('T'), N = cm_type('N'))) {
  financing <- match.arg(financing); mobility <- match.arg(mobility)
  tradables <- names(types)[vapply(types, function(t) t$kind == 'T', logical(1))]
  share <- vapply(types[tradables], function(t) t$theta_k, numeric(1))
  share[is.na(share)] <- (1 - theta - sum(share, na.rm = TRUE)) / sum(is.na(share))
  for (k in tradables) types[[k]]$theta_k <- share[[k]]
  list(L = L, M = M, theta = theta, b = b, G = G, financing = financing, mobility = mobility, types = types)
}

cm_price_index <- function(pN, spec) {
  P <- pN^spec$theta
  for (t in spec$types) if (t$kind == 'T') P <- P * t$p^t$theta_k
  P
}

# City sizes given the national non-tradable price (and hence P). Returns NULL if no valid allocation.
cm_sizes <- function(pN, counts, spec) {
  P <- cm_price_index(pN, spec)
  active <- names(counts)[counts > 0]
  ty <- spec$types[active]
  p  <- vapply(ty, function(t) if (t$kind == 'N') pN else t$p, numeric(1))
  if (spec$mobility == 'immobile') {
    Lk <- setNames(rep(spec$L / spec$M, length(active)), active)
    return(list(P = P, L = Lk, p = p, v = NA_real_))
  }
  bP <- spec$b * P
  if (all(vapply(ty, `[[`, logical(1), 'linear'))) {
    d <- bP - p * vapply(ty, `[[`, numeric(1), 'slope')       # stability needs d > 0 (Venables 2018 fn 10)
    if (any(d <= 0)) return(NULL)
    m <- counts[active]
    v <- (sum(m * p / d) - spec$L) / sum(m / d)
    Lk <- (p - v) / d
  } else {
    size_at <- function(k, v) {
      f <- function(Lc) p[[k]] * ty[[k]]$q(Lc) - bP * Lc - v
      if (f(0) <= 0) return(0)
      hi <- spec$L; if (f(hi) > 0) return(NA_real_)
      uniroot(f, c(0, hi), tol = 1e-12)$root
    }
    total <- function(v) sum(vapply(active, function(k) counts[[k]] * size_at(k, v), numeric(1))) - spec$L
    v_top <- min(p) - 1e-12
    lo <- v_top - 1; while (is.finite(total(lo)) && total(lo) < 0 && lo > -1e3) lo <- lo - 10
    tl <- total(lo); if (!is.finite(tl) || tl < 0) return(NULL)
    tt <- total(v_top); if (!is.finite(tt) || tt > 0) return(NULL)  # no v gives every type a positive size
    v <- uniroot(total, c(lo, v_top), tol = 1e-12)$root
    Lk <- vapply(active, function(k) size_at(k, v), numeric(1))
  }
  if (any(!is.finite(Lk)) || any(Lk <= 0)) return(NULL)
  list(P = P, L = setNames(Lk, active), p = p, v = v)
}

cm_excess_N <- function(pN, counts, spec) {
  s <- cm_sizes(pN, counts, spec)
  if (is.null(s)) return(NA_real_)
  active <- names(s$L)
  w <- vapply(active, function(k) s$p[[k]] * spec$types[[k]]$q(s$L[[k]]), numeric(1))
  m <- counts[active]
  Y <- sum(m * s$L * w)
  Gn <- spec$G * s$P
  tax <- if (spec$financing == 'balanced') Gn else 0
  isN <- vapply(spec$types[active], function(t) t$kind == 'N', logical(1))
  sum((m * s$L * w)[isN]) - (spec$theta * (Y - tax) + Gn)
}

# Solve for given counts (named, matching names(spec$types), summing to M). Returns NULL if no solution
# or more than one (flagged rather than picked).
cm_solve <- function(counts, spec, pN_grid = exp(seq(log(0.05), log(20), length.out = 601))) {
  counts <- counts[names(spec$types)]; counts[is.na(counts)] <- 0
  if (abs(sum(counts) - spec$M) > 1e-8 || any(counts < 0)) stop('counts must be non-negative and sum to M')
  if (sum(counts[vapply(spec$types, function(t) t$kind == 'N', logical(1))]) <= 0) return(NULL)
  ex <- vapply(pN_grid, cm_excess_N, numeric(1), counts = counts, spec = spec)
  i <- which(!is.na(ex[-1]) & !is.na(ex[-length(ex)]) & ex[-1] * ex[-length(ex)] <= 0)
  if (length(i) > 1) i <- i[c(TRUE, diff(i) > 1)]  # a root exactly on a grid point shows up twice
  if (length(i) != 1) return(NULL)
  pN <- if (ex[i] == 0) pN_grid[i] else if (ex[i + 1] == 0) pN_grid[i + 1] else
    uniroot(cm_excess_N, pN_grid[c(i, i + 1)], counts = counts, spec = spec, tol = 1e-13)$root
  s <- cm_sizes(pN, counts, spec)
  active <- names(s$L)
  tax_pw <- if (spec$financing == 'balanced') spec$G * s$P / spec$L else 0
  cities <- tibble(
    type  = active,
    kind  = vapply(spec$types[active], `[[`, character(1), 'kind'),
    count = unname(counts[active]),
    L     = unname(s$L),
    p     = unname(s$p),
    w     = unname(vapply(active, function(k) s$p[[k]] * spec$types[[k]]$q(s$L[[k]]), numeric(1)))
  ) %>%
    mutate(u = (w - spec$b * s$P * L - tax_pw) / s$P,   # utility, in units of the composite good
           R = spec$b * L^2 / 2,                         # real rent per city
           r_pc = R / L)                                 # real rent per resident
  Y <- sum(cities$count * cities$L * cities$w)
  list(counts = counts, pN = pN, P = s$P, cities = cities,
       totals = tibble(Y_nominal = Y, rent_real = sum(cities$count * cities$R),
                       util_real = sum(cities$count * cities$L * cities$u),
                       U = (sum(cities$count * cities$L * cities$u) + sum(cities$count * cities$R)) / spec$L,
                       rent_share = s$P * sum(cities$count * cities$R) / Y,
                       popshare_N = sum((cities$count * cities$L)[cities$kind == 'N']) / spec$L))
}

# Gains to a lone firm starting sector j in a city of type k: p_j q_j(0) - w_k (positive = deviation pays)
cm_entry_gaps <- function(sol, spec) {
  sectors <- names(spec$types)
  price0 <- vapply(sectors, function(j) (if (spec$types[[j]]$kind == 'N') sol$pN else spec$types[[j]]$p) *
                     spec$types[[j]]$q(0), numeric(1))
  expand_grid(city = sol$cities$type, sector = sectors) %>%
    filter(city != sector) %>%
    mutate(gap = unname(price0[sector]) - sol$cities$w[match(city, sol$cities$type)])
}

# Move the economy to an equilibrium: while some lone firm would gain by switching sector in a city of
# another type, switch cities from that type to that sector until the gain is zero. This is the "dragged
# by the boundary" adjustment in Venables (2018) section 3.3. Returns the solution plus the moves made.
cm_adjust <- function(counts, spec, tol = 1e-9, max_moves = 20) {
  moves <- tibble()
  for (iter in seq_len(max_moves)) {
    sol <- cm_solve(counts, spec)
    if (is.null(sol)) stop('no solution at counts ', paste(names(counts), round(counts, 3), collapse = ' '))
    g <- cm_entry_gaps(sol, spec) %>% filter(gap > tol) %>% arrange(desc(gap))
    if (!nrow(g)) return(c(sol, list(moves = moves)))
    from <- g$city[1]; to <- g$sector[1]
    gap_after <- function(x) {
      cc <- counts; cc[from] <- cc[from] - x; cc[to] <- cc[to] + x
      if (cc[[from]] < 1e-9) return(-1)  # every city of this type has switched: nothing left to gain
      s <- cm_solve(cc, spec); if (is.null(s)) return(NA_real_)
      g <- cm_entry_gaps(s, spec)
      g$gap[g$city == from & g$sector == to]
    }
    hi <- counts[[from]]
    xs <- seq(0, hi, length.out = 41)[-1]
    gx <- vapply(xs, gap_after, numeric(1))
    j <- which(!is.na(gx) & gx <= 0)[1]
    x <- if (is.na(j)) hi * (1 - 1e-9) else
      uniroot(function(x) { v <- gap_after(x); if (is.na(v)) -1 else v }, c(if (j == 1) 0 else xs[j - 1], xs[j]), tol = 1e-10)$root
    counts[from] <- counts[from] - x; counts[to] <- counts[to] + x
    counts[counts < 1e-7] <- 0                     # a type that has switched out entirely is gone
    counts <- counts * spec$M / sum(counts)
    # If the gain rose as cities switched (gx increasing), every city of the type switched: with
    # increasing returns, one city's switch makes the next one's more attractive (a cascade)
    moves <- bind_rows(moves, tibble(from = from, to = to, cities = x, cascade = is.na(j)))
  }
  stop('cm_adjust did not settle')
}

# Edges of the equilibrium set with one tradable type T and the non-tradable type N:
#   E (Tmin): pT q(0) = wN, a lone tradable firm in a type-N city just breaks even
#   X (Tmax): pN = wT, a lone non-tradable firm in a type-T city just breaks even
cm_bounds <- function(spec, grid = seq(0.5, spec$M - 0.5, by = 0.5)) {
  gaps <- function(MT) {
    s <- cm_solve(c(T = MT, N = spec$M - MT), spec)
    if (is.null(s)) return(c(E = NA, X = NA))
    g <- cm_entry_gaps(s, spec)
    c(E = g$gap[g$city == 'N' & g$sector == 'T'], X = g$gap[g$city == 'T' & g$sector == 'N'])
  }
  root_of <- function(which) {
    f <- function(MT) unname(gaps(MT)[which])
    v <- vapply(grid, f, numeric(1))
    i <- which(!is.na(v[-1]) & !is.na(v[-length(v)]) & v[-1] * v[-length(v)] <= 0)[1]
    if (is.na(i)) return(NA_real_)
    if (v[i] == 0) return(grid[i]); if (v[i + 1] == 0) return(grid[i + 1])
    uniroot(f, grid[c(i, i + 1)], tol = 1e-10)$root
  }
  c(E = root_of('E'), X = root_of('X'))
}

# Curves over a grid of MT (Venables 2020 Fig. 1; Venables 2018 Figs 1-3)
cm_curves <- function(spec, MT = seq(10, 90, by = 0.5)) {
  bind_rows(lapply(MT, function(m) {
    s <- cm_solve(c(T = m, N = spec$M - m), spec)
    if (is.null(s)) return(NULL)
    cT <- s$cities[s$cities$type == 'T', ]; cN <- s$cities[s$cities$type == 'N', ]
    tibble(MT = m, share_T = m / spec$M, wT = cT$w, wN = cN$w, wTN = spec$types$T$p * spec$types$T$q(0),
           LT = cT$L, LN = cN$L, RT = cT$R, RN = cN$R, u = cN$u, P = s$P,
           U = s$totals$U, rent_per_worker = s$totals$rent_real / spec$L, rent_share = s$totals$rent_share)
  }))
}
