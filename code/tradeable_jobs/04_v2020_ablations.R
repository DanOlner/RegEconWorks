# Step 4 of the plan: which ingredient of Model A does each claim need? Switch ingredients off one at a
# time and rerun the same tests:
#   - the width of the equilibrium set [E, X] (C2: indeterminacy; zero width means a unique equilibrium)
#   - an import shock that removes 5 of the type-T cities, starting from X as Venables (2018) does: do
#     new tradables replace them (C3), do all type-N cities lose (C4)?
#   - total real income at E against X (C6: do fewer tradable cities lower aggregate real income?)

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_v2020.R')
abl_deps <- c('code/tradeable_jobs/functions_v2020.R', 'code/tradeable_jobs/04_v2020_ablations.R')

saturating_q <- function(L) 1 + 0.15 * pmin(L, 1)   # agglomeration used up beyond the size at X

v2020_variants <- list(
  'Base case (papers\' parameters)'                    = cm_spec(),
  'No agglomeration (q flat)'                           = cm_spec(types = list(T = cm_type('T', slope = 0), N = cm_type('N'))),
  'Half the agglomeration (slope 0.075)'                = cm_spec(types = list(T = cm_type('T', slope = 0.075), N = cm_type('N'))),
  'Agglomeration in non-tradables too (slope 0.15)'     = cm_spec(types = list(T = cm_type('T'), N = cm_type('N', slope = 0.15))),
  'Agglomeration used up above the size at X'           = cm_spec(types = list(T = cm_type('T', q = saturating_q), N = cm_type('N'))),
  'Smaller non-tradable sector (theta 0.3)'             = cm_spec(theta = 0.3),
  'Small non-tradable sector (theta 0.1)'               = cm_spec(theta = 0.1),
  'Immobile labour (city sizes fixed)'                  = cm_spec(mobility = 'immobile'),
  'Lower urban costs (b 0.2)'                           = cm_spec(b = 0.2),
  'Higher urban costs (b 0.6)'                          = cm_spec(b = 0.6),
  'Much higher urban costs (b 1.2)'                     = cm_spec(b = 1.2)
)

ablate <- function(label, spec) {
  bounds <- cm_bounds(spec)
  E <- bounds[['E']]; X <- bounds[['X']]
  if (is.na(E) && !is.na(X)) E <- X     # no edge found below X: the set has collapsed onto X
  width <- X - E                 # also the largest shock from X that brings in no new tradables
  start <- X
  before <- cm_solve(c(T = start, N = 100 - start), spec)
  after <- cm_adjust(c(T = start - 5, N = 100 - start + 5), spec)
  re_entered <- if (nrow(after$moves)) sum(after$moves$cities[after$moves$to == 'T']) else 0
  b <- function(s, ty, v) s$cities[[v]][s$cities$type == ty]
  sE <- cm_solve(c(T = E, N = 100 - E), spec); sX <- cm_solve(c(T = X, N = 100 - X), spec)
  tibble(
    variant = label, E = E, X = X, width = width, shock_start = start,
    re_entered_of_5 = re_entered,
    wN_change_pct = (b(after, 'N', 'w') / b(before, 'N', 'w') - 1) * 100,
    LN_change_pct = (b(after, 'N', 'L') / b(before, 'N', 'L') - 1) * 100,
    RN_change_pct = (b(after, 'N', 'R') / b(before, 'N', 'R') - 1) * 100,
    wT_change_pct = (b(after, 'T', 'w') / b(before, 'T', 'w') - 1) * 100,
    worker_u_change_pct = (b(after, 'N', 'u') / b(before, 'N', 'u') - 1) * 100,
    # Under immobile labour utility differs by city type: the gap a hit city's workers end up with
    hit_city_u_gap_pct = (b(after, 'N', 'u') / b(after, 'T', 'u') - 1) * 100,
    rent_share_change_pts = (after$totals$rent_share - before$totals$rent_share) * 100,
    U_E_vs_X_pct = (sE$totals$U / sX$totals$U - 1) * 100
  )
}

v2020_ablations <- tj_cached('v2020_ablations',
  bind_rows(Map(ablate, names(v2020_variants), v2020_variants)), depends = abl_deps)

# Which claims survive in each variant
v2020_ablation_claims <- v2020_ablations %>%
  transmute(variant,
            C2_range_of_equilibria = width > 0.5,
            C3_lost_tradables_not_replaced = re_entered_of_5 < 0.5,
            C4_all_N_cities_lose = wN_change_pct < -0.01 & RN_change_pct < -0.01 & wT_change_pct > 0.01,
            C6_fewer_T_cities_lower_real_income = U_E_vs_X_pct < -0.01)

tj_write(v2020_ablations, 'v2020_ablations.csv')
tj_write(v2020_ablation_claims, 'v2020_ablation_claims.csv')
print(as.data.frame(v2020_ablations %>% mutate(across(where(is.numeric), ~ round(.x, 2)))))
print(as.data.frame(v2020_ablation_claims))
