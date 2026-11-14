# Model B: Venables (2018) section 3, two tradable sectors and two skill types (C5: trade shocks can
# knock out tradable cities; Stolper-Samuelson effects; the "lozenge" of equilibria).
#   1. The equilibrium set on a grid of (M_A, M_B), at the stated agglomeration slope (0.1) and at 0.3,
#      which reproduces the extent of the paper's Figures 4 and 5
#   2. The trade shock: p_B / p_A falls from 1 to 0.8 in steps, cities switching whenever a lone firm
#      would gain (the "dragged by the boundary" path), from S and from Y
#   3. The point without coordination failure (S^), where factor prices are equal in every city type

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_v2018s3.R')
mb_deps <- c('code/tradeable_jobs/functions_v2018s3.R', 'code/tradeable_jobs/05_v2018_two_sector.R')

mb_lozenge <- tj_cached('mb_lozenge', bind_rows(lapply(c(0.1, 0.3), function(slope) {
  bind_rows(lapply(c(1, 0.8), function(pB) {
    par <- mb_params(q_slope = slope, p = c(A = 1, B = pB))
    g <- expand_grid(MA = seq(8, 56, by = 1), MB = seq(8, 56, by = 1)) %>% filter(MA + MB <= 88)
    # With strong agglomeration the same city counts can have more than one solution for city sizes.
    # Solve every cell from the same start (equal-sized cities), so the map doesn't depend on the order
    # the grid is scanned in (warm starts carried over from the previous cell picked other branches)
    bind_rows(lapply(seq_len(nrow(g)), function(k) {
      s <- mb_solve(c(A = g$MA[k], B = g$MB[k], N = 100 - g$MA[k] - g$MB[k]), par)
      if (is.null(s)) return(NULL)
      gaps <- mb_entry_gaps(s, par)
      tibble(slope = slope, pB = pB, MA = g$MA[k], MB = g$MB[k],
             exit_A = max(gaps$gap[gaps$city == 'A' & gaps$sector == 'N']),
             exit_B = max(gaps$gap[gaps$city == 'B' & gaps$sector == 'N']),
             entry_A = max(gaps$gap[gaps$sector == 'A']), entry_B = max(gaps$gap[gaps$sector == 'B']),
             max_gap = max(gaps$gap))
    }))
  }))
})), depends = mb_deps)

mb_path <- function(start_counts, slope, pB_path = seq(1, 0.8, by = -0.01)) {
  counts <- start_counts; prev <- NULL; out <- list()
  for (k in seq_along(pB_path)) {
    par <- mb_params(q_slope = slope, p = c(A = 1, B = pB_path[k]))
    s <- mb_adjust(counts, par, start = prev)
    counts <- s$counts; prev <- s
    cw <- setNames(s$cities$R, s$cities$type)
    out[[k]] <- tibble(pB = pB_path[k], MA = counts[['A']], MB = counts[['B']], MN = counts[['N']],
                       R_A = cw['A'], R_B = cw['B'], R_N = cw['N'], rent_total = s$rent_total, U_total = s$U_total,
                       skill_premium = mean(s$cities$r / s$cities$w))
  }
  bind_rows(out)
}

mb_paths <- tj_cached('mb_paths', bind_rows(
  mb_path(c(A = 100/3, B = 100/3, N = 100/3), 0.1) %>% mutate(slope = 0.1, start = 'S'),
  mb_path(c(A = 100/3, B = 100/3, N = 100/3), 0.3) %>% mutate(slope = 0.3, start = 'S'),
  mb_path(c(A = 24, B = 35, N = 41), 0.3) %>% mutate(slope = 0.3, start = 'Y')
), depends = mb_deps)

mb_no_cf <- tj_cached('mb_no_cf', bind_rows(lapply(c(0.1, 0.3), function(slope) {
  par <- mb_params(q_slope = slope, p = c(A = 1, B = 0.8))
  m <- mb_no_coordination_failure(par, guess = c(48, 17))
  s <- mb_solve(c(A = m[1], B = m[2], N = 100 - sum(m)), par)
  s0 <- mb_solve(c(A = 100/3, B = 100/3, N = 100/3), mb_params(q_slope = slope))
  tibble(slope = slope, MA = m[1], MB = m[2], MN = 100 - sum(m), rent = mean(s$cities$R),
         U_change_pct = 100 * (s$U_total / s0$U_total - 1),
         skill_premium = mean(s$cities$r / s$cities$w), skill_premium_start = mean(s0$cities$r / s0$cities$w))
})), depends = mb_deps)

# Compare with the numbers Venables (2018) reports for the move from S
mb_compare <- mb_paths %>% filter(start == 'S') %>% group_by(slope) %>%
  summarise(MA_end = last(MA), MB_end = last(MB), MN_end = last(MN),
            rent_A_pct = 100 * (last(R_A) / first(R_A) - 1), rent_B_pct = 100 * (last(R_B) / first(R_B) - 1),
            rent_N_pct = 100 * (last(R_N) / first(R_N) - 1),
            total_rent_pct = 100 * (last(rent_total) / first(rent_total) - 1),
            real_income_pct = 100 * (last(U_total) / first(U_total) - 1),
            skill_premium_end = last(skill_premium), .groups = 'drop') %>%
  mutate(source = paste('rebuild, slope', slope)) %>%
  bind_rows(tibble(source = 'reported in Venables (2018) section 3.3', MA_end = 33, MB_end = 25.7, MN_end = 41.3,
                   rent_A_pct = 126, rent_B_pct = -43, rent_N_pct = -26, total_rent_pct = 22, real_income_pct = 2))

tj_write(mb_lozenge, 'v2018s3_equilibrium_set.csv')
tj_write(mb_paths, 'v2018s3_shock_paths.csv')
tj_write(mb_no_cf, 'v2018s3_no_coordination_failure.csv')
tj_write(mb_compare, 'v2018s3_compare.csv')
print(as.data.frame(mb_compare %>% mutate(across(where(is.numeric), ~ round(.x, 2)))))
print(mb_no_cf)
print(mb_paths %>% group_by(slope, start) %>% summarise(MA = paste(round(first(MA), 1), '->', round(last(MA), 1)),
                                                       MB = paste(round(first(MB), 1), '->', round(last(MB), 1)), .groups = 'drop'))
