# Equilibrium search for Model F (and so the Rice and Venables engine, its special case) when there may be
# several equilibria: with agglomeration, productivity in a place-sector rises with its employment, so
# where people and firms are depends on where they already are.
#
# The model's own solver (mf_solve) adjusts wages from one start and finds at most one equilibrium. Here the
# problem is split in two:
#   inner  given the allocation of workers to place-sectors x (shares, summing to 1), solve wages, prices and
#          rents with labour fixed (mf_spec(mobility = 'fixed')). With labour fixed, agglomeration is just
#          a given productivity, so this is well behaved however strong agglomeration is.
#   outer  the allocation workers would choose given the utilities u(x) that result: F(x) = softmax(vartheta
#          log u(x)), Frechet mobility as in the model. Equilibria are the fixed points x = F(x).
# Three ways to find the fixed points:
#   hill climbing    damped best-response ("move towards higher utility") dynamics,
#                    log x <- (1 - lambda) log x + lambda log F(x), from many random starts. Finds stable
#                    equilibria, the ones an economy would settle into.
#   residual search  minimise |log F(x) - log x|^2 over allocations from many random starts (Nelder-Mead),
#                    then polish with Newton's method. Finds unstable equilibria too.
#   brute force      evaluate the residual on a grid over every allocation (small problems only), and polish
#                    every grid point that is a local minimum. Misses nothing finer than the grid.
# Corners. With agglomeration of the form a (L / mean L)^kappa, productivity goes to zero as a place-sector
# empties, so strong agglomeration gives equilibria with complete specialisation: some shares are exactly
# zero, approached only in the limit (each round of best responses makes a small share smaller still). So
# convergence is judged in shares (levels), shares are floored at sv_floor (a cell at the floor is empty),
# and stability is tested by perturbing an equilibrium and checking that the hill climb comes back.
# Interior equilibria also get the eigenvalue test on d(log x)/dt = log F(x) - log x.
# Needs functions_modelF.R (and functions_rv2023.R).

# Allocation <-> unconstrained coordinates: z are log shares relative to the last cell (N*S - 1 numbers)
sv_x_of_z <- function(z, N, S) { e <- exp(c(z, 0) - max(c(z, 0))); matrix(e / sum(e), N, S) }
sv_z_of_x <- function(x) { lx <- log(as.vector(x)); head(lx - lx[length(lx)], -1) }

# The inner solve and the outer map, with a warm-start cache so repeated evaluations near each other are quick
sv_problem <- function(sp) {
  stopifnot(sp$mobility == 'frechet')
  N <- sp$N; S <- sp$S; L <- sp$L
  last <- NULL
  inner <- function(x) {
    spf <- sp; spf$mobility <- 'fixed'; spf$L_fixed <- x * L
    s <- tryCatch(mf_solve(spf, start = last, max_iter = 6000), error = function(e) NULL)
    if (is.null(s) || !s$converged) s <- tryCatch(mf_solve(spf, max_iter = 20000), error = function(e) NULL)
    if (!is.null(s) && s$converged) last <<- s
    s
  }
  # log F(x) - log x, as a vector over cells; NA if the inner problem can't be solved
  resid <- function(x) {
    s <- inner(x); if (is.null(s) || !s$converged) return(rep(NA_real_, N * S))
    lu <- sp$vartheta * as.vector(s$log_u)
    lF <- lu - (max(lu) + log(sum(exp(lu - max(lu)))))
    lF - log(as.vector(x))
  }
  Fmap <- function(x) {                                    # the allocation workers would choose, in shares
    s <- inner(x); if (is.null(s) || !s$converged) return(NULL)
    lu <- sp$vartheta * as.vector(s$log_u)
    matrix(exp(lu - (max(lu) + log(sum(exp(lu - max(lu)))))), N, S)
  }
  list(N = N, S = S, sp = sp, inner = inner, resid = resid, Fmap = Fmap,
       g = function(z) { r <- resid(sv_x_of_z(z, N, S)); r - r[length(r)] },        # in z coordinates
       reset = function() last <<- NULL)
}

sv_newton <- function(g, z, tol = 1e-10, max_iter = 60) {
  gz <- g(z)
  for (it in seq_len(max_iter)) {
    if (anyNA(gz)) return(NULL)
    if (max(abs(gz)) < tol) return(list(z = z, err = max(abs(gz)), iterations = it))
    J <- vapply(seq_along(z), function(k) { zz <- z; zz[k] <- zz[k] + 1e-6; (g(zz)[-length(gz)] - gz[-length(gz)]) / 1e-6 }, numeric(length(z)))
    dz <- tryCatch(solve(J, -gz[-length(gz)]), error = function(e) NULL)
    if (is.null(dz)) return(NULL)
    step <- 1
    repeat {
      zn <- z + step * dz; gn <- g(zn)
      if (!anyNA(gn) && max(abs(gn)) < max(abs(gz))) break
      step <- step / 2; if (step < 1e-6) return(NULL)
    }
    z <- zn; gz <- gn
  }
  if (max(abs(gz)) < tol * 100) list(z = z, err = max(abs(gz)), iterations = max_iter) else NULL
}

# Stability: eigenvalues of the Jacobian of d z/dt = g(z) at a fixed point; stable if all real parts < 0
sv_stability <- function(pr, z) {
  g0 <- pr$g(z)[-length(z) - 1]
  J <- vapply(seq_along(z), function(k) { zz <- z; zz[k] <- zz[k] + 1e-6; (pr$g(zz)[-length(z) - 1] - g0) / 1e-6 }, numeric(length(z)))
  ev <- eigen(J, only.values = TRUE)$values
  list(max_real = max(Re(ev)), stable = max(Re(ev)) < 0)
}

sv_floor <- 1e-14

# Hill climbing on best responses, in log shares with a floor, judged in shares. The step adapts: it halves
# (and the move is undone) when the gap |F(x) - x| grows, and creeps back up after improvements. With high
# mobility the best-response map is steep, and a fixed step overshoots.
# monotone = FALSE: a fixed small step with no shrink test (for large problems with high mobility, where
# moving towards better choices need not shrink the gap at every step); it stops if the gap blows up.
sv_hill_climb <- function(pr, x0, lambda = 0.2, tol = 1e-10, max_iter = 4000, min_lambda = 1e-6, monotone = TRUE) {
  norm_of <- function(x, Fx) max(abs(Fx - x))
  x <- pmax(as.vector(x0), sv_floor); x <- x / sum(x)
  Fx <- pr$Fmap(matrix(x, pr$N, pr$S)); if (is.null(Fx)) return(NULL); Fx <- pmax(as.vector(Fx), sv_floor)
  start_norm <- norm_of(x, Fx)
  for (it in seq_len(max_iter)) {
    if (norm_of(x, Fx) < tol) return(list(x = matrix(x, pr$N, pr$S), err = norm_of(x, Fx), iterations = it))
    xn <- exp((1 - lambda) * log(x) + lambda * log(Fx)); xn <- pmax(xn, sv_floor); xn <- xn / sum(xn)
    Fn <- pr$Fmap(matrix(xn, pr$N, pr$S))
    if (monotone) {
      if (is.null(Fn) || norm_of(xn, pmax(as.vector(Fn), sv_floor)) > norm_of(x, Fx)) {
        lambda <- lambda / 2; if (lambda < min_lambda) return(NULL); next
      }
      lambda <- min(lambda * 1.1, 0.5)
    } else if (is.null(Fn) || norm_of(xn, pmax(as.vector(Fn), sv_floor)) > 100 * max(start_norm, 1e-3)) return(NULL)
    x <- xn; Fx <- pmax(as.vector(Fn), sv_floor)
  }
  NULL
}

# Continuation: solve along a path of a parameter (e.g. agglomeration kappa), each step starting from the
# previous step's equilibrium. make_spec(value) returns a Frechet-mobility spec. Returns, for each value, the
# equilibrium found (or NULL) and the problem object.
sv_continuation <- function(make_spec, values, x0, lambda = 0.02, tol = 1e-8, max_iter = 3000) {
  x <- x0; out <- list()
  for (v in values) {
    pr <- sv_problem(make_spec(v))
    f <- sv_hill_climb(pr, x, lambda = lambda, tol = tol, max_iter = max_iter, monotone = FALSE)
    out[[length(out) + 1]] <- list(value = v, found = f, pr = pr)
    if (is.null(f)) break
    x <- f$x
  }
  out
}

sv_residual_search <- function(pr, z0, maxit = 400) {
  obj <- function(z) { gz <- pr$g(z); if (anyNA(gz)) 1e6 else sum(gz^2) }
  o <- optim(z0, obj, method = 'Nelder-Mead', control = list(maxit = maxit, reltol = 1e-12))
  f <- sv_newton(pr$g, o$par)
  if (is.null(f)) NULL else c(f, list(x = sv_x_of_z(f$z, pr$N, pr$S)))
}

# Random allocations: Dirichlet draws, spread from near-corners to near-even
sv_random_x <- function(N, S, n, conc = c(0.3, 1, 3)) {
  lapply(seq_len(n), function(i) { a <- conc[(i - 1) %% length(conc) + 1]; g <- rgamma(N * S, a) + 1e-6; matrix(g / sum(g), N, S) })
}

# Is equilibrium x stable? Perturb it (move a share `size` of workers at random, several times) and see
# whether the hill climb comes back to it. Interior equilibria also get the eigenvalue test.
sv_stable <- function(pr, x, size = 0.01, tries = 4, return_tol = 1e-3, eigen = TRUE, ...) {
  back <- vapply(seq_len(tries), function(k) {
    xp <- as.vector(x) * exp(size * 10 * rnorm(length(x))) + size * runif(length(x)) / length(x)
    f <- sv_hill_climb(pr, matrix(xp / sum(xp), pr$N, pr$S), ...)
    !is.null(f) && max(abs(as.vector(f$x) - as.vector(x))) < return_tol
  }, TRUE)
  interior <- all(x > 1e-6)
  eig <- if (interior && eigen) tryCatch(sv_stability(pr, sv_z_of_x(x))$max_real, error = function(e) NA_real_) else NA_real_
  list(stable = all(back), returned = mean(back), max_real_eigen = eig, interior = interior)
}

# merge_tol: equilibria closer than this in every share are the same. ... goes to the hill climb in the
# stability test (its own tol, lambda and so on), so it must not use the name merge_tol.
sv_cluster <- function(found, pr, merge_tol = 1e-3, eigen = TRUE, ...) {
  found <- Filter(Negate(is.null), found)
  if (!length(found)) return(tibble(equilibrium = integer(), methods = character(), hits = numeric(), stable = logical(),
                                    interior = logical(), max_real_eigen = numeric(), welfare = numeric(),
                                    gva_per_worker = numeric(), x = list()))
  keep <- list()
  for (f in found) {
    x <- f$x
    dup <- vapply(keep, function(k) max(abs(as.vector(k$x) - as.vector(x))) < merge_tol, TRUE)
    if (length(dup) && any(dup)) { i <- which(dup)[1]; keep[[i]]$hits <- keep[[i]]$hits + 1
      keep[[i]]$methods <- union(keep[[i]]$methods, f$method)
    } else keep[[length(keep) + 1]] <- list(x = x, hits = 1, methods = f$method)
  }
  bind_rows(lapply(seq_along(keep), function(i) {
    k <- keep[[i]]; st <- sv_stable(pr, k$x, eigen = eigen, ...)
    # outcomes from a fresh start: a warm start from an unrelated allocation can land on a different price
    # level, which shifts every utility by the same factor (so it doesn't affect where workers go, only
    # welfare levels)
    xs <- pmax(as.vector(k$x), sv_floor); xs <- matrix(xs / sum(xs), pr$N, pr$S)
    pr$reset(); s <- pr$inner(xs); sp_out <- pr$sp; sp_out$mobility <- 'fixed'; sp_out$L_fixed <- xs * pr$sp$L
    o <- mf_outcomes(s, sp_out)
    lw <- pr$sp$vartheta * s$log_u
    tibble(equilibrium = i, methods = paste(sort(k$methods), collapse = ', '), hits = k$hits, stable = st$stable,
           interior = st$interior, max_real_eigen = st$max_real_eigen,
           welfare = exp((max(lw) + log(sum(exp(lw - max(lw))))) / pr$sp$vartheta),
           gva_per_worker = o$national$gva_per_worker, x = list(k$x))
  }))
}

# Brute force: the residual |log F(x) - log x| at every point of a grid over allocations (each share a multiple
# of 1/steps, none below `floor`), then Newton's method from every grid point that is a local minimum
# (no lower neighbour: moving one grid step of share between any two cells). Small problems only: the grid
# has choose(steps + N*S - 1, N*S - 1) points.
sv_brute_force <- function(pr, steps = 20, floor = 0.005) {
  K <- pr$N * pr$S
  comps <- function(n, k) if (k == 1) matrix(n, 1, 1) else do.call(rbind, lapply(0:n, function(i) cbind(i, comps(n - i, k - 1))))
  grid <- comps(steps, K) / steps
  grid <- pmax(grid, floor); grid <- grid / rowSums(grid)
  norm <- vapply(seq_len(nrow(grid)), function(i) { Fx <- pr$Fmap(matrix(grid[i, ], pr$N, pr$S)); if (is.null(Fx)) NA_real_ else max(abs(as.vector(Fx) - grid[i, ])) }, 0)
  key <- apply(round(grid * steps), 1, paste, collapse = ',')
  idx <- setNames(seq_len(nrow(grid)), key)
  is_min <- vapply(seq_len(nrow(grid)), function(i) {
    if (is.na(norm[i])) return(FALSE)
    g <- round(grid[i, ] * steps)
    for (a in seq_len(K)) for (b in seq_len(K)) if (a != b && g[a] > 0) {
      h <- g; h[a] <- h[a] - 1; h[b] <- h[b] + 1
      j <- idx[paste(h, collapse = ',')]
      if (!is.na(j) && !is.na(norm[j]) && norm[j] < norm[i]) return(FALSE)
    }
    TRUE
  }, TRUE)
  starts <- which(is_min)
  # polish each local minimum both ways: Newton (finds unstable interior equilibria) and the hill climb
  # (follows a stable one, including into a corner)
  found <- unlist(lapply(starts, function(i) {
    x0 <- matrix(grid[i, ], pr$N, pr$S)
    fn <- sv_newton(pr$g, sv_z_of_x(x0)); if (!is.null(fn)) fn <- c(fn, list(x = sv_x_of_z(fn$z, pr$N, pr$S), method = 'brute force'))
    fh <- sv_hill_climb(pr, x0); if (!is.null(fh)) fh$method <- 'brute force'
    list(fn, fh)
  }), recursive = FALSE)
  list(found = found, grid_points = nrow(grid), local_minima = length(starts), norm = norm)
}
