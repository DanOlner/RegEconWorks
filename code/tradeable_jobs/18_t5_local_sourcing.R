# Round 2, test T5 (limited version): do foundational sectors buy more locally than tradables?
# The plan's version builds regional coefficient matrices from the payment flows and computes local
# multipliers. T4 showed the payments cover too little of business-to-business trade for that (a median
# of 16% of a division's intermediate sales), so this version keeps to a ratio within each buying sector:
# the share of its business spending paid to suppliers in its own ITL1 region, against the share it would
# be with no home bias. Both payer and payee intermediaries are dropped, as are unknown industries and
# regions. Own-region shares are "the trustworthy half" of the payment data (RegionalEconomicTools'
# caveats note): when both parties are local, intermediary geography can't distort them.
#   own_share       sum over regions of own-region spending / all spending, pooled across regions
#   expected_own    sum_r spend_r q_r / spend, with q_r region r's share of all payments to suppliers of
#                   the buying industry's purchases... approximated by region r's share of all payments
#                   received by the industries the buyer buys from (weighted by the buyer's purchase mix)
#   index           own_share / expected_own (1 = no home bias; above 1 = buys locally)
# No household spending (not in the data), so this is a first-round, business-to-business view only.

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_io.R')
source('code/tradeable_jobs/functions_payments.R')

t5 <- tj_cached('t5_local_sourcing', {
  pay <- tj_cached('pay_yearly', pay_yearly(), depends = 'code/tradeable_jobs/functions_payments.R', key = pay_editions)
  x <- pay %>% filter(year == 2019, !payer_sic %in% c(pay_not_industries, pay_intermediaries),
                      !payee_sic %in% c(pay_not_industries, pay_intermediaries),
                      payer_region != 'unknown', payee_region != 'unknown')
  # where each supplying industry's sales come from, by region (for the no-home-bias benchmark)
  supply_reg <- x %>% group_by(payee_sic, payee_region) %>% summarise(v = sum(value), .groups = 'drop') %>%
    group_by(payee_sic) %>% mutate(q = v / sum(v)) %>% ungroup() %>% select(payee_sic, region = payee_region, q)
  cell <- x %>% group_by(payer_sic, region = payer_region, payee_sic) %>%
    summarise(spend = sum(value), own = sum(value[payee_region == payer_region]), .groups = 'drop') %>%
    left_join(supply_reg, by = c('payee_sic', 'region')) %>% mutate(q = coalesce(q, 0))
  buyers <- cell %>% group_by(sic2 = payer_sic) %>%
    summarise(spend_bn = sum(spend) / 1e9, own_share = sum(own) / sum(spend), expected_own = sum(spend * q) / sum(spend),
              .groups = 'drop') %>%
    mutate(index = own_share / expected_own, group = io_group_sic2(as.integer(sic2))) %>%
    left_join(io_group_labels, by = 'group')
  # without London as buyer or seller (London-registered head offices buy for the whole country)
  nolon <- cell %>% filter(region != 'TLI') %>% group_by(sic2 = payer_sic) %>%
    summarise(own_share_noLondon = sum(own) / sum(spend), expected_noLondon = sum(spend * q) / sum(spend), .groups = 'drop') %>%
    mutate(index_noLondon = own_share_noLondon / expected_noLondon)
  buyers <- buyers %>% left_join(nolon, by = 'sic2')
  by_type <- function(var) buyers %>% filter(!is.na(.data[[var]])) %>% group_by(class = .data[[var]]) %>%
    summarise(own_share = weighted.mean(own_share, spend_bn), index = weighted.mean(index, spend_bn),
              own_share_noLondon = weighted.mean(own_share_noLondon, spend_bn, na.rm = TRUE),
              index_noLondon = weighted.mean(index_noLondon, spend_bn, na.rm = TRUE),
              divisions = n(), spend_bn = sum(spend_bn), .groups = 'drop') %>%    # totals last
    mutate(dimension = var)
  list(buyers = buyers, by_type = bind_rows(by_type('foundational'), by_type('limit')),
       by_group = buyers %>% group_by(group, group_name, foundational, limit) %>%
         summarise(own_share = weighted.mean(own_share, spend_bn), index = weighted.mean(index, spend_bn),
                   index_noLondon = weighted.mean(index_noLondon, spend_bn, na.rm = TRUE), spend_bn = sum(spend_bn),
                   .groups = 'drop'))
}, depends = c('code/tradeable_jobs/functions_payments.R', 'code/tradeable_jobs/functions_io.R', 'code/tradeable_jobs/18_t5_local_sourcing.R'))

tj_write(t5$buyers, 't5_buyer_local_sourcing.csv')
tj_write(t5$by_type, 't5_local_sourcing_by_type.csv')
tj_write(t5$by_group, 't5_local_sourcing_by_group.csv')
