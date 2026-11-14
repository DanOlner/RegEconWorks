# Model C: Rice and Venables (2023) section 3.1 and 3.2.
#   - the demand elasticities and home-market shares in Table 1 (eq. 11)
#   - Table 1: 100 places, 9 sectors, place i has a 50% productivity advantage in sector i (i = 1..9),
#     perfect mobility (approximated by vartheta = 1000; utilities then differ by under 0.1%), no external
#     trade, labour the only input. The paper's footnote gives alpha = beta_s = 0.25, which can't sum to
#     one with nine sectors; the central reading here is alpha = 0.25 with the other 0.75 split equally.
#     Rows below vary that reading, the land elasticity and mobility, since none matches every number.
#   - eq. (13), the comparative statics, against finite differences of the full model

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_rv2023.R')
rv_deps <- c('code/tradeable_jobs/functions_rv2023.R', 'code/tradeable_jobs/06_rv2023_table1.R')

rv_t1_N <- 100; rv_t1_S <- 9; rv_t1_t <- seq(1, 3, length.out = rv_t1_S)
rv_t1_a <- matrix(1, rv_t1_N, rv_t1_S); for (s in 1:rv_t1_S) rv_t1_a[s, s] <- 1.5

rv_elasticity_check <- rv_elasticity(rv_t1_t[c(1, 5, 9)], sigma = 10, N = rv_t1_N) %>%
  mutate(sector = c(1, 5, 9), paper_mu = c(0.01, 0.84, 0.99), paper_E = c(9.9, 3.7, 1.1), .before = 1)

rv_table1 <- tj_cached('rv_table1', {
  variants <- tribble(
    ~variant,                                   ~alpha, ~beta,  ~eta, ~vartheta,
    'Central reading (alpha 0.25, eta 1)',       0.25, 0.75/9,  1,    1000,
    'Land elasticity 2',                         0.25, 0.75/9,  2,    1000,
    'Land elasticity 0.5',                       0.25, 0.75/9,  0.5,  1000,
    'alpha = beta_s = 0.1',                      0.10, 0.10,    1,    1000,
    'Imperfect mobility (vartheta 50)',          0.25, 0.75/9,  1,      50)
  bind_rows(lapply(seq_len(nrow(variants)), function(k) {
    v <- variants[k, ]
    sp <- rv_spec(rv_t1_N, rv_t1_S, t_s = rv_t1_t, a = rv_t1_a, beta0 = 0, alpha = v$alpha,
                  beta_s = rep(v$beta, rv_t1_S), gamma = 1, eta = v$eta, vartheta = v$vartheta)
    sol <- rv_solve(sp, max_iter = 20000)
    pl <- rv_places(sol); rest <- pl %>% filter(place > 9)
    bind_rows(lapply(c(1, 5, 9), function(i) tibble(
      variant = v$variant, place = i,
      wage = pl$w[i] / mean(rest$w), rent = pl$r[i] / mean(rest$r), employment = pl$L[i] / mean(rest$L),
      utility = pl$u[i] / mean(rest$u), cv_sector_emp = pl$cv_sector_emp[i],
      own_sector_share = sol$Ls[i, i] / sum(sol$Ls[i, ]), converged = sol$converged)))
  }))
}, depends = rv_deps)

rv_table1_paper <- tibble(variant = 'Reported in RV2023 Table 1', place = c(1, 5, 9),
                          wage = c(1.17, 1.06, 0.98), rent = c(1.40, 1.27, 1.12), employment = c(1.74, 1.55, 1.26),
                          utility = 1, cv_sector_emp = c(0.39, 0.26, 0.03), own_sector_share = c(0.5, NA, NA))

# Eq. (13) against finite differences: raise productivity by 1% in one sector of place 1, from the
# symmetric base, and compare the change in place 1's wage relative to the rest
rv_comparative_statics <- tj_cached('rv_comparative_statics', {
  base_a <- matrix(1, rv_t1_N, rv_t1_S)
  mk <- function(a) rv_spec(rv_t1_N, rv_t1_S, t_s = rv_t1_t, a = a, beta0 = 0, alpha = 0.25,
                            beta_s = rep(0.75 / 9, rv_t1_S), gamma = 1, eta = 1, vartheta = 1000)
  base <- rv_solve(mk(base_a), tol = 1e-11)
  bind_rows(lapply(c(1, 5, 9), function(s) {
    a <- base_a; a[1, s] <- 1.01
    sol <- rv_solve(mk(a), start = base, tol = 1e-11)
    pl <- rv_places(sol)
    a_hat <- rep(0, rv_t1_S); a_hat[s] <- log(1.01)
    tibble(sector = s, t_s = rv_t1_t[s],
           finite_difference = log(pl$w[1] / mean(pl$w[-1])) / log(1.01),
           eq13 = rv_wage_response(a_hat, rv_t1_t, 10, rv_t1_N, 0.25, 1, rep(0.75 / 9, rv_t1_S)) / log(1.01))
  }))
}, depends = rv_deps)

tj_write(rv_elasticity_check, 'rv2023_elasticities.csv')
tj_write(bind_rows(rv_table1_paper, rv_table1), 'rv2023_table1.csv')
tj_write(rv_comparative_statics, 'rv2023_comparative_statics.csv')
print(rv_elasticity_check)
print(as.data.frame(bind_rows(rv_table1_paper, rv_table1) %>% mutate(across(where(is.numeric), ~ round(.x, 3)))))
print(rv_comparative_statics)
