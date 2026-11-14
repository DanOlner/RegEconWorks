# Round 2, test T10: break-even. How much more could a point of productivity cost in the long tail, the
# business-to-business groups or local services before a frontier push in tradables does better?
# Evidence on the cost of a point is too thin to assume one (plan section 7), so this computes the ratio at
# which two policies give the same real gain, and leaves the cost to be argued about.
#
# A "point" is the employment-weighted mean log rise in productivity a policy delivers, sum L_is d log a_is
# over sum L_is (16_modelF.R's `points`), so it scales with the workers a policy reaches. For proxies X and
# P1 (frontier push), the break-even cost ratio is
#     (real gain per point under X) / (real gain per point under P1)
# X beats P1 if a point costs less than that multiple of a point under P1.
#   national   real gain = national welfare (Frechet index, or the immobile index)
#   local      the lagging place's own real income per resident, from E2: a group's +5% in that place only,
#              per point delivered in that place (its employment share in the group x 5%)
# Both benchmarks: people mobile between places (broad) and immobile (narrow).

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_uk.R')
source('code/tradeable_jobs/functions_io.R')
source('code/tradeable_jobs/functions_rv2023.R')
source('code/tradeable_jobs/functions_modelF.R')
source('code/tradeable_jobs/16_modelF.R')

t10 <- tj_cached('t10_breakeven', {
  prox <- mf_runs %>% filter(grepl('^P[1-4] ', experiment), supply_chains) %>%
    mutate(gain_per_point = d_welfare / points, gva_per_point = d_gva_pw / points)
  base <- prox %>% filter(grepl('^P1 ', experiment)) %>% select(mobility, seed, p1_gain = gain_per_point, p1_gva = gva_per_point)
  national <- prox %>% left_join(base, by = c('mobility', 'seed')) %>%
    mutate(breakeven = gain_per_point / p1_gain, breakeven_official_lens = gva_per_point / p1_gva) %>%
    group_by(experiment, mobility) %>%
    summarise(points = mean(points), d_welfare = mean(d_welfare), gain_per_point = mean(gain_per_point),
              breakeven_mean = mean(breakeven), breakeven_min = min(breakeven), breakeven_max = max(breakeven),
              breakeven_official_lens = mean(breakeven_official_lens), .groups = 'drop')

  # Local: the lagging place's own gain per point delivered there, by group, against the tradable frontier groups
  sec <- mf$sectors
  loc <- mf_runs %>% filter(experiment == 'E2 local', supply_chains) %>% left_join(sec %>% select(group, limit, t_s), by = 'group')
  # points delivered in the lagging place: its employment share in the group (from the run's baseline) x the shock
  local <- loc %>% mutate(points = lag_emp_share * log(1 + mf_shock), local_gain_per_point = lag_d_u / points,
                          national_gain_per_point = d_welfare / points)
  # Pooled within each type: summed gain over summed points (a ratio of means, not a mean of ratios: a
  # group that is a sliver of the place's jobs has a tiny denominator and a wild ratio of its own)
  pooled <- local %>% group_by(limit, mobility, seed) %>%
    summarise(local = sum(lag_d_u) / sum(points), national = sum(d_welfare) / sum(points), groups = n(), .groups = 'drop')
  ref <- pooled %>% filter(limit == 'Tradable frontier') %>% select(mobility, seed, ref_local = local, ref_national = national)
  local_by_type <- pooled %>% left_join(ref, by = c('mobility', 'seed')) %>%
    mutate(breakeven_local = local / ref_local, breakeven_national = national / ref_national) %>%
    group_by(limit, mobility) %>%
    summarise(local_gain_per_point = mean(local), national_gain_per_point = mean(national),
              breakeven_local = mean(breakeven_local), breakeven_local_min = min(local / ref_local),
              breakeven_local_max = max(local / ref_local), breakeven_national = mean(breakeven_national),
              groups = first(groups), .groups = 'drop')
  local_by_group <- local %>% group_by(group, limit, mobility) %>%
    summarise(points = mean(points), lag_d_u = mean(lag_d_u), local_gain_per_point = sum(lag_d_u) / sum(points),
              national_gain_per_point = sum(d_welfare) / sum(points), .groups = 'drop')
  list(national = national, local_by_group = local_by_group, local_by_type = local_by_type)
}, depends = c('code/tradeable_jobs/16_modelF.R', 'code/tradeable_jobs/19_t10_breakeven.R'))

tj_write(t10$national, 't10_breakeven_national.csv')
tj_write(t10$local_by_group, 't10_breakeven_local_by_group.csv')
tj_write(t10$local_by_type, 't10_breakeven_local_by_type.csv')
