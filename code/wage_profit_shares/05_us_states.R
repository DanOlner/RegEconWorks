# US state labour shares from BEA state GDP by income component
# Used in llm_output/wage_profit_shares_gva.md, section 7.7,
# and in docs/chunks/wage_profit_shares/wage_profit_shares.qmd (which sources this script)
#
# Labour share = compensation / (compensation + gross operating surplus).
# BEA's state gross operating surplus includes proprietors' income, so these are raw shares
# (all self-employed income counted as capital). Real estate = NAICS 531
source('code/wage_profit_shares/functions.R')

bea_zip <- get_file('https://apps.bea.gov/regional/zip/SAGDP.zip', 'bea_SAGDP.zip')

# SAGDP4 = compensation of employees by industry, SAGDP7 = gross operating surplus by industry (thousands of dollars)
read_bea <- function(table, component) {
  csv <- paste0(table, '__ALL_AREAS_1997_2025.csv')
  unzip(bea_zip, files = csv, exdir = raw_dir, overwrite = FALSE)
  # The footnote lines at the end of each file have fewer columns, which triggers a parsing warning
  suppressWarnings(read_csv(file.path(raw_dir, csv), col_types = cols(.default = 'c'), show_col_types = FALSE)) %>%
    filter(!is.na(LineCode)) %>%  # drops those footnote lines
    pivot_longer(`1997`:`2025`, names_to = 'year', values_to = 'value') %>%
    transmute(
      fips = str_trim(GeoFIPS), area = str_remove(GeoName, ' \\*$'),
      industry = str_trim(IndustryClassification), description = str_trim(Description),
      year = as.integer(year), value = suppressWarnings(as.numeric(value)), component = component
    )
}

bea <- bind_rows(read_bea('SAGDP4', 'CoE'), read_bea('SAGDP7', 'GOS')) %>%
  pivot_wider(names_from = component, values_from = value)

yr_us <- 2024

all_industries <- bea %>% filter(industry == '...', description == 'All industry total')
real_estate <- bea %>% filter(industry == '531') %>% select(fips, year, CoE_re = CoE, GOS_re = GOS)

us_shares <- all_industries %>%
  left_join(real_estate, by = c('fips', 'year')) %>%
  mutate(
    ls = CoE / (CoE + GOS),
    ls_exRE = (CoE - CoE_re) / (CoE + GOS - CoE_re - GOS_re)
  )

# States and DC have FIPS codes ending 000 below 57000 (above that are BEA regions)
is_state <- function(fips) str_detect(fips, '000$') & fips != '00000' & as.integer(fips) < 57000


# RESULTS----

# US totals over time
us_trend <- us_shares %>% filter(fips == '00000') %>% select(year, ls, ls_exRE)
us_trend %>% filter(year %in% c(1997, 2000, 2007, 2014, 2019, yr_us))

us_states <- us_shares %>% filter(is_state(fips), year == yr_us)

us_states_summary <- us_states %>%
  summarise(n = n(), min = min(ls_exRE), p10 = quantile(ls_exRE, 0.1), median = median(ls_exRE),
            p90 = quantile(ls_exRE, 0.9), max = max(ls_exRE), sd = sd(ls_exRE))
us_states_summary

us_states %>% arrange(ls_exRE) %>% select(area, ls, ls_exRE) %>% print(n = 8)
us_states %>% arrange(desc(ls_exRE)) %>% select(area, ls, ls_exRE) %>% print(n = 8)

# The same industry across states
us_industry_spread <- bea %>%
  filter(is_state(fips), year == yr_us, industry %in% c('21', '22', '23', '31-33', '42', '44-45', '52', '531', '54', '62', '72')) %>%
  filter(!is.na(CoE), !is.na(GOS), CoE + GOS > 0) %>%
  mutate(ls = CoE / (CoE + GOS)) %>%
  group_by(industry, description) %>%
  summarise(n = n(), p10 = quantile(ls, 0.1), median = median(ls), p90 = quantile(ls, 0.9), .groups = 'drop')
us_industry_spread
