# Model E: the UK replication of Rice and Venables (2023) section 4, plus the extra tests in step 8 of
# the plan. Areas: the 163 GB areas of the paper (ITL3, i.e. NUTS 2016 level 3, with the six Highlands
# and Islands areas merged into their ITL2 area UKM6 because ASHE samples there are small). Sectors: SIC
# 2007 3-digit groups with an ASHE mean hourly pay, excluding sections T and U. Years 2015-2019 averaged,
# earnings in 2015 prices using the GDP deflator.

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_uk.R')
uk_deps <- c('code/tradeable_jobs/functions_uk.R', 'code/tradeable_jobs/09_uk_sparsity.R')

highlands_islands <- c('UKM61', 'UKM62', 'UKM63', 'UKM64', 'UKM65', 'UKM66')

uk_data <- tj_cached('uk_data', {
  defl <- uk_deflator()
  bres <- uk_bres() %>% filter(!substr(sic3, 1, 2) %in% c('97', '98', '99')) %>%
    mutate(area = ifelse(nuts3 %in% highlands_islands, 'UKM6', nuts3),
           area_name = ifelse(nuts3 %in% highlands_islands, 'Highlands and Islands', nuts3_name))
  area_ashe <- uk_ashe_area() %>% left_join(defl, by = 'year') %>% mutate(real = mean * to_2015)
  sector_ashe <- uk_ashe_sector() %>% left_join(defl, by = 'year') %>% mutate(real = mean * to_2015)
  areas <- bres %>% distinct(area, area_name)
  w_area <- area_ashe %>% filter(code %in% areas$area) %>% group_by(area = code) %>%
    summarise(w_i = mean(real, na.rm = TRUE), years_used = sum(!is.na(real)), .groups = 'drop')
  w_sector <- sector_ashe %>% group_by(sic3) %>%
    summarise(w_s = mean(real, na.rm = TRUE), years_used = sum(!is.na(real)), sector_name = first(description), .groups = 'drop') %>%
    filter(is.finite(w_s))
  emp <- bres %>% filter(sic3 %in% w_sector$sic3) %>% group_by(area, area_name, sic3, year) %>%
    summarise(employees = sum(employees), .groups = 'drop') %>%
    group_by(area, area_name, sic3) %>% summarise(L = mean(employees), .groups = 'drop')
  list(emp = emp, w_area = w_area, w_sector = w_sector, deflator = defl,
       export_share = uk_export_share_sic3(w_sector$sic3, uk_export_share()))
}, depends = uk_deps)

# Matrices: areas in rows, sectors in columns
uk_emp_mat <- uk_data$emp %>% select(area, sic3, L) %>% pivot_wider(names_from = sic3, values_from = L, values_fill = 0)
uk_E <- as.matrix(uk_emp_mat[, -1]); rownames(uk_E) <- uk_emp_mat$area
uk_E <- uk_E[, colSums(uk_E) > 0]          # sectors with an ASHE mean but no GB employees in BRES
uk_areas <- tibble(area = rownames(uk_E)) %>% left_join(distinct(uk_data$emp, area, area_name), by = 'area') %>%
  left_join(uk_data$w_area, by = 'area') %>% mutate(london = substr(area, 1, 3) == 'UKI', L_i = rowSums(uk_E))
uk_sectors <- tibble(sic3 = colnames(uk_E)) %>% left_join(uk_data$w_sector, by = 'sic3') %>%
  left_join(uk_data$export_share, by = 'sic3') %>% mutate(L_s = colSums(uk_E))
stopifnot(!anyNA(uk_areas$w_i), !anyNA(uk_sectors$w_s))

# Sparsity measures (plan 2.2). which_rows lets the sector measure be computed without London.
uk_sector_measures <- function(E, which_rows = rep(TRUE, nrow(E))) {
  E <- E[which_rows, , drop = FALSE]
  s <- sweep(E, 2, pmax(colSums(E), 1e-12), '/'); x <- rowSums(E) / sum(E)
  tibble(SK = apply(s - x, 2, tj_skew), SD = apply(s - x, 2, sd),
         SK_LQ = apply(s / x, 2, tj_skew), SK_logLQ = apply(log(s / x + 1), 2, tj_skew))
}
uk_bias <- function(E, measure) as.vector((E / rowSums(E)) %*% ifelse(is.finite(measure), measure, 0))

sm <- uk_sector_measures(uk_E)
uk_sectors <- bind_cols(uk_sectors, sm) %>% mutate(SK_exLondon = uk_sector_measures(uk_E, !uk_areas$london)$SK)
lam <- uk_E / rowSums(uk_E)
w_bar <- sum(uk_areas$w_i * uk_areas$L_i) / sum(uk_areas$L_i)          # national average (employment weighted)
uk_areas <- uk_areas %>% mutate(
  w_tilde = as.vector(lam %*% uk_sectors$w_s),
  sector_diff = w_tilde - w_bar, area_diff = w_i - w_tilde,
  SB = uk_bias(uk_E, uk_sectors$SK), SB_SD = uk_bias(uk_E, uk_sectors$SD), SB_LQ = uk_bias(uk_E, uk_sectors$SK_LQ),
  SB_logLQ = uk_bias(uk_E, uk_sectors$SK_logLQ), SB_exLondon = uk_bias(uk_E, uk_sectors$SK_exLondon),
  TB_exports = uk_bias(uk_E, uk_sectors$export_share),
  krugman = rowSums(abs(lam - matrix(colSums(uk_E) / sum(uk_E), nrow(lam), ncol(lam), byrow = TRUE))))

# Alternative decomposition (paper section 4.3, Table 5): w_is = w_bar (d_i + d_s); solve the N + S
# equations for area and sector average earnings by least squares, with employment-weighted mean d_i = 0
uk_alt <- local({
  theta <- sweep(uk_E, 2, colSums(uk_E), '/')
  N <- nrow(uk_E); S <- ncol(uk_E)
  A <- rbind(cbind(diag(N), lam), cbind(t(theta), diag(S)), c(uk_areas$L_i / sum(uk_areas$L_i), rep(0, S)))
  b <- c(uk_areas$w_i, uk_sectors$w_s, 0) / w_bar
  d <- qr.solve(A, b)
  sector_alt <- w_bar * as.vector(lam %*% d[N + 1:S])
  tibble(area = uk_areas$area, sector_diff_alt = sector_alt - w_bar, area_diff_alt = uk_areas$w_i - sector_alt)
})
uk_areas <- uk_areas %>% left_join(uk_alt, by = 'area')

# TABLES ----
desc <- function(x, label) tibble(variable = label, mean = mean(x), median = median(x), variance = var(x), min = min(x), max = max(x))
uk_table3 <- bind_rows(
  desc(uk_areas$w_i, 'ITL3 area mean hourly earnings, w_i'),
  desc(uk_sectors$w_s, 'SIC3 sector mean hourly earnings, w_s'),
  desc(uk_areas$sector_diff, 'Sector differential'),
  desc(uk_areas$area_diff, 'Area differential')) %>% mutate(source = 'rebuild') %>%
  bind_rows(tibble(variable = c('ITL3 area mean hourly earnings, w_i', 'SIC3 sector mean hourly earnings, w_s', 'Sector differential', 'Area differential'),
                   mean = c(14.87, 15.65, -0.9474, 0.1019), median = c(14.31, 14.96, -1.0493, -0.3214), variance = c(5.174, 17.61, 0.576, 2.711),
                   min = c(12.01, 8.10, -2.32, -1.83), max = c(28.41, 34.49, 3.23, 9.83), source = 'paper'))

vshare <- function(d) tibble(sector_share = var(d$sector_diff) / var(d$w_i), area_share = var(d$area_diff) / var(d$w_i),
                             covariance_share = 2 * cov(d$sector_diff, d$area_diff) / var(d$w_i))
uk_variance <- bind_rows(vshare(uk_areas) %>% mutate(sample = 'All 163 areas'),
                         vshare(filter(uk_areas, !london)) %>% mutate(sample = 'Excluding London')) %>%
  mutate(source = 'rebuild') %>%
  bind_rows(tibble(sample = c('All 163 areas', 'Excluding London'), sector_share = c(0.11, 0.20), area_share = c(0.52, 0.47), source = 'paper'))

reg_set <- function(d, sb, tag) bind_rows(
  uk_reg(d$w_i, d[[sb]], 'Mean hourly earnings'),
  uk_reg(d$sector_diff, d[[sb]], 'Sector differential'),
  uk_reg(d$area_diff, d[[sb]], 'Area differential'),
  uk_reg(d$sector_diff_alt, d[[sb]], 'Sector differential (alternative decomposition)'),
  uk_reg(d$area_diff_alt, d[[sb]], 'Area differential (alternative decomposition)')) %>% mutate(measure = tag, .before = 1)

uk_table4 <- bind_rows(
  reg_set(uk_areas, 'SB', 'Sparsity bias (skewness, as paper)') %>% mutate(sample = 'All'),
  reg_set(filter(uk_areas, !london), 'SB', 'Sparsity bias (skewness, as paper)') %>% mutate(sample = 'Excluding London'),
  reg_set(uk_areas, 'SB_exLondon', 'Sparsity bias, sector skewness computed without London') %>% mutate(sample = 'All'),
  reg_set(filter(uk_areas, !london), 'SB_exLondon', 'Sparsity bias, sector skewness computed without London') %>% mutate(sample = 'Excluding London'),
  reg_set(uk_areas, 'SB_SD', 'Sparsity bias (standard deviation)') %>% mutate(sample = 'All'),
  reg_set(uk_areas, 'SB_LQ', 'Sparsity bias (skewness of location quotient)') %>% mutate(sample = 'All'),
  reg_set(uk_areas, 'SB_logLQ', 'Sparsity bias (skewness of log(LQ + 1))') %>% mutate(sample = 'All'),
  reg_set(uk_areas, 'TB_exports', 'Export-share bias (input-output tables)') %>% mutate(sample = 'All'),
  reg_set(filter(uk_areas, !london), 'TB_exports', 'Export-share bias (input-output tables)') %>% mutate(sample = 'Excluding London'))

uk_table4_paper <- tribble(
  ~measure, ~sample, ~model, ~coef, ~t, ~adj_r2,
  'Sparsity bias (skewness, as paper)', 'All', 'Mean hourly earnings', 2.7180, 10.06, 0.7413,
  'Sparsity bias (skewness, as paper)', 'All', 'Sector differential', 0.9552, 14.42, 0.8177,
  'Sparsity bias (skewness, as paper)', 'All', 'Area differential', 1.7628, 7.69, 0.5939,
  'Sparsity bias (skewness, as paper)', 'All', 'Sector differential (alternative decomposition)', 0.7164, 11.37, 0.7305,
  'Sparsity bias (skewness, as paper)', 'All', 'Area differential (alternative decomposition)', 2.0016, 8.40, 0.6325,
  'Sparsity bias (skewness, as paper)', 'Excluding London', 'Mean hourly earnings', 1.9144, 11.82, 0.5387,
  'Sparsity bias (skewness, as paper)', 'Excluding London', 'Sector differential', 0.9742, 17.54, 0.7144,
  'Sparsity bias (skewness, as paper)', 'Excluding London', 'Area differential', 0.9402, 6.94, 0.2752)

# Horse race: sparsity bias and export-share bias together, and the Krugman specialisation index
uk_horse_race <- bind_rows(lapply(c('w_i', 'area_diff'), function(y) {
  bind_rows(lapply(list(c('SB', 'TB_exports'), c('SB', 'krugman')), function(xs) {
    f <- summary(lm(reformulate(xs, y), data = uk_areas))
    tibble(outcome = y, regressors = paste(xs, collapse = ' + '), term = rownames(f$coefficients)[-1],
           coef = f$coefficients[-1, 1], t = f$coefficients[-1, 3], adj_r2 = f$adj.r.squared)
  }))
}))

uk_correlations <- tibble(
  statistic = c('cor(sector sparsity SK_s, sector mean earnings w_s)', 'cor(area sparsity bias, area earnings)',
                'cor(area sparsity bias, area earnings), excluding London', 'cor(sector sparsity SK_s, export share)',
                'Spearman cor(sector sparsity SK_s, export share)', 'cor(SK_s with London, SK_s without London)',
                'cor(area sparsity bias, export-share bias)'),
  rebuild = c(cor(uk_sectors$SK, uk_sectors$w_s), cor(uk_areas$SB, uk_areas$w_i),
              with(filter(uk_areas, !london), cor(SB, w_i)),
              cor(uk_sectors$SK, uk_sectors$export_share, use = 'complete.obs'),
              cor(uk_sectors$SK, uk_sectors$export_share, use = 'complete.obs', method = 'spearman'),
              cor(uk_sectors$SK, uk_sectors$SK_exLondon, use = 'complete.obs'),
              cor(uk_areas$SB, uk_areas$TB_exports)),
  paper = c(0.46, 0.86, 0.74, NA, NA, NA, NA))

uk_sb_summary <- bind_rows(
  tibble(source = 'rebuild', mean = mean(uk_areas$SB), median = median(uk_areas$SB), sd = sd(uk_areas$SB), min = min(uk_areas$SB), max = max(uk_areas$SB)),
  tibble(source = 'paper', mean = 0.961, median = 0.765, sd = 0.721, min = 0.127, max = 4.845))

uk_extremes <- list(
  most_sparse_sectors = uk_sectors %>% arrange(desc(SK)) %>% select(sic3, sector_name, SK, export_share, w_s) %>% head(12),
  least_sparse_sectors = uk_sectors %>% arrange(SK) %>% select(sic3, sector_name, SK, export_share, w_s) %>% head(12),
  highest_SB_areas = uk_areas %>% arrange(desc(SB)) %>% select(area, area_name, SB, w_i) %>% head(8),
  lowest_SB_areas = uk_areas %>% arrange(SB) %>% select(area, area_name, SB, w_i) %>% head(8))

tj_write(uk_areas, 'uk_areas.csv')
tj_write(uk_sectors, 'uk_sectors.csv')
tj_write(uk_table3, 'uk_table3.csv')
tj_write(uk_variance, 'uk_variance_decomposition.csv')
tj_write(uk_table4, 'uk_regressions.csv')
tj_write(uk_table4_paper, 'uk_regressions_paper.csv')
tj_write(uk_horse_race, 'uk_horse_race.csv')
tj_write(uk_correlations, 'uk_correlations.csv')
cat('Areas:', nrow(uk_areas), ' sectors:', nrow(uk_sectors), '\n')
print(as.data.frame(uk_table3 %>% mutate(across(where(is.numeric), ~ round(.x, 3)))))
print(uk_variance)
print(uk_sb_summary)
print(as.data.frame(uk_correlations %>% mutate(across(where(is.numeric), ~ round(.x, 3)))))
print(as.data.frame(uk_table4 %>% filter(measure == 'Sparsity bias (skewness, as paper)') %>% select(sample, model, coef, t, adj_r2) %>% mutate(across(where(is.numeric), ~ round(.x, 3)))))
print(uk_extremes)
