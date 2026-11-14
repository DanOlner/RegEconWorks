# Model C: Rice and Venables (2023) section 3.3, Table 2a. 300 places, 50 sectors, trade costs from 1
# to 4, sigma 10, land elasticity 1, Frechet shape 50, labour share 0.9, imports 0.1875 of spending.
# Productivity a_is = 1 + N(0, 0.2) truncated at +/- 0.5 (columns 1-2), or the shock divided by t_s
# (columns 3-4). The text says "variance 0.2"; sd 0.2 is what reproduces the paper's correlations and
# wage range (checked in the plan's log), so sd 0.2 is used. 20 runs per case, as in the paper.
# Sparsity bias (eq. 14) is regressed on place average wages. Coefficients depend on units the paper
# doesn't state, so the comparison is on R^2, t-statistics, wage range and the sector correlations.

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_rv2023.R')
rv_deps <- c('code/tradeable_jobs/functions_rv2023.R', 'code/tradeable_jobs/07_rv2023_simulations.R')

rv_sim_N <- 300; rv_sim_S <- 50; rv_sim_t <- seq(1, 4, length.out = rv_sim_S)

rv_run_once <- function(seed, shock_scale, sd = 0.2, ...) {
  set.seed(seed)
  a <- rv_draw_a(rv_sim_N, rv_sim_S, sd, scale_by = shock_scale)
  sol <- rv_solve(rv_spec(rv_sim_N, rv_sim_S, t_s = rv_sim_t, a = a, ...), max_iter = 20000)
  pl <- rv_places(sol); sx <- rv_sparsity(sol$Ls)
  w_rel <- pl$w / mean(pl$w)
  f_sd <- summary(lm(w_rel ~ sx$SB_SD)); f_sk <- summary(lm(w_rel ~ sx$SB_SK))
  tibble(seed = seed, converged = sol$converged,
         R2_SD = f_sd$adj.r.squared, t_SD = coef(f_sd)[2, 3], R2_SK = f_sk$adj.r.squared, t_SK = coef(f_sk)[2, 3],
         coef_SD_per_unit_N_share = coef(f_sd)[2, 1] / rv_sim_N, coef_SK = coef(f_sk)[2, 1],
         wage_range_ppt = 100 * diff(range(w_rel)),
         cor_t_SD = cor(rv_sim_t, sx$SD), cor_t_SK = cor(rv_sim_t, sx$SK))
}

rv_table2a_runs <- tj_cached('rv_table2a_runs', bind_rows(
  bind_rows(lapply(1:20, rv_run_once, shock_scale = rep(1, rv_sim_S))) %>% mutate(case = 'Shocks the same size in every sector (cols 1-2)'),
  bind_rows(lapply(1:20, rv_run_once, shock_scale = rv_sim_t)) %>% mutate(case = 'Shocks divided by t_s (cols 3-4)')
), depends = rv_deps)

rv_table2a <- rv_table2a_runs %>% group_by(case) %>%
  summarise(runs = n(), all_converged = all(converged), across(c(R2_SD, t_SD, R2_SK, t_SK, wage_range_ppt, cor_t_SD, cor_t_SK), mean), .groups = 'drop')

rv_table2a_paper <- tibble(case = c('Shocks the same size in every sector (cols 1-2)', 'Shocks divided by t_s (cols 3-4)'),
                           R2_SD = c(0.45, 0.83), t_SD = c(15.8, 39.4), R2_SK = c(0.17, 0.29), t_SK = c(7.6, 11.45),
                           wage_range_ppt = c(21.7, 22.9), cor_t_SD = c(-0.958, NA), cor_t_SK = c(-0.908, NA))

tj_write(rv_table2a_runs, 'rv2023_table2a_runs.csv')
tj_write(bind_rows(rv_table2a_paper %>% mutate(source = 'paper'), rv_table2a %>% mutate(source = 'rebuild')), 'rv2023_table2a.csv')
print(as.data.frame(bind_rows(rv_table2a_paper %>% mutate(source = 'paper'), rv_table2a %>% mutate(source = 'rebuild'))))
