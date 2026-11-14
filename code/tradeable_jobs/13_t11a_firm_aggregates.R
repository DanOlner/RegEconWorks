# Round 2, test T11a: aggregates from the Companies House firm data, by T2's sector groups.
# What UK firms with 10+ employees show about the settings that drive the round 2 results:
#   1. dist      spread of real GVA per job within each group and size band (firm averages, 2022-24)
#   2. catchup   the "big blocks" arithmetic: GVA gained if firms below their group and size band's
#                median reached it, against the top decile gaining 10%; and the implied national gain
#   3. decomp    within, between, entry and exit, 2019 to 2024 (Melitz-Polanec), for the UK, each group
#                and each ITL1 region; and how far jobs moved between groups among surviving firms
#   4. respons   responsiveness: next year's jobs growth on GVA per job against the group-year mean
#   5. rent      pass-through to pay: pay per head on GVA per head, and the wage bill on GVA with jobs
#   6. place     how much of the spread in GVA per job is place, after sector; place-by-group effects
#
# Everything here is revenue productivity (GVA from the income side: pay plus EBITDA), placed at the
# registered office, for firms that tag a usable profit and loss account; real values in 2019 prices.
# Samples follow companieshouseopen's reports (gva_spatial, jobs_gva) so the pooled numbers can be
# checked against them. Cells with fewer than ch_min_firms firms are suppressed.
#
# Output: CSVs in local/tradeable_jobs/companieshouse/ (gitignored), each stamped with the build time
# of the report outputs it came from. Skipped, with a message, if those outputs aren't on this machine.

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_uk.R')
source('code/tradeable_jobs/functions_io.R')
source('code/tradeable_jobs/functions_ch.R')

ch_min_firms <- 20
size_band <- function(e) cut(e, c(9.5, 49.5, 249.5, Inf), labels = c('10-49', '50-249', '250+'))

if (!ch_available()) {
  message('T11a skipped: the Companies House report outputs are not at ', ch_reports(),
          ' (set options(tj.ch_reports = ...) if they are elsewhere)')
} else {

builds <- ch_builds()
t2_groups_tab <- read_csv(file.path(tj_output_dir, 't2_groups.csv'), show_col_types = FALSE)

t11a <- tj_cached('t11a_firms', {

  firms <- ch_read('gva_spatial', 'firms.parquet',
                   c('company_number', 'sic2', 'itl1', 'itl2', 'itl3', 'agency', 'gone', 'last_accounts_end',
                     'incorporation_date', 'b3_drop')) %>%
    mutate(group = ch_group(sic2))
  fy <- ch_read('gva_spatial', 'firm_years.parquet', c('company_number', 'year', 'usable', 'employees', 'gva_real')) %>%
    filter(usable, employees >= 10) %>%
    inner_join(firms %>% filter(!agency), by = 'company_number')
  stopifnot(!anyDuplicated(fy[c('company_number', 'year')]))

  # 1. Spread within groups and size bands: each firm's average over its usable years in 2022-24
  fa <- fy %>% filter(year %in% 2022:2024, !is.na(group), group != 'excluded') %>%
    group_by(company_number, group, sic2, itl1, itl2, itl3, b3_drop) %>%
    summarise(years = n(), jobs = mean(employees), gva = mean(gva_real), .groups = 'drop') %>%
    mutate(lp = gva / jobs, band = size_band(jobs))
  spread <- function(x) {
    q <- quantile(x$lp, c(0.1, 0.25, 0.5, 0.75, 0.9), names = FALSE)
    pos <- x$lp[x$lp > 0]
    tibble(firms = nrow(x), jobs = sum(x$jobs), gva_m = sum(x$gva) / 1e6, lp_weighted = sum(x$gva) / sum(x$jobs),
           p10 = q[1], p25 = q[2], p50 = q[3], p75 = q[4], p90 = q[5],
           sd_log = if (length(pos) > 2) sd(log(pos)) else NA_real_, share_negative = mean(x$lp <= 0))
  }
  dist <- bind_rows(
    fa %>% group_by(group, band = as.character(band)) %>% group_modify(~ spread(.x)) %>% ungroup(),
    fa %>% group_by(group) %>% group_modify(~ spread(.x)) %>% ungroup() %>% mutate(band = 'all'),
    fa %>% group_modify(~ spread(.x)) %>% mutate(group = 'all', band = 'all')) %>%
    mutate(across(c(lp_weighted, p10, p25, p50, p75, p90, sd_log, share_negative), ~ ifelse(firms < ch_min_firms, NA, .x)))

  # 2. Catch-up arithmetic. The target is the median of the firm's SIC division and size band (the
  # group and size band's median where that cell has fewer than 10 firms), so differences between
  # industries inside a group don't count as room for catch-up; the group-and-band median is kept as
  # a sensitivity. Gaps are measured from max(GVA per job, 0): a firm with negative GVA raised to the
  # median gains the median, not more
  cu <- fa %>% group_by(sic2, band) %>% mutate(n_cell = n(), med_cell = median(lp)) %>%
    group_by(group, band) %>% mutate(med_group = median(lp)) %>% ungroup() %>%
    mutate(med = if_else(n_cell >= 10, med_cell, med_group), below = lp < med, below_g = lp < med_group) %>%
    group_by(group) %>% mutate(top10 = lp >= quantile(lp, 0.9)) %>% ungroup()
  # (the totals come last: summarise() would otherwise use the summed jobs and GVA in the lines after)
  catchup <- cu %>% group_by(group) %>%
    summarise(jobs_below_median = sum(jobs[below]) / sum(jobs),
              gain_tail_to_median = sum(((med - pmax(lp, 0)) * jobs)[below]) / sum(gva),
              gain_tail_to_group_median = sum(((med_group - pmax(lp, 0)) * jobs)[below_g]) / sum(gva),
              gva_share_top10 = sum(gva[top10]) / sum(gva),
              gain_top10_plus10 = 0.1 * sum(gva[top10]) / sum(gva),
              firms = n(), gva_m = sum(gva) / 1e6, jobs = sum(jobs), .groups = 'drop') %>%
    mutate(gain_tail_halfway = gain_tail_to_median / 2,
           top10_rise_to_match_halfway = gain_tail_halfway / gva_share_top10) %>%
    left_join(t2_groups_tab %>% select(group, group_name, foundational, limit, va_share), by = 'group') %>%
    mutate(national_tail_halfway = gain_tail_halfway * va_share, national_top10_plus10 = gain_top10_plus10 * va_share) %>%
    mutate(across(c(jobs_below_median, gain_tail_to_median, gain_tail_to_group_median, gva_share_top10,
                    gain_top10_plus10, gain_tail_halfway,
                    top10_rise_to_match_halfway, national_tail_halfway, national_top10_plus10),
                  ~ ifelse(firms < ch_min_firms, NA, .x)))

  # 3. Decomposition, 2019 to 2024: as gva_spatial's "Reporters", and with real entry and exit only
  d2 <- fy %>% filter(year %in% c(2019, 2024)) %>% mutate(period = if_else(year == 2019, 1L, 2L))
  both <- d2 %>% count(company_number) %>% filter(n == 2) %>% pull(company_number)
  real_ee <- d2 %>% filter(company_number %in% both | (period == 1 & gone & last_accounts_end < as.Date('2024-01-01')) |
                             (period == 2 & incorporation_date >= as.Date('2019-01-01')))
  mp_by <- function(d, by) {
    x <- d %>% transmute(id = company_number, period, w = employees, y = gva_real, key = if (is.null(by)) 'UK' else .data[[by]])
    x %>% filter(!is.na(key)) %>% group_by(key) %>% group_modify(~ mp_terms(.x)) %>% ungroup() %>%
      mutate(level = if (is.null(by)) 'UK' else by, .before = 1)
  }
  decomp <- bind_rows(
    bind_rows(mp_by(d2, NULL), mp_by(d2, 'group'), mp_by(d2, 'itl1')) %>% mutate(version = 'Reporters'),
    bind_rows(mp_by(real_ee, NULL), mp_by(real_ee, 'group'), mp_by(real_ee, 'itl1')) %>% mutate(version = 'Real entry and exit')) %>%
    mutate(across(change:residual, ~ ifelse(n_survivors < ch_min_firms, NA, .x)))

  # Survivors only: how much of their change in GVA per job came from jobs moving between groups
  sv <- d2 %>% filter(company_number %in% both, !is.na(group)) %>% group_by(group, period) %>%
    summarise(jobs = sum(employees), gva = sum(gva_real), .groups = 'drop') %>%
    group_by(period) %>% mutate(share = jobs / sum(jobs), phi = gva / jobs) %>% ungroup() %>%
    pivot_wider(id_cols = group, names_from = period, values_from = c(jobs, share, phi)) %>%
    mutate(across(-group, ~ coalesce(.x, 0)))
  shift <- tibble(
    term = c('change', 'within groups', 'between groups', 'cross'),
    value = c(sum(sv$share_2 * sv$phi_2) - sum(sv$share_1 * sv$phi_1),
              sum(sv$share_1 * (sv$phi_2 - sv$phi_1)), sum((sv$share_2 - sv$share_1) * sv$phi_1),
              sum((sv$share_2 - sv$share_1) * (sv$phi_2 - sv$phi_1))))
  shift_groups <- sv %>% transmute(group, firms_jobs_2019 = jobs_1, jobs_2024 = jobs_2, share_2019 = share_1, share_2024 = share_2,
                                   lp_2019 = phi_1, lp_2024 = phi_2)

  # 4 and 5. Responsiveness and pass-through, on jobs_gva's year-on-year links (its default sample)
  fj <- ch_read('jobs_gva', 'firm_years.parquet', c('company_number', 'year', 'employees', 'gva', 'sic2', 'section')) %>%
    filter(employees >= 10, gva > 0) %>% mutate(group = ch_group(sic2), lp = log(gva / employees)) %>%
    group_by(section, year) %>% mutate(rel_lp_sec = lp - mean(lp), rel_size_sec = log(employees) - mean(log(employees))) %>%
    group_by(group, year) %>% mutate(rel_lp = lp - mean(lp), rel_size = log(employees) - mean(log(employees))) %>% ungroup()
  links <- ch_read('jobs_gva', 'links.parquet',
                   c('company_number', 'year', 'sic2', 'section', 'in_default', 'd_jobs', 'd_gva', 'd_per_job',
                     'd_pay_per_head', 'employee_costs0', 'employee_costs1')) %>%
    filter(in_default) %>% mutate(group = ch_group(sic2), d_wage_bill = log(employee_costs1 / employee_costs0))
  rs <- links %>% mutate(year0 = year - 1) %>%
    inner_join(fj %>% select(company_number, year0 = year, rel_lp, rel_size, rel_lp_sec, rel_size_sec), by = c('company_number', 'year0'))
  by_group <- function(d, f, min_links = 300) d %>% filter(!is.na(group), group != 'excluded') %>%
    group_by(group) %>% filter(n() >= min_links) %>% group_modify(~ ch_reg(.x, f)) %>% ungroup()
  respons <- bind_rows(
    ch_reg(rs, d_jobs ~ rel_lp_sec + rel_size_sec | section^year) %>% mutate(group = 'all (as jobs_gva: sections)'),
    ch_reg(rs %>% filter(!is.na(group)), d_jobs ~ rel_lp + rel_size | group^year) %>% mutate(group = 'all (T2 groups)'),
    by_group(rs, d_jobs ~ rel_lp + rel_size | year)) %>% filter(term %in% c('rel_lp', 'rel_lp_sec'))
  ok_r <- links %>% filter(is.finite(d_pay_per_head), is.finite(d_per_job))
  ok_w <- links %>% filter(is.finite(d_wage_bill), is.finite(d_gva), is.finite(d_jobs))
  rent <- bind_rows(
    bind_rows(ch_reg(ok_r, d_pay_per_head ~ d_per_job | section^year) %>% mutate(group = 'all (as jobs_gva: sections)'),
              by_group(ok_r, d_pay_per_head ~ d_per_job | year)) %>% mutate(model = 'pay per head on GVA per head'),
    bind_rows(ch_reg(ok_w, d_wage_bill ~ d_gva + d_jobs | section^year) %>% mutate(group = 'all (as jobs_gva: sections)'),
              by_group(ok_w, d_wage_bill ~ d_gva + d_jobs | year)) %>% filter(term == 'd_gva') %>%
      mutate(model = 'wage bill on GVA, with jobs'))

  # 6. Place after sector, on log GVA per job (firm averages 2022-24, positive GVA), leaving out firms
  # classed as having many sites (their office says little about where the work is)
  fp <- fa %>% filter(lp > 0, !coalesce(b3_drop, FALSE), !is.na(itl2), group != 'public_providential') %>%
    mutate(y = log(lp), g_itl1 = paste(group, itl1), g_itl2 = paste(group, itl2))
  r2 <- function(f) unname(fitstat(feols(f, fp, warn = FALSE, notes = FALSE), 'ar2')[[1]])
  place_r2 <- tibble(
    model = c('SIC division', '+ ITL2', '+ ITL3', 'SIC division + ITL1 x group', 'SIC division + ITL2 x group'),
    adj_r2 = c(r2(y ~ 1 | sic2), r2(y ~ 1 | sic2 + itl2), r2(y ~ 1 | sic2 + itl3),
               r2(y ~ 1 | sic2 + g_itl1), r2(y ~ 1 | sic2 + g_itl2)))
  vc <- function(f) {
    m <- lme4::lmer(f, data = fp, REML = TRUE)
    as.data.frame(lme4::VarCorr(m)) %>% transmute(term = grp, sd = sdcor, variance = vcov, share = vcov / sum(vcov))
  }
  place_vc <- bind_rows(
    vc(y ~ 1 + (1 | sic2) + (1 | itl1) + (1 | g_itl1)) %>% mutate(model = 'ITL1'),
    vc(y ~ 1 + (1 | sic2) + (1 | itl2) + (1 | g_itl2)) %>% mutate(model = 'ITL2'))
  place_n <- tibble(firms = nrow(fp), sic2 = n_distinct(fp$sic2), itl2 = n_distinct(fp$itl2), group_itl2 = n_distinct(fp$g_itl2))

  list(dist = dist, catchup = catchup, decomp = decomp, shift = shift, shift_groups = shift_groups,
       respons = respons, rent = rent, place_r2 = place_r2, place_vc = place_vc, place_n = place_n,
       n = tibble(firm_years = nrow(fy), firms_2022_24 = nrow(fa), links = nrow(links), resp_links = nrow(rs)))
}, depends = c('code/tradeable_jobs/functions_io.R', 'code/tradeable_jobs/functions_ch.R',
               'code/tradeable_jobs/13_t11a_firm_aggregates.R', file.path(tj_output_dir, 't2_groups.csv')),
   key = builds)

for (nm in names(t11a)) ch_write(t11a[[nm]], paste0('t11a_', nm, '.csv'), builds)
}
