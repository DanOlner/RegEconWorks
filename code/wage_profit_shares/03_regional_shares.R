# Regional labour shares from ONS's balanced regional GVA income components, ITL1 and ITL2
# Used in llm_output/wage_profit_shares_gva.md, sections 7.1 to 7.4,
# and in docs/chunks/wage_profit_shares/wage_profit_shares.qmd (which sources this script)
#
# Caveat (section 7.1 of the write-up): each component is a national total shared out by an indicator.
# Company profits follow ABS operating surplus in most industries but PAY in finance and the public sector,
# so regional labour shares there are largely set by assumption
source('code/wage_profit_shares/functions.R')

comp <- load_regional_components()
yr_regional <- 2023  # latest year with components in the workbook

# Industry rows only (not the 'Total' row), for ITL1 regions plus two UK rows:
# 'UK' includes Extra-Regio (mostly offshore oil and gas, which isn't in any region);
# 'UKX' is UK less Extra-Regio, which is what the 12 regions add up to, so it is the benchmark for regions
itl1 <- comp %>% filter(level %in% c('UK', 'ITL1'), sic != 'Total')
itl2 <- comp %>% filter(level == 'ITL2', sic != 'Total')
uk_codes <- c('UK', 'UKX')


# ITL1, 2023----

# Labour share by industry for UK less Extra-Regio, excluding real estate, used for the industry-mix prediction.
# Using the whole UK instead would put mining's benchmark at 12% (offshore oil and gas) rather than 51%
uk_by_industry <- itl1 %>%
  filter(code == 'UKX', year == yr_regional, sic != 'L (68)') %>%
  group_by(sic) %>%
  labour_share() %>%
  select(sic, ls_uk = ls)

# What each area's labour share would be with UK labour shares in each industry
# but its own mix of industries (weights = factor income), excluding real estate
mix_prediction <- function(df) {
  df %>%
    filter(sic != 'L (68)') %>%
    left_join(uk_by_industry, by = 'sic') %>%
    group_by(code) %>%
    summarise(ls_mix = sum(FC * ls_uk) / sum(FC))
}

itl1_all <- itl1 %>% filter(year == yr_regional) %>% group_by(code, region) %>% labour_share() %>%
  transmute(code, region, ls_all = ls, rent_share = Rent / FC, profit_share = GTP / FC)

itl1_exL <- itl1 %>% filter(year == yr_regional, sic != 'L (68)') %>% group_by(code) %>% labour_share() %>%
  select(code, ls_exL = ls, ls_raw_exL = ls_raw)

itl1_table <- itl1_all %>%
  left_join(itl1_exL, by = 'code') %>%
  left_join(itl1 %>% filter(year == yr_regional, !code %in% uk_codes) %>% mix_prediction(), by = 'code') %>%
  mutate(within_gap = ls_exL - ls_mix) %>%
  arrange(desc(ls_exL))

itl1_table %>% mutate(across(where(is.numeric), ~ round(100 * .x, 1))) %>% print(n = Inf)

# Extra-Regio = UK minus 'UK less Extra-Regio'
extra_regio <- comp %>%
  filter(code %in% c('UK', 'UKX'), sic == 'Total', year == yr_regional) %>%
  select(code, GVA, CoE, FC) %>%
  summarise(across(c(GVA, CoE, FC), ~ .x[code == 'UK'] - .x[code == 'UKX'])) %>%
  mutate(ls_raw = CoE / FC)
extra_regio


# INDUSTRY BY INDUSTRY: HOW MUCH REGIONS DIFFER, AND WHAT DRIVES A REGION'S GAP----

# Spread of each industry's labour share across the 12 ITL1 regions, against UK less Extra-Regio.
# Finance (K) is tight because its profits are shared out by pay
itl1_industry_spread <- itl1 %>%
  filter(year == yr_regional) %>%
  group_by(sic, code, region) %>%
  labour_share() %>%
  group_by(sic) %>%
  summarise(
    ukx = ls[code == 'UKX'],
    min = min(ls[!code %in% uk_codes]), max = max(ls[!code %in% uk_codes]), sd = sd(ls[!code %in% uk_codes]),
    london = ls[region == 'London'], north_east = ls[region == 'North East']
  )

itl1_industry_spread %>% mutate(across(where(is.numeric), ~ round(100 * .x, 1))) %>% print(n = Inf)

# Mixed income share of factor income by industry (UK), to flag where the self-employment split matters
uk_mi_shares <- itl1 %>% filter(code == 'UK', year == yr_regional) %>% group_by(sic) %>% labour_share() %>%
  transmute(sic, mi_share = MI / FC) %>% arrange(desc(mi_share))
uk_mi_shares %>% print(n = 8)

# A region's within-industry gap, industry by industry: weight x (regional share - UK share).
# This sums to a slightly different total from itl1_table because alpha is computed per industry here
within_by_industry <- function(region_name) {
  itl1 %>%
    filter(region == region_name, year == yr_regional, sic != 'L (68)') %>%
    group_by(sic) %>%
    labour_share() %>%
    left_join(uk_by_industry, by = 'sic') %>%
    mutate(weight = FC / sum(FC), contribution = weight * (ls - ls_uk)) %>%
    arrange(contribution) %>%
    select(sic, weight, ls, ls_uk, contribution)
}

within_contributions <- c('London', 'North East', 'Scotland') %>%
  set_names() %>%
  map(within_by_industry)

within_contributions %>%
  map(~ list(total_pp = 100 * sum(.x$contribution), biggest = .x %>% filter(abs(contribution) >= 0.002)))


# ITL2, 2023----

itl2_table <- itl2 %>%
  filter(year == yr_regional, sic != 'L (68)') %>%
  group_by(code, region) %>%
  labour_share() %>%
  select(code, region, ls_exL = ls, ls_raw_exL = ls_raw) %>%
  left_join(itl2 %>% filter(year == yr_regional) %>% mix_prediction(), by = 'code') %>%
  mutate(within_gap = ls_exL - ls_mix) %>%
  ungroup()

nrow(itl2_table)

itl2_summary <- itl2_table %>%
  summarise(
    min = min(ls_exL), p10 = quantile(ls_exL, 0.1), median = median(ls_exL), p90 = quantile(ls_exL, 0.9), max = max(ls_exL),
    sd = sd(ls_exL), sd_mix = sd(ls_mix), sd_within = sd(within_gap), cor_mix_within = cor(ls_mix, within_gap)
  )
itl2_summary

itl2_table %>% arrange(ls_exL) %>% print(n = 8)
itl2_table %>% arrange(desc(ls_exL)) %>% print(n = 8)

# Including real estate
itl2_inclL <- itl2 %>% filter(year == yr_regional) %>% group_by(code, region) %>% labour_share() %>%
  select(code, region, ls) %>% arrange(ls)
itl2_inclL %>% print(n = 5)


# TRENDS, ITL1, EXCLUDING REAL ESTATE----

itl1_trend <- itl1 %>%
  filter(sic != 'L (68)') %>%
  group_by(code, region, year) %>%
  labour_share() %>%
  select(code, region, year, ls) %>%
  ungroup()

itl1_trend %>%
  filter(code %in% c('TLI', 'TLC', 'UK', 'UKX'), year %in% c(1998, 2001, 2007, 2010, 2016, 2019, 2023)) %>%
  select(-code) %>%
  pivot_wider(names_from = region, values_from = ls)

# Spread across the 12 ITL1 regions each year
itl1_spread_by_year <- itl1_trend %>%
  filter(!code %in% uk_codes) %>%
  group_by(year) %>%
  summarise(sd = sd(ls), range = max(ls) - min(ls))
itl1_spread_by_year %>% print(n = Inf)
