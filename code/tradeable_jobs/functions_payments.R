# Round 2 helpers for the ONS industry-to-industry payment flows by region (test T4, later T3 and T5).
# Source: ONS, "Industry to industry payment flows by region, UK" (official statistics in development,
# from Pay.UK Bacs and Faster Payments data): monthly payments between 2-digit SIC industries in the
# 12 ITL1 regions, January 2019 onwards. Values are rounded to £1,000 and transaction counts to 100;
# cells that could disclose a payer are suppressed ("[C]"), about three-quarters of monthly cells.
#
# What the geography means (see RegionalEconomicTools/claude/payment_flows_method_and_caveats.md):
# payments are placed at the registered paying and receiving entity, not where the activity is;
# households are not in the data (business-to-business payments only); card takings arrive as one
# payment from the card acquirer (SIC 64), and platform payouts from SIC 63 and 82, mostly London-
# registered. So intermediary payers are stripped before measuring where a sector's income comes from.
# Needs functions_common.R.

suppressPackageStartupMessages(suppressWarnings(library(data.table)))

pay_dir <- file.path(tj_raw_dir, 'payments')
pay_base <- 'https://www.ons.gov.uk/file?uri=/economy/economicoutputandproductivity/output/datasets/industrytoindustrypaymentflowsbyregionuk/'
pay_editions <- c('2019to2021/industryregionbusinesspayments1921dataset17092026.zip',
                  '2022to2024/industryregionbusinesspayments2224dataset17092026.zip',
                  '2025to2026/industryregionbusinesspayments2526dataset22102026.zip')
pay_intermediaries <- c('63', '64', '66', '82')   # platforms, card acquirers and banks, financial auxiliaries, booking and admin
pay_not_industries <- c('00', '97', '98', '99')   # unknown, households as employers, extraterritorial

pay_files <- function() vapply(pay_editions, function(e) tj_get_file(paste0(pay_base, e), basename(e), dir = pay_dir, expect = 'zip'), '')

# Yearly sums of the published monthly cells, with the number of months published and suppressed
pay_yearly <- function() {
  files <- pay_files()
  out <- rbindlist(lapply(files, function(f) {
    d <- fread(cmd = paste('unzip -p', shQuote(f)), colClasses = 'character', showProgress = FALSE)
    setnames(d, c('payer_sic', 'payer_region', 'payee_sic', 'payee_region', 'date', 'value', 'n'))
    d[, year := 2000L + as.integer(substr(date, 8, 9))]
    d[, suppressed := value == '[C]']
    d[, `:=`(value = suppressWarnings(as.numeric(value)), n = suppressWarnings(as.numeric(n)))]
    d[, .(value = sum(value, na.rm = TRUE), n = sum(n, na.rm = TRUE),
          months_published = sum(!suppressed), months_suppressed = sum(suppressed)),
      by = .(year, payer_sic, payer_region, payee_sic, payee_region)]
  }))
  stopifnot(!anyDuplicated(out[, .(year, payer_sic, payer_region, payee_sic, payee_region)]))
  as_tibble(out)
}

# Where each selling industry's business income comes from, one year. Flows from unknown industries or
# regions, households as employers and extraterritorial bodies are dropped; strip = TRUE also drops the
# intermediary payers. For each selling division s:
#   other_share     share of its income paid from other regions (pooled across its regions)
#   expected_other  the same if every buyer region bought from s's regions in proportion to their
#                   national purchases from s, i.e. no home bias: sum over r of income_rs (1 - p_rs) / income_s,
#                   with p_rs region r's share of all payments to s
#   index           other_share / expected_other: 1 = no home bias, 0 = all income from own region
pay_seller_measures <- function(d, yr, strip = TRUE, drop_london = FALSE) {
  x <- d %>% filter(year == yr, !payer_sic %in% pay_not_industries, !payee_sic %in% pay_not_industries,
                    payer_region != 'unknown', payee_region != 'unknown')
  if (strip) x <- x %>% filter(!payer_sic %in% pay_intermediaries)
  if (drop_london) x <- x %>% filter(payer_region != 'TLI', payee_region != 'TLI')
  buyers <- x %>% group_by(payee_sic, payer_region) %>% summarise(v = sum(value), .groups = 'drop') %>%
    group_by(payee_sic) %>% mutate(p = v / sum(v)) %>% ungroup() %>% select(payee_sic, region = payer_region, p)
  x %>% group_by(payee_sic, region = payee_region) %>%
    summarise(income = sum(value), own = sum(value[payer_region == payee_region]),
              cells = n(), cells_suppressed_all_year = sum(months_published == 0), .groups = 'drop') %>%
    left_join(buyers, by = c('payee_sic', 'region')) %>% mutate(p = coalesce(p, 0)) %>%
    group_by(sic2 = payee_sic) %>%
    summarise(income_bn = sum(income) / 1e9, other_share = 1 - sum(own) / sum(income),
              expected_other = sum(income * (1 - p)) / sum(income),
              share_cells_suppressed = sum(cells_suppressed_all_year) / sum(cells), .groups = 'drop') %>%
    mutate(index = other_share / expected_other)
}
