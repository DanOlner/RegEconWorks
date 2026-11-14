# Round 2, test T4: tradability within the UK, measured from business-to-business payments.
# For each SIC division, how much of its business income comes from other ITL1 regions, against what it
# would be with no home bias (functions_payments.R). Then:
#   - validation against Scotland's input-output tables (sales to the rest of the UK by product);
#   - comparison with round 1's sparsity (SK) and the export share, by division;
#   - round 1's UK regression with a "business-to-business tradability bias" beside sparsity bias.
# Main year 2019 (the input-output tables' year, before the pandemic); 2024 as a check on stability.

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_uk.R')
source('code/tradeable_jobs/functions_io.R')
source('code/tradeable_jobs/functions_payments.R')
invisible(capture.output(source('code/tradeable_jobs/09_uk_sparsity.R')))   # round 1's areas and sectors (cached; quiet)

t4_deps <- c('code/tradeable_jobs/functions_payments.R', 'code/tradeable_jobs/functions_io.R',
             'code/tradeable_jobs/14_t4_payment_tradability.R')

pay <- tj_cached('pay_yearly', pay_yearly(), depends = 'code/tradeable_jobs/functions_payments.R', key = pay_editions)

# Scotland: sales to the rest of the UK as a share of output, by SIC division, 2019
scot_ruk <- tj_cached('scot_ruk', {
  dir <- file.path(tj_raw_dir, 'scotland_io')
  base <- 'https://www.gov.scot/binaries/content/documents/govscot/publications/statistics/2019/08/input-output-latest/documents/'
  fx <- tj_get_file(paste0(base, 'detailed-imports-exports-tables-all-years/detailed-imports-exports-tables-all-years/govscot%3Adocument/SUT-Imports-Exports-98-22.xlsx'),
                    'SUT-Imports-Exports-98-22.xlsx', dir = dir, expect = 'xls')
  fs <- tj_get_file(paste0(base, 'all-tables-all-years/all-tables-all-years/govscot%3Adocument/SUT-98-22.xlsx'),
                    'SUT-98-22.xlsx', dir = dir, expect = 'xls')
  rd <- function(f, sheet) {
    d <- suppressMessages(read_excel(f, sheet = sheet, col_names = FALSE, col_types = 'text'))
    h <- which(d[[1]] == 'Year')[1]
    setNames(d[-(1:h), ], make.names(unlist(d[h, ]), unique = TRUE))
  }
  ex <- rd(fx, 'Exports Detail'); out <- rd(fs, 'Output & supply')
  # sales to visitors from the rest of the UK, and other exports to the rest of the UK (headers have line breaks)
  ruk_cols <- names(ex)[grepl('UK', names(ex)) & !grepl('World|^Total', names(ex))]
  stopifnot(length(ruk_cols) == 2)
  ex <- ex %>% filter(Year == '2019')
  ex <- tibble(code = ex$SIC, ruk = rowSums(sapply(ruk_cols, function(col) io_num(ex[[col]])), na.rm = TRUE))
  out_col <- grep('^Total.output.of.products', names(out), value = TRUE)[1]
  out <- out %>% filter(Year == '2019')
  out <- tibble(code = out$SIC, output = io_num(out[[out_col]]))
  ex %>% inner_join(out, by = 'code') %>% mutate(sic2 = substr(code, 1, 2)) %>%
    group_by(sic2) %>% summarise(ruk = sum(ruk), output = sum(output), .groups = 'drop') %>%
    filter(output > 0) %>% mutate(ruk_share = ruk / output)
}, depends = t4_deps)

# ONS interregional trade in goods and services, 2019 (official statistics in development): exports from
# each ITL1 region to every other, by eight industry groups (tables 3 and 6, summed over region pairs)
irt <- tj_cached('irt_2019', {
  f <- tj_get_file('https://www.ons.gov.uk/file?uri=/businessindustryandtrade/internationaltrade/datasets/interregionaltradeingoodsandservicesuk/2019/2019interregionaltradeuk.xlsx',
                   '2019interregionaltradeuk.xlsx', dir = file.path(tj_raw_dir, 'interregional'), expect = 'xls')
  one <- function(sheet, kind) {
    d <- suppressMessages(read_excel(f, sheet = sheet, col_names = FALSE, col_types = 'text'))
    h <- which(d[[1]] == 'Region')[1]
    x <- setNames(d[-(1:h), ], unlist(d[h, ])) %>% filter(`Direction of Trade` == 'Exports')
    x %>% select(-Region, -`Partner Region`, -`Direction of Trade`, -`All industries`) %>%
      pivot_longer(everything(), names_to = 'industry_group', values_to = 'v') %>%
      group_by(industry_group) %>% summarise(exports = sum(io_num(v), na.rm = TRUE), suppressed = sum(v == '[c]'),
                                             pairs = n(), .groups = 'drop') %>% mutate(kind = kind)
  }
  bind_rows(one('Table 3 ITL1 Industry TiG', 'goods'), one('Table 6 ITL1 Industry TiS', 'services')) %>%
    group_by(industry_group) %>% summarise(exports_m = sum(exports), suppressed_cells = sum(suppressed), .groups = 'drop')
}, depends = t4_deps)
irt_sections <- tribble(
  ~industry_group, ~sections,
  'Non-manufacturing production', 'A,B,D,E,F', 'Manufacturing', 'C', 'Wholesale and motor trades', 'G45-46',
  'Retail (excluding motor trades)', 'G47', 'Transportation and storage, accommodation and food service activities', 'H,I',
  'Information and communication', 'J', 'Real estate activities, professional, scientific and technical activities', 'L,M',
  'Other service industries', 'N-U')
irt_group_of_sic2 <- function(sic2) {
  sec <- as.character(io_section_sic2(as.integer(sic2)))
  case_when(sec %in% c('A', 'B', 'D', 'E', 'F') ~ 'Non-manufacturing production', sec == 'C' ~ 'Manufacturing',
            sic2 %in% c('45', '46') ~ 'Wholesale and motor trades', sic2 == '47' ~ 'Retail (excluding motor trades)',
            sec %in% c('H', 'I') ~ 'Transportation and storage, accommodation and food service activities',
            sec == 'J' ~ 'Information and communication',
            sec %in% c('L', 'M') ~ 'Real estate activities, professional, scientific and technical activities',
            sec %in% c('N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U') ~ 'Other service industries')
}

t4 <- tj_cached('t4_tradability', {
  versions <- list(
    `Raw` = pay_seller_measures(pay, 2019, strip = FALSE),
    `Intermediaries stripped` = pay_seller_measures(pay, 2019, strip = TRUE),
    `Stripped, without London` = pay_seller_measures(pay, 2019, strip = TRUE, drop_london = TRUE),
    `Stripped, 2024` = pay_seller_measures(pay, 2024, strip = TRUE))
  long <- bind_rows(versions, .id = 'version')

  # Division-level comparators: business-to-business share of sales and export share (input-output tables),
  # round 1's sparsity (employment-weighted mean of SIC 3-digit SK), employment
  io <- io_tables(); p <- io$products
  links <- io_cpa_links(p$cpa) %>% mutate(sic2 = substr(code, 1, 2)) %>% distinct(cpa, sic2)
  io_div <- links %>% inner_join(p %>% select(cpa, sales_intermediate, fd_exports, total_use), by = 'cpa') %>%
    group_by(sic2) %>% summarise(b2b_share = sum(sales_intermediate) / sum(total_use),
                                 export_share = sum(fd_exports) / sum(total_use), .groups = 'drop')
  sk_div <- uk_sectors %>% mutate(sic2 = substr(sic3, 1, 2)) %>% group_by(sic2) %>%
    summarise(SK = weighted.mean(SK, L_s), SK_exLondon = weighted.mean(SK_exLondon, L_s), employees = sum(L_s), .groups = 'drop')
  main <- versions[['Intermediaries stripped']] %>%
    left_join(versions[['Stripped, without London']] %>% select(sic2, index_noLondon = index, other_noLondon = other_share), by = 'sic2') %>%
    left_join(versions[['Raw']] %>% select(sic2, index_raw = index, other_raw = other_share), by = 'sic2') %>%
    left_join(versions[['Stripped, 2024']] %>% select(sic2, index_2024 = index), by = 'sic2') %>%
    left_join(io_div, by = 'sic2') %>% left_join(sk_div, by = 'sic2') %>%
    left_join(scot_ruk %>% select(sic2, scot_ruk_share = ruk_share), by = 'sic2') %>%
    mutate(group = io_group_sic2(as.integer(sic2)))

  # Scotland's sellers in the payments, for the validation
  scot_pay <- pay %>% filter(year == 2019, !payer_sic %in% c(pay_not_industries, pay_intermediaries),
                             !payee_sic %in% pay_not_industries, payer_region != 'unknown', payee_region == 'TLM') %>%
    group_by(sic2 = payee_sic) %>% summarise(income = sum(value), from_ruk = sum(value[payer_region != 'TLM']), .groups = 'drop') %>%
    mutate(pay_ruk_share = from_ruk / income) %>%
    inner_join(scot_ruk, by = 'sic2')

  cr <- function(x, y, w = NULL, method = 'pearson') { ok <- is.finite(x) & is.finite(y); cor(x[ok], y[ok], method = method) }
  b2b <- main %>% filter(b2b_share >= 0.3)
  correlations <- tibble(
    pair = c('index with SK (all divisions)', 'index with SK (B2B share 30%+)', 'index with export share (B2B 30%+)',
             'index with B2B share', 'index, stripped against raw', 'index, with and without London',
             'index, 2019 against 2024', 'Scotland: payments RUK share against IO RUK share',
             'Scotland: same, Spearman'),
    r = c(cr(main$index, main$SK), cr(b2b$index, b2b$SK), cr(b2b$index, b2b$export_share), cr(main$index, main$b2b_share),
          cr(main$index, main$index_raw), cr(main$index, main$index_noLondon), cr(main$index, main$index_2024),
          cr(scot_pay$pay_ruk_share, scot_pay$ruk_share), cr(scot_pay$pay_ruk_share, scot_pay$ruk_share, method = 'spearman')),
    n = c(sum(is.finite(main$index) & is.finite(main$SK)), sum(is.finite(b2b$index) & is.finite(b2b$SK)),
          sum(is.finite(b2b$index) & is.finite(b2b$export_share)), sum(is.finite(main$index) & is.finite(main$b2b_share)),
          nrow(main), sum(is.finite(main$index_noLondon)), sum(is.finite(main$index_2024)), nrow(scot_pay), nrow(scot_pay)))

  # Round 1's regression with a business-to-business tradability bias: each area's employment-weighted
  # mean of its sectors' index (each SIC 3-digit sector takes its division's value)
  idx3 <- tibble(sic3 = colnames(uk_E)) %>% mutate(sic2 = substr(sic3, 1, 2)) %>% left_join(main %>% select(sic2, index, index_noLondon), by = 'sic2')
  areas <- uk_areas %>% mutate(TB_b2b = uk_bias(uk_E, idx3$index), TB_b2b_noLondon = uk_bias(uk_E, idx3$index_noLondon))
  fit <- function(d, y, xs) {
    f <- summary(lm(reformulate(xs, y), data = d))
    tibble(outcome = y, regressors = paste(xs, collapse = ' + '), term = rownames(f$coefficients)[-1],
           coef = f$coefficients[-1, 1], t = f$coefficients[-1, 3], adj_r2 = f$adj.r.squared, n = nrow(d))
  }
  regs <- bind_rows(lapply(c('w_i', 'area_diff'), function(y) bind_rows(
    fit(areas, y, 'SB'), fit(areas, y, 'TB_b2b'), fit(areas, y, c('SB', 'TB_b2b')), fit(areas, y, c('SB', 'TB_b2b_noLondon')),
    fit(filter(areas, !london), y, c('SB', 'TB_b2b')) %>% mutate(regressors = paste(regressors, '(excluding London)')))))
  cor_areas <- tibble(pair = c('area SB with TB_b2b', 'area SB with TB_exports', 'area TB_b2b with TB_exports'),
                      r = c(cor(areas$SB, areas$TB_b2b), cor(areas$SB, areas$TB_exports), cor(areas$TB_b2b, areas$TB_exports)))

  # The eight interregional-trade groups: trade between regions as a share of output (input-output
  # tables; imputed rent left out), against the payment index, sparsity and the international export share
  out_div <- links %>% inner_join(links %>% count(cpa, name = 'k'), by = 'cpa') %>%
    inner_join(p %>% filter(cpa != 'CPA_L68A') %>% select(cpa, output, fd_exports, total_use), by = 'cpa') %>%
    group_by(sic2) %>% summarise(output = sum(output / k), exports = sum(fd_exports / k), .groups = 'drop')
  groups8 <- main %>% select(sic2, income_bn, index, index_noLondon, SK, employees) %>%
    full_join(out_div, by = 'sic2') %>% mutate(industry_group = irt_group_of_sic2(sic2)) %>% filter(!is.na(industry_group)) %>%
    group_by(industry_group) %>%
    summarise(index = weighted.mean(index, income_bn, na.rm = TRUE), index_noLondon = weighted.mean(index_noLondon, income_bn, na.rm = TRUE),
              SK = weighted.mean(SK, employees, na.rm = TRUE), output_m = sum(output), intl_exports_m = sum(exports), .groups = 'drop') %>%
    left_join(irt, by = 'industry_group') %>% left_join(irt_sections, by = 'industry_group') %>%
    mutate(interregional_share = exports_m / output_m, international_share = intl_exports_m / output_m)
  # Wholesale and retail trade is valued at sales, but their output in the tables is the margin, so their
  # shares exceed 1 and aren't comparable: the correlations use the other six groups
  g6 <- groups8 %>% filter(!industry_group %in% c('Wholesale and motor trades', 'Retail (excluding motor trades)'))
  correlations <- bind_rows(correlations, tibble(
    pair = c('6 groups: interregional share with payment index', '6 groups: interregional share with SK',
             '6 groups: interregional share with international export share',
             '6 groups: Spearman, interregional share with SK'),
    r = c(cr(g6$interregional_share, g6$index), cr(g6$interregional_share, g6$SK),
          cr(g6$interregional_share, g6$international_share), cr(g6$interregional_share, g6$SK, method = 'spearman')),
    n = nrow(g6)))

  suppression <- pay %>% filter(year %in% c(2019, 2024)) %>% group_by(year) %>%
    summarise(cells = n(), published_months = sum(months_published), suppressed_months = sum(months_suppressed),
              value_bn = sum(value) / 1e9, .groups = 'drop') %>%
    mutate(share_months_suppressed = suppressed_months / (published_months + suppressed_months))

  # Coverage: published, stripped payment income against domestic intermediate sales in the tables
  int_div <- links %>% inner_join(links %>% count(cpa, name = 'k'), by = 'cpa') %>%
    inner_join(p %>% select(cpa, sales_intermediate), by = 'cpa') %>% group_by(sic2) %>%
    summarise(intermediate_bn = sum(sales_intermediate / k) / 1e3, .groups = 'drop')
  coverage <- main %>% select(sic2, group, income_bn) %>% inner_join(int_div, by = 'sic2') %>% mutate(coverage = income_bn / intermediate_bn)

  list(long = long, main = main, scot_pay = scot_pay, correlations = correlations, regs = regs, cor_areas = cor_areas,
       groups8 = groups8, coverage = coverage,
       areas = areas %>% select(area, area_name, london, w_i, area_diff, SB, TB_exports, TB_b2b, TB_b2b_noLondon),
       suppression = suppression)
}, depends = c(t4_deps, 'code/tradeable_jobs/functions_uk.R', 'code/tradeable_jobs/09_uk_sparsity.R'))

tj_write(t4$main, 't4_division_tradability.csv')
tj_write(t4$long, 't4_division_tradability_versions.csv')
tj_write(t4$correlations, 't4_correlations.csv')
tj_write(t4$regs, 't4_regressions.csv')
tj_write(t4$scot_pay %>% select(sic2, pay_ruk_share, ruk_share, income, output), 't4_scotland_validation.csv')
tj_write(t4$suppression, 't4_suppression.csv')
tj_write(t4$groups8, 't4_interregional_groups.csv')
tj_write(t4$coverage, 't4_payment_coverage.csv')
