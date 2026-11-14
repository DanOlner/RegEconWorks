# Round 2, test T2: Domar weights against tradability, from the UK input-output analytical tables
# (2019, product by product). Which products carry the most national gain per 1% productivity gain,
# how tradable are they, and where does a gain in each one end up?
#
# Hulten (1978): to first order, a 1% gain in a product's (gross-output) productivity raises real
# GDP by its Domar weight, gross output over GDP, whoever buys the product. Here:
#   - Domar weight = output / total GVA at basic prices (£2,000bn), so weights sum to about 1.9.
#     The net weight leaves out a product's (or group's) sales to itself: construction sells a third
#     of its output to construction and utilities 42% to utilities, so the gross weight overstates
#     what a like-for-like "1% gain in the sector" is worth. Both give the same gain for the same
#     physical change; they differ in what "1%" means;
#   - where the gain lands: a 1% cost fall in product j lowers the price of each final product k by
#     L[j, k] %, so final buyers of k gain L[j, k] * FD[k]. Summed over k this is exactly output[j].
#     Splitting FD by buyer (households, government and NPISH, investment, exports) gives the share
#     of j's gain that lands on each; the export part is j's "embodied export share";
#   - linkages: backward = column sums of the Leontief inverse; forward = row sums of the Ghosh
#     inverse, which is also Antràs et al.'s (2012) upstreamness without the open-economy correction;
#   - employment: BRES 2019 GB employees (the tables are UK-wide, so GVA per job is about 3% too high
#     everywhere; BRES leaves out the self-employed and farm agriculture, which matters for
#     construction, agriculture and personal services);
#   - sparsity: round 1's sector skewness SK (09_uk_sparsity.R), carried to products by employment.
#
# Outputs: t2_products.csv (105 products), t2_groups.csv (19 groups plus the left-out products),
# t2_group_coefficients.csv and t2_group_final_demand.csv (for Model F), t2_summary.csv.

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_uk.R')
source('code/tradeable_jobs/functions_io.R')

t2 <- tj_cached('t2_domar', {
  io <- io_tables()
  p <- io$products
  fd_cols <- c(households = 'fd_households', government = 'fd_government', investment = 'fd_investment', exports = 'fd_exports')
  FD <- as.matrix(p[, fd_cols])
  dest <- (io$L %*% FD) / p$output                        # share of each product's gain landing on each buyer
  colnames(dest) <- paste0('dest_', names(fd_cols))
  stopifnot(max(abs(rowSums(dest) - 1)) < 1e-8)
  fd_total <- rowSums(FD)
  gdp <- sum(p$gva)

  # employment and round 1's sparsity, carried from SIC groups to products
  alloc <- io_allocation(p$cpa, p$gva)
  sk <- read_csv(file.path(tj_output_dir, 'uk_sectors.csv'), col_types = cols(sic3 = 'c', .default = 'd', sector_name = 'c',
                                                                              export_share_level = 'c')) %>%
    select(sic3, SK, SK_exLondon)
  emp <- alloc %>% group_by(cpa) %>% summarise(employees = sum(emp_alloc), .groups = 'drop')
  sk_p <- alloc %>% inner_join(sk, by = 'sic3') %>% filter(emp_alloc > 0) %>% group_by(cpa) %>%
    summarise(SK = weighted.mean(SK, emp_alloc), SK_exLondon = weighted.mean(SK_exLondon, emp_alloc),
              sk_emp_covered = sum(emp_alloc), .groups = 'drop')

  products <- p %>%
    mutate(group = io_groups(cpa)) %>% left_join(io_group_labels, by = 'group') %>%
    left_join(emp, by = 'cpa') %>% left_join(sk_p, by = 'cpa') %>%
    mutate(employees = coalesce(employees, 0),
           domar = output / gdp, va_share = gva / gdp, va_ratio = gva / output,
           own_use = diag(io$Z) / output, domar_net = (output - diag(io$Z)) / gdp,
           b2b_share = sales_intermediate / total_use,
           export_share = fd_exports / total_use, household_share = fd_households / total_use,
           government_share = fd_government / total_use, investment_share = fd_investment / total_use,
           import_penetration = imports / (output + imports),
           own_final_share = diag(io$L) * fd_total / output,  # gain landing on final buyers of the product itself
           backward = colSums(io$L) / mean(colSums(io$L)),
           upstreamness = rowSums(io$G), forward = upstreamness / mean(upstreamness),
           gva_per_job = ifelse(employees > 0, 1e6 * gva / employees, NA_real_),
           output_per_job = ifelse(employees > 0, 1e6 * output / employees, NA_real_)) %>%
    bind_cols(as_tibble(dest)) %>%
    mutate(reach = case_when(
      group == 'excluded' ~ 'Left out',
      export_share >= 0.25 ~ 'International',
      b2b_share >= 0.5 ~ 'Business to business',
      household_share >= 0.5 ~ 'Households',
      government_share >= 0.5 ~ 'Government',
      investment_share >= 0.5 ~ 'Investment',
      TRUE ~ 'Mixed'))

  # groups: sums, then the same shares; upstreamness and backward linkage weighted by output,
  # sparsity by employment
  # (weighted means come first: summarise() would otherwise weight by the already-summed output)
  groups <- products %>% group_by(group, group_name, foundational, limit) %>%
    summarise(upstreamness = weighted.mean(upstreamness, output), backward = weighted.mean(backward, output),
              across(starts_with('dest_'), ~ weighted.mean(.x, output)),
              SK = if (any(!is.na(SK))) weighted.mean(SK[!is.na(SK)], sk_emp_covered[!is.na(SK)]) else NA_real_,
              n_products = n(), output = sum(output), gva = sum(gva), coe = sum(coe), gos = sum(gos),
              employees = sum(employees), sales_intermediate = sum(sales_intermediate),
              across(c(fd_households, fd_government, fd_investment, fd_exports, total_use, imports), sum),
              .groups = 'drop') %>%
    mutate(domar = output / gdp, va_share = gva / gdp, emp_share = employees / sum(employees),
           va_ratio = gva / output, labour_share_va = coe / gva,
           b2b_share = sales_intermediate / total_use, export_share = fd_exports / total_use,
           household_share = fd_households / total_use, government_share = fd_government / total_use,
           import_penetration = imports / (output + imports),
           gva_per_job = 1e6 * gva / employees, output_per_job = 1e6 * output / employees) %>%
    arrange(desc(domar))

  # Model F inputs: intermediate inputs per £ of output, group by group (domestic and imported), and
  # the rest of the cost structure
  gi <- products$group
  agg <- function(X) {                                     # sum a product-by-product matrix to groups
    rs <- rowsum(X, gi); t(rowsum(t(rs), gi))
  }
  out_g <- c(tapply(products$output, gi, sum))
  Zg <- agg(io$Z); Mg <- agg(io$M)
  # a group's Domar weight net of its sales to itself: the like-for-like weight for a 1% gain in the group
  groups <- groups %>% mutate(within_group = diag(Zg)[group] / output,
                              domar_net = (output - diag(Zg)[group]) / gdp) %>% relocate(domar_net, .after = domar)
  coefficients <- expand_grid(from = rownames(Zg), to = colnames(Zg)) %>%
    mutate(domestic = unname(Zg[cbind(from, to)] / out_g[to]), imported = unname(Mg[cbind(from, to)] / out_g[to]),
           total = domestic + imported)
  cost_structure <- products %>% group_by(to = group) %>%
    summarise(output = sum(output), compensation = sum(coe) / output, surplus = sum(gos) / output,
              gva = sum(gva) / output, inputs_domestic = sum(inputs_domestic) / output,
              inputs_imported = sum(inputs_imported) / output, .groups = 'drop') %>%
    mutate(taxes_and_other = 1 - gva - inputs_domestic - inputs_imported)
  final_demand <- products %>% group_by(group) %>%
    summarise(across(c(fd_households, fd_government, fd_investment, fd_exports, imports), sum), .groups = 'drop')

  # headline numbers: national gain per 1% gain, by foundational type and by market reach
  by_type <- function(var) products %>% group_by(across(all_of(var))) %>%
    summarise(n_products = n(), domar = sum(domar), domar_net = sum(domar_net), va_share = sum(va_share),
              employees = sum(employees),
              exports_embodied = sum(dest_exports * output) / gdp, .groups = 'drop') %>%
    mutate(emp_share = employees / sum(employees), dimension = var) %>% rename(class = 1)
  summary <- bind_rows(by_type('foundational'), by_type('reach'), by_type('limit'))

  checks <- tibble(
    check = c('max |L - ONS Leontief|', 'max |output - L x final demand|', 'max |shares to buyers - 1|',
              'total output £m', 'total GVA £m', 'total exports £m', 'BRES employees allocated',
              'products with SK'),
    value = c(max(abs(io$L - io$L_ons)), max(abs(p$output - io$L %*% fd_total)),
              max(abs(rowSums(dest) - 1)), sum(p$output), gdp, sum(p$fd_exports),
              sum(products$employees), sum(!is.na(products$SK))))

  list(products = products, groups = groups, coefficients = coefficients, cost_structure = cost_structure,
       final_demand = final_demand, summary = summary, checks = checks, gdp = gdp)
}, depends = c('code/tradeable_jobs/functions_uk.R', 'code/tradeable_jobs/functions_io.R',
               'code/tradeable_jobs/12_t2_domar_tradability.R', file.path(tj_output_dir, 'uk_sectors.csv')))

list2env(setNames(t2[c('products', 'groups', 'coefficients', 'cost_structure', 'final_demand', 'summary', 'checks')],
                  paste0('t2_', c('products', 'groups', 'coefficients', 'cost_structure', 'final_demand', 'summary', 'checks'))),
         envir = environment())

tj_write(t2_products %>% select(cpa, name, group, foundational, limit, reach, domar, domar_net, own_use, va_share,
                                va_ratio, employees,
                                gva_per_job, output_per_job, b2b_share, export_share, household_share, government_share,
                                investment_share, import_penetration, starts_with('dest_'), own_final_share,
                                upstreamness, forward, backward, SK, SK_exLondon, output, gva, coe, gos),
         't2_products.csv')
tj_write(t2_groups, 't2_groups.csv')
tj_write(t2_coefficients %>% left_join(t2_cost_structure %>% select(to, compensation, surplus, gva, taxes_and_other),
                                       by = 'to'), 't2_group_coefficients.csv')
tj_write(t2_final_demand, 't2_group_final_demand.csv')
tj_write(t2_summary, 't2_summary.csv')
tj_write(t2_checks, 't2_checks.csv')
