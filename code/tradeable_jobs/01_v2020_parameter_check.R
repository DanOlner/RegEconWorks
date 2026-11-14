# Which agglomeration slope did Venables use? The 2020 appendix gives q(LT) = 1 + 0.015 LT; the 2018
# appendix (same model, same other parameters) gives 1 + 0.15 LT. Solve the model at both and compare
# with the numbers the 2018 paper reports for its Figures 1 to 3 (sections 2.2 and 2.3):
#   - at Tmin, q(LT) is 25% above q(0)
#   - at Tmin, type-T cities have 2.03 times the population and 4.1 times the total rent of type-N
#   - total real income per worker is 1.4% higher at Tmin than at Tmax
#   - Tmax is at 50% (because theta = 0.5); Figure 1's x axis puts Tmin a little under 30%
# Run from the repo root: Rscript code/tradeable_jobs/01_v2020_parameter_check.R

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_v2020.R')

slope_spec <- function(slope) cm_spec(types = list(T = cm_type('T', slope = slope), N = cm_type('N')))

param_check <- bind_rows(lapply(c(0.015, 0.15), function(slope) {
  spec <- slope_spec(slope)
  bounds <- cm_bounds(spec)
  at <- function(MT) cm_solve(c(T = MT, N = spec$M - MT), spec)
  sE <- at(bounds[['E']]); sX <- at(bounds[['X']])
  cT <- sE$cities[sE$cities$type == 'T', ]; cN <- sE$cities[sE$cities$type == 'N', ]
  tibble(source = paste0('solved, slope ', slope, if (slope == 0.015) ' (2020 appendix)' else ' (2018 appendix)'),
         slope = slope,
         Tmin_pct = bounds[['E']] / spec$M * 100,
         Tmax_pct = bounds[['X']] / spec$M * 100,
         q_gap_at_Tmin_pct = (cT$w / spec$types$T$p - 1) * 100,
         pop_ratio_T_to_N_Tmin = cT$L / cN$L,
         rent_ratio_T_to_N_Tmin = cT$R / cN$R,
         U_Tmin_vs_Tmax_pct = (sE$totals$U / sX$totals$U - 1) * 100)
}))

param_check <- bind_rows(param_check,
  tibble(source = 'reported in Venables (2018), section 2', slope = NA, Tmin_pct = NA, Tmax_pct = 50,
         q_gap_at_Tmin_pct = 25, pop_ratio_T_to_N_Tmin = 2.03, rent_ratio_T_to_N_Tmin = 4.1, U_Tmin_vs_Tmax_pct = 1.4))

print(as.data.frame(param_check), digits = 3, row.names = FALSE)
tj_write(param_check, 'v2020_parameter_check.csv')
