# Cross-check regional labour shares against the Annual Business Survey
# ABS: employment costs / aGVA for the non-financial business economy, ITL1, with standard errors
# Used in llm_output/wage_profit_shares_gva.md, section 7.5,
# and in docs/chunks/wage_profit_shares/wage_profit_shares.qmd (which sources this script)
#
# Needs data/abs_itl1_long.csv, made by code/ABS_direct_dataprep.R
source('code/wage_profit_shares/functions.R')

abs <- read_csv('data/abs_itl1_long.csv', show_col_types = FALSE)


# ABS LABOUR SHARES BY ITL1----

# Standard error of the ratio by the delta method, treating the two errors as independent.
# They come from the same sample and are probably positively correlated, so this likely overstates the SE
abs_ls <- abs %>%
  filter(level == 'total', variable %in% c('aGVA', 'employment_costs')) %>%
  select(Region_name, year, variable, value, SE) %>%
  pivot_wider(names_from = variable, values_from = c(value, SE)) %>%
  mutate(
    ls = value_employment_costs / value_aGVA,
    se_ls = ls * sqrt((SE_employment_costs / value_employment_costs)^2 + (SE_aGVA / value_aGVA)^2)
  )

abs_ls %>%
  filter(year %in% c(2008, 2019, 2023)) %>%
  select(year, Region_name, ls, se_ls) %>%
  arrange(year, ls) %>%
  print(n = Inf)


# COMPARE WITH ONS'S BALANCED REGIONAL COMPONENTS----

# Restrict ONS's components to roughly the ABS's coverage (A to J, M, N, R, S) and use the raw share,
# CoE / factor income, since ABS employment costs don't include any self-employed income either
abs_like_industries <- c(
  'A (1-3)', 'B (5-9)', 'CA (10-12)', 'CB (13-15)', 'CC (16-18)', 'CD-CE (19-20)', 'CF (21)', 'CG (22-23)',
  'CH (24-25)', 'CI (26)', 'CJ (27)', 'CK (28)', 'CL (29-30)', 'CM (31-33)', 'D (35)', 'E (36-39)',
  'F (41-43)', 'G (45-47)', 'H (49-53)', 'I (55-56)', 'J (58-63)', 'M (69-75)', 'N (77-82)', 'R (90-93)', 'S (94-96)'
)

gvab_ls <- load_regional_components() %>%
  filter(level %in% c('UK', 'ITL1'), code != 'UKX', sic %in% abs_like_industries, year %in% c(2019, 2023)) %>%
  group_by(region, year) %>%
  labour_share() %>%
  transmute(Region_name = recode(region, 'East' = 'East of England'), year, gvab_ls_raw = ls_raw)

abs_vs_gvab <- gvab_ls %>%
  inner_join(abs_ls %>% select(Region_name, year, abs_ls = ls, abs_se = se_ls), by = c('Region_name', 'year'))

abs_vs_gvab %>% arrange(year, gvab_ls_raw) %>% print(n = Inf)

abs_vs_gvab_cor <- abs_vs_gvab %>%
  filter(Region_name != 'United Kingdom') %>%
  group_by(year) %>%
  summarise(pearson = cor(gvab_ls_raw, abs_ls), spearman = cor(gvab_ls_raw, abs_ls, method = 'spearman'))
abs_vs_gvab_cor
