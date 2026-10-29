# Shared functions for the wage and profit share analysis
# Write-up: llm_output/wage_profit_shares_gva.md
# All scripts in this folder run from the project root, like the rest of code/
library(tidyverse)
library(readxl)

# Raw downloads go here (local/ is gitignored)
raw_dir <- 'local/wage_profit_raw'


# DOWNLOADING----

# Download once and reuse after that.
# ONS rate-limits repeated requests and returns a tiny text file instead (Cloudflare error 1015),
# so check xlsx and zip files really start with the zip signature 'PK'
get_file <- function(url, filename, dir = raw_dir, check_zip = str_detect(filename, '\\.(xlsx|zip)$')) {

  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  dest <- file.path(dir, filename)

  if (!file.exists(dest)) download.file(url, dest, mode = 'wb', quiet = TRUE)

  if (check_zip && !identical(readBin(dest, 'raw', 2), charToRaw('PK'))) {
    unlink(dest)
    stop('Download of ', filename, ' did not return a zip/xlsx file (ONS rate limit?). Wait a few minutes and rerun.')
  }

  dest
}


# ONS REGIONAL INCOME COMPONENTS----

# Regional GVA(B) per head and income components: ITL1 and ITL2 by industry group, 1998-2023
# Tables 6 to 16 are GVA and its components, all in pounds million.
# Holding gains and subsidies are already signed negative, so the components sum to GVA (checked for 2023)
regional_components_url <- 'https://www.ons.gov.uk/file?uri=/economy/grossvalueaddedgva/datasets/nominalregionalgrossvalueaddedbalancedperheadandincomecomponents/current/regionalgrossvalueaddedbalancedperheadandincomecomponents.xlsx'

regional_component_tables <- c(
  'Table 6' = 'GVA', 'Table 7' = 'CoE', 'Table 8' = 'MI', 'Table 9' = 'Rent',
  'Table 10' = 'NMCC', 'Table 11' = 'Hold', 'Table 12' = 'GTP', 'Table 13' = 'GTS',
  'Table 14' = 'TaxP', 'Table 15' = 'SubP', 'Table 16' = 'Disc'
)

# Returns one row per area x industry x year, one column per component, plus:
# K  = capital income other than mixed income (rent, non-market capital consumption, holding gains, trading profits and surpluses)
# FC = factor income = CoE + MI + K (excludes taxes on production and the statistical discrepancy)
load_regional_components <- function() {

  path <- get_file(regional_components_url, 'regional_gvab_income_components.xlsx')

  read_table <- function(sheet, component) {
    suppressMessages(read_excel(path, sheet = sheet, skip = 1, .name_repair = 'minimal')) %>%
      set_names(c('level', 'code', 'region', 'sic', 'sicdesc', names(.)[-(1:5)])) %>%
      pivot_longer(-(level:sicdesc), names_to = 'year', values_to = 'value') %>%
      mutate(year = as.integer(year), value = suppressWarnings(as.numeric(value)), component = component)
  }

  imap(regional_component_tables, ~ read_table(.y, .x)) %>%
    bind_rows() %>%
    select(-sicdesc) %>%
    pivot_wider(names_from = component, values_from = value) %>%
    mutate(
      across(GVA:Disc, ~ coalesce(.x, 0)),
      K = Rent + NMCC + Hold + GTP + GTS,
      FC = CoE + MI + K
    ) %>%
    # 'CD-CF (19-21)' overlaps the separate CD-CE and CF rows, so drop it to avoid double counting
    filter(sic != 'CD-CF (19-21)')
}


# ITL2 BOUNDARIES----

# ITL2 January 2025, UK, ultra generalised (BUC) - small enough for a page-sized map.
# Codes match the regional components workbook (46 areas)
itl2_boundaries_url <- 'https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/ITL2_JAN_2025_UK_BUC/FeatureServer/0/query?where=1%3D1&outFields=ITL225CD,ITL225NM&outSR=27700&f=geojson'

load_itl2_boundaries <- function() {
  path <- get_file(itl2_boundaries_url, 'itl2_jan2025_uk_buc.geojson', check_zip = FALSE)
  sf::read_sf(path)
}


# LABOUR SHARES----

# Sum components over whatever groups are passed in, then:
# ls_raw = CoE / factor income (all mixed income counted as capital)
# ls     = ONS 'method 5': mixed income split between labour and capital in the same
#          proportion as the rest of the group's factor income, alpha = CoE / (CoE + K)
labour_share <- function(df) {
  df %>%
    summarise(across(c(CoE, MI, K, FC, Rent, GTP), sum), .groups = 'drop') %>%
    mutate(
      alpha = CoE / (CoE + K),
      ls_raw = CoE / FC,
      ls = (CoE + alpha * MI) / FC
    )
}


# WEIGHTED SUMMARIES----

weighted_sd <- function(x, w) sqrt(sum(w * (x - weighted.mean(x, w))^2) / sum(w))

weighted_quantile <- function(x, w, p) {
  o <- order(x)
  x[o][which(cumsum(w[o]) / sum(w) >= p)[1]]
}
