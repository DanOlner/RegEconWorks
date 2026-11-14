# T7 (Model A part): supply chains in Venables's city model. Tradable cities buy gamma units of the
# non-tradable per unit of output, from the national non-tradable market (functions_v2020.R, input_N).
# Questions:
#   1. Does buying from the non-tradable sector move the equilibrium range [E, X] of tradable-city shares,
#      and so the lock-in Venables describes (economies stuck with too few tradable cities)?
#   2. With gamma > 0, does higher productivity in the non-tradable sector (cheaper inputs for tradables)
#      widen the range of tradable shares that can be sustained, i.e. is it a "lever" for lagging places?
# Base parameters as round 1 (cm_spec(): 100 cities, L = 100, theta 0.5, b 0.3, slope 0.15).

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_v2020.R')

ma <- tj_cached('modelA_supply_chains', {
  spec_g <- function(gamma, qN = 1) cm_spec(types = list(T = cm_type('T', slope = 0.15, input_N = gamma),
                                                          N = cm_type('N', q = local({ v <- qN; function(L) v + 0 * L }))))
  one <- function(gamma, qN) {
    sp <- spec_g(gamma, qN)
    b <- cm_bounds(sp)
    mid <- if (all(is.finite(b))) mean(b) else 50
    s <- cm_solve(c(T = mid, N = sp$M - mid), sp)
    tibble(gamma = gamma, qN = qN, E = b[['E']] / sp$M, X = b[['X']] / sp$M, width = (b[['X']] - b[['E']]) / sp$M,
           pN_mid = if (is.null(s)) NA else s$pN, U_mid = if (is.null(s)) NA else s$totals$U,
           wT_mid = if (is.null(s)) NA else s$cities$w[s$cities$type == 'T'],
           wN_mid = if (is.null(s)) NA else s$cities$w[s$cities$type == 'N'])
  }
  bind_rows(lapply(c(0, 0.1, 0.2, 0.3), function(g) bind_rows(lapply(c(1, 1.05, 1.1), function(q) one(g, q)))))
}, depends = c('code/tradeable_jobs/functions_v2020.R', 'code/tradeable_jobs/25_modelA_supply_chains.R'))

tj_write(ma, 'modelA_supply_chains.csv')
