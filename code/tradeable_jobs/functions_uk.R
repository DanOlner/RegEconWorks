# Data for the UK replication of Rice and Venables (2023) section 4 (Model E). All open data:
#   - BRES employees by NUTS 2016 level 3 (= ITL3) and SIC 2007 3-digit group, 2015-2019 (Nomis NM_189_1)
#   - ASHE workplace mean gross hourly pay by NUTS3, 2015-2019 (ONS ad hoc 12453, table 22)
#   - ASHE mean gross hourly pay by SIC 2007 3-digit, all UK employees, 2015-2019 (ASHE table 16, revised)
# Downloads go to local/tradeable_jobs/data_raw/ (gitignored).

suppressPackageStartupMessages(suppressWarnings(library(readxl)))

uk_years <- 2015:2019
ons_file <- function(path) paste0('https://www.ons.gov.uk/file?uri=', path)

# BRES: employees (employment_status 1), count, every SIC 3-digit group, NUTS 2016 level 3, by year.
# The first version paged through one big query with recordoffset. Nomis returned some pages twice and
# skipped others (2015 had 50,000 duplicated rows; 2017 and 2019 were each 25,000 rows short), which
# distorted round 1's employment shares. Now each request is one year and about half the SIC groups,
# under the 25,000-row limit, so nothing pages; and the result is checked before it's used.
uk_bres <- function(years = uk_years) {
  dest <- file.path(tj_raw_dir, 'bres_nuts3_sic3_2015_2019_v2.csv')
  if (!file.exists(dest)) {
    defs <- jsonlite::fromJSON('https://www.nomisweb.co.uk/api/v01/dataset/NM_189_1/industry.def.sdmx.json')
    codes <- defs$structure$codelists$codelist$code[[1]]
    ids <- codes$value[grepl('^\\d{3} :', codes$description$value)]
    chunks <- split(ids, ceiling(seq_along(ids) / 130))      # 168 areas x 130 groups = 21,840 rows
    parts <- list()
    for (y in years) for (ch in chunks) {
      url <- paste0('https://www.nomisweb.co.uk/api/v01/dataset/NM_189_1.data.csv?geography=TYPE437',
                    '&date=', y, '&industry=', paste(ch, collapse = ','),
                    '&employment_status=1&measure=1&measures=20100',
                    '&select=date,geography_code,geography_name,industry_name,obs_value,obs_status',
                    '&recordlimit=25000')
      part <- read_csv(url, show_col_types = FALSE, col_types = cols(.default = 'c'))
      if (nrow(part) >= 25000) stop('BRES request hit the 25,000-row limit; make the chunks smaller')
      parts[[length(parts) + 1]] <- part
      Sys.sleep(1)
    }
    out <- bind_rows(parts)
    # Checks: one row per year, area and group; every area and group present; totals match Nomis's
    # own all-industry total for the same geography (allowing for rounding of the group figures)
    key <- paste(out$DATE, out$GEOGRAPHY_CODE, out$INDUSTRY_NAME)
    if (any(duplicated(key))) stop('BRES download has duplicated rows')
    n_areas <- length(unique(out$GEOGRAPHY_CODE))
    per_year <- table(out$DATE)
    if (any(per_year != n_areas * length(ids))) stop('BRES download is missing rows: ', paste(per_year, collapse = ' '))
    for (y in years) {
      tot <- read_csv(paste0('https://www.nomisweb.co.uk/api/v01/dataset/NM_189_1.data.csv?geography=TYPE437',
                             '&date=', y, '&industry=37748736&employment_status=1&measure=1&measures=20100',
                             '&select=obs_value'), show_col_types = FALSE)
      ours <- sum(as.numeric(out$OBS_VALUE[out$DATE == y]), na.rm = TRUE)
      if (abs(ours / sum(tot$OBS_VALUE) - 1) > 0.02) stop('BRES ', y, ': groups sum to ', ours, ' against a total of ', sum(tot$OBS_VALUE))
    }
    write_csv(out, dest)
  }
  read_csv(dest, show_col_types = FALSE, col_types = cols(.default = 'c')) %>%
    transmute(year = as.integer(DATE), nuts3 = GEOGRAPHY_CODE, nuts3_name = GEOGRAPHY_NAME,
              sic3 = substr(INDUSTRY_NAME, 1, 3), sic3_name = sub('^\\d{3} : ', '', INDUSTRY_NAME),
              employees = as.numeric(OBS_VALUE), status = OBS_STATUS)
}

# Unzip an ONS zip into its own folder and return the file paths inside
uk_unzip <- function(zip, sub) {
  out <- file.path(tj_raw_dir, sub)
  if (!dir.exists(out) || !length(list.files(out, recursive = TRUE))) unzip(zip, exdir = out)
  list.files(out, recursive = TRUE, full.names = TRUE)
}

uk_ashe_table22_files <- function() {
  zip <- tj_get_file(ons_file('/employmentandlabourmarket/peopleinwork/earningsandworkinghours/adhocs/12453earningsandhoursworkedworkandhomenuts2014revisedto2020provisional/ashetable22.zip'),
                     'ashe_adhoc12453_table22.zip', expect = 'zip')
  uk_unzip(zip, 'ashe_adhoc12453_table22')
}

uk_ashe_table16_files <- function(year) {
  path <- c(`2015` = '2015/table162015revised.zip', `2016` = '2016revised/table162016revised.zip',
            `2017` = '2017revised/table162017revised.zip', `2018` = '2018revised/sic2007table162018revised.zip',
            `2019` = '2019revised/sic2007table162019revised.zip')[[as.character(year)]]
  zip <- tj_get_file(ons_file(paste0('/employmentandlabourmarket/peopleinwork/earningsandworkinghours/datasets/industry4digitsic2007ashetable16/', path)),
                     paste0('ashe_table16_', year, '.zip'), expect = 'zip')
  uk_unzip(zip, paste0('ashe_table16_', year))
}

# GDP deflator (ONS series YBGB, index), to put earnings in 2015 prices as Rice and Venables do
uk_deflator <- function(years = uk_years) {
  dest <- tj_get_file('https://www.ons.gov.uk/economy/grossdomesticproductgdp/timeseries/ybgb/qna/data',
                      'ons_ybgb_gdp_deflator.json')
  d <- jsonlite::fromJSON(dest)$years
  tibble(year = as.integer(d$year), deflator = as.numeric(d$value)) %>% filter(year %in% years) %>%
    mutate(to_2015 = deflator[year == 2015] / deflator)
}

# Read one ASHE xls sheet ('All' = all employee jobs): description, code, jobs (thousands), mean
uk_read_ashe <- function(file) {
  d <- suppressMessages(read_excel(file, sheet = 'All', col_names = FALSE, col_types = 'text'))[, 1:6]
  names(d) <- c('description', 'code', 'jobs_k', 'median', 'median_change', 'mean')
  d %>% filter(!is.na(code)) %>%
    mutate(jobs_k = suppressWarnings(as.numeric(jobs_k)), mean = suppressWarnings(as.numeric(mean)))
}

# ASHE table 22.5a (workplace, NUTS3): mean gross hourly pay by area and year
uk_ashe_area <- function(years = uk_years) {
  files <- uk_ashe_table22_files()
  bind_rows(lapply(years, function(y) {
    inner <- files[grepl(paste0('Table 22 ', y, ' revised'), files)]
    out <- file.path(tj_raw_dir, paste0('ashe_table22_', y))
    if (!dir.exists(out)) unzip(inner, exdir = out)
    f <- list.files(out, pattern = '22\\.5a.*Hourly pay - Gross', full.names = TRUE, recursive = TRUE)
    f <- f[!grepl('CV', f)][1]
    uk_read_ashe(f) %>% mutate(year = y)
  }))
}

# ASHE table 16.5a (all UK employees): mean gross hourly pay by SIC 2007 3-digit group and year.
# The tables drop leading zeros, so sections A and B (divisions 01-09) need padding: division "1" is 01,
# group "11" is 011, class "111" is 0111.
uk_ashe_sector <- function(years = uk_years) {
  bind_rows(lapply(years, function(y) {
    f <- uk_ashe_table16_files(y)
    f <- f[grepl('16\\.5a', f) & !grepl('CV', f)][1]
    d <- uk_read_ashe(f)
    section <- NA_character_; padded <- character(nrow(d))
    for (k in seq_len(nrow(d))) {
      cd <- trimws(d$code[k])
      if (grepl('^[A-Z]$', cd)) section <- cd
      padded[k] <- if (grepl('^\\d+$', cd) && section %in% c('A', 'B')) paste0('0', cd) else cd
    }
    d %>% mutate(code = padded, year = y) %>% filter(grepl('^\\d{3}$', code))
  })) %>% rename(sic3 = code)
}

# Exports as a share of total use of domestic output, by SIC 3-digit group, from the 2019 input-output
# analytical tables (product by product, domestic use). Products are mapped to SIC groups through their
# CPA codes; where a product covers a whole division (e.g. CPA_A01), every group in it gets that share.
uk_export_share <- function() {
  f <- tj_get_file('https://www.ons.gov.uk/file?uri=/economy/nationalaccounts/supplyandusetables/datasets/ukinputoutputanalyticaltablesdetailed/2019/nasu1719pr.xlsx',
                   'ioat_2019_nasu1719pr.xlsx', expect = 'xls')
  d <- suppressMessages(read_excel(f, sheet = 'IOT', col_names = FALSE, col_types = 'text'))
  hdr <- unlist(d[5, ])
  col <- function(pattern) which(grepl(pattern, hdr))[1]
  rows <- d %>% filter(grepl('^CPA_', ...1))
  num <- function(v) suppressWarnings(as.numeric(v))
  prod <- tibble(cpa = rows$...1, product = rows$...2,
                 exports = num(rows[[col('Exports of goods to EU')]]) + num(rows[[col('Exports of goods to rest')]]) +
                   num(rows[[col('Exports of services')]]),
                 total_use = num(rows[[col('Total Use at basic prices')]]))
  # Map each CPA product code to SIC 3-digit groups or 2-digit divisions
  irregular <- list(
    'CPA_B06 & B07' = c('06', '07'), 'CPA_C11.01-6 & C12' = c('110', '12'),
    'CPA_C20A' = '20', 'CPA_C20B' = '20', 'CPA_C20C' = '20', 'CPA_C23OTHER' = '23', 'CPA_C25OTHER' = '25',
    'CPA_C30OTHER' = '30', 'CPA_C33OTHER' = '33', 'CPA_F41, F42 & F43' = c('41', '42', '43'),
    'CPA_J59 & J60' = c('59', '60'), 'CPA_K65.1-2 & K65.3' = c('651', '652', '653'),
    'CPA_L68A' = character(0),                       # owner-occupiers' imputed rent: not an industry's output
    'CPA_L68BXL683' = c('681', '682'), 'CPA_Q87 & Q88' = c('87', '88'))
  map_codes <- function(cpa) {
    if (cpa %in% names(irregular)) return(irregular[[cpa]])
    s <- sub('^CPA_[A-Z]', '', cpa)
    if (grepl('T', s)) { r <- as.integer(strsplit(s, 'T')[[1]]); return(sprintf('%02d', seq(r[1], r[2]))) }
    s <- gsub('\\.', '', s); s <- gsub('[A-Z]+$', '', s)
    if (grepl('_', s)) {
      parts <- strsplit(s, '_')[[1]]; base <- parts[1]
      ends <- strsplit(parts[2], '')[[1]]
      first <- as.integer(substr(base, nchar(base), nchar(base)))
      last <- as.integer(ends[length(ends)])
      codes <- paste0(substr(base, 1, nchar(base) - 1), seq(first, last))
    } else codes <- s
    unique(ifelse(nchar(codes) >= 3, substr(codes, 1, 3), codes))
  }
  links <- bind_rows(lapply(seq_len(nrow(prod)), function(k) {
    cd <- map_codes(prod$cpa[k]); if (!length(cd)) return(NULL); tibble(cpa = prod$cpa[k], code = cd) }))
  list(products = prod, links = links)
}

# Export share for a set of SIC 3-digit groups: use products mapped to the group itself, else its division
uk_export_share_sic3 <- function(sic3, es) {
  by_code <- es$links %>% left_join(es$products, by = 'cpa') %>% distinct(cpa, code, exports, total_use)
  grp <- by_code %>% filter(nchar(code) == 3) %>% group_by(code) %>%
    summarise(exports = sum(exports), total_use = sum(total_use), .groups = 'drop')
  div <- by_code %>% mutate(division = substr(code, 1, 2)) %>% distinct(cpa, division, exports, total_use) %>%
    group_by(division) %>% summarise(exports = sum(exports), total_use = sum(total_use), .groups = 'drop')
  tibble(sic3 = sic3) %>%
    left_join(grp %>% transmute(sic3 = code, es_group = exports / total_use), by = 'sic3') %>%
    mutate(division = substr(sic3, 1, 2)) %>%
    left_join(div %>% transmute(division, es_division = exports / total_use), by = 'division') %>%
    transmute(sic3, export_share = coalesce(es_group, es_division),
              export_share_level = ifelse(is.na(es_group), 'division', 'group'))
}

# Regression with t-values from the larger of the OLS and HC3 standard errors (Rice and Venables, fn 27)
uk_reg <- function(y, x, label) {
  fit <- lm(y ~ x); X <- model.matrix(fit); e <- resid(fit)
  XtXi <- solve(crossprod(X)); h <- rowSums((X %*% XtXi) * X)
  hc3 <- XtXi %*% crossprod(X * (e / (1 - h))) %*% XtXi
  se <- pmax(sqrt(diag(vcov(fit))), sqrt(diag(hc3)))
  tibble(model = label, coef = coef(fit)[2], t = coef(fit)[2] / se[2], ci_low = coef(fit)[2] - 1.96 * se[2],
         ci_high = coef(fit)[2] + 1.96 * se[2], constant = coef(fit)[1], adj_r2 = summary(fit)$adj.r.squared, n = length(y))
}
