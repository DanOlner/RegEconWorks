# Model A curves: Venables (2020) Figure 1 and Venables (2018) Figures 1 to 3, with the 0.15 slope
# that 01 shows the papers used. Also checks the statements the 2018 paper makes about these curves.

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_v2020.R')
v2020_deps <- c('code/tradeable_jobs/functions_v2020.R', 'code/tradeable_jobs/02_v2020_curves.R')

v2020_base <- cm_spec()
v2020_bounds_base <- tj_cached('v2020_bounds_base', cm_bounds(v2020_base), depends = v2020_deps)
v2020_curve_data  <- tj_cached('v2020_curves', cm_curves(v2020_base, MT = seq(10, 90, by = 0.5)), depends = v2020_deps)

in_set <- v2020_curve_data %>% filter(MT >= v2020_bounds_base[['E']], MT <= v2020_bounds_base[['X']])
fig_range <- v2020_curve_data %>% filter(MT >= 20, MT <= 80)   # the x range of Venables (2018) Figs 1-3
interior <- in_set %>% filter(MT < v2020_bounds_base[['X']])
ratio <- in_set$u / in_set$rent_per_worker
ratio_peak <- in_set$MT[which.max(ratio)]

# Statements in Venables (2018) section 2.2-2.3 about these curves, checked against the solution
v2020_curve_checks <- tibble(
  statement = c(
    'wN rises with the share of type-T cities',
    'wT = pT q(LT) falls with the share of type-T cities',
    'Inside the equilibrium set, wT > wN and type-T cities are larger',
    'Total real rent is smallest where cities are the same size (point X)',
    'Total real income per worker U falls with the number of type-T cities across the set',
    'Workers\' utility relative to rents falls as type-T cities become fewer, throughout the set'),
  holds = c(
    all(diff(v2020_curve_data$wN) > 0),
    all(diff(fig_range$wT) < 0),
    all(interior$wT > interior$wN) && all(interior$LT > interior$LN),
    abs(v2020_curve_data$MT[which.min(v2020_curve_data$rent_per_worker)] - v2020_bounds_base[['X']]) <= 0.5,
    all(diff(in_set$U) < 0),
    all(diff(ratio) > 0)),
  note = c(
    'whole range solved (10% to 90%)',
    'over the figures\' range, 20% to 80%; it turns up again above 84%, outside the equilibrium set',
    '',
    '',
    sprintf('U is %.2f%% higher at E than at X', (in_set$U[1] / in_set$U[nrow(in_set)] - 1) * 100),
    sprintf('holds from E to %.1f%% of cities; the ratio dips slightly between there and X. Workers\' utility itself peaks at %.1f%%',
            ratio_peak, in_set$MT[which.max(in_set$u)]))
)
print(as.data.frame(v2020_curve_checks))
tj_write(v2020_curve_checks, 'v2020_curve_checks.csv')
tj_write(v2020_curve_data, 'v2020_curves.csv')
