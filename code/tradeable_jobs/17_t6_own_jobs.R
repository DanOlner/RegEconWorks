# Round 2, test T6: does productivity growth in a sector cut its own jobs?
# The model answer is Model F's E1 experiments (16_modelF.R): the change in the improved group's jobs.
# The data check, as Autor and Salomons (2018) do for own-industry effects: across UK industries, hours
# growth against output-per-hour growth, from the ONS labour productivity by industry division dataset
# (Q4 2020 edition, the last; experimental statistics), 1997 to 2019 (before the pandemic).
#   long difference: log change 1997-2019, one row per industry, weighted by 1997 hours
#   stacked:         log changes over 1997-2002, 2002-2007, 2007-2012, 2012-2017, with period effects
# Each is run for all industries and with the slope split by T2's market reach (local services, the
# business-to-business groups, tradables).

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_uk.R')
source('code/tradeable_jobs/functions_io.R')

t6 <- tj_cached('t6_own_jobs', {
  f <- tj_get_file('https://www.ons.gov.uk/file?uri=/economy/economicoutputandproductivity/productivitymeasures/datasets/labourproductivitybyindustrydivision/octobertodecember2020/division.xlsx',
                   'division_2020q4.xlsx', dir = file.path(tj_raw_dir, 'ons_productivity'), expect = 'xls')
  rd <- function(sheet) {
    d <- suppressMessages(read_excel(f, sheet = sheet, col_names = FALSE, col_types = 'text'))
    codes <- unlist(d[5, ]); desc <- unlist(d[6, ])
    rows <- which(grepl('^\\d{4} Q\\d$', d[[1]]))
    keep <- which(!is.na(codes) & codes != 'WE' & !grepl('nested', desc, ignore.case = TRUE))
    keep <- setdiff(keep, 1)
    bind_rows(lapply(keep, function(j) tibble(code = codes[j], name = desc[j], quarter = d[[1]][rows], v = io_num(d[[j]][rows]))))
  }
  oph <- rd('OpH index') %>% rename(oph = v); hrs <- rd('Hours') %>% rename(hours = v)
  d <- oph %>% inner_join(hrs %>% select(code, quarter, hours), by = c('code', 'quarter')) %>%
    mutate(year = as.integer(substr(quarter, 1, 4))) %>%
    group_by(code, name, year) %>% summarise(oph = mean(oph), hours = mean(hours), n = n(), .groups = 'drop') %>% filter(n == 4)
  # each industry's first SIC division, and T2's group and reach for it
  d <- d %>% mutate(first_div = as.integer(sub('^[A-Z]*\\s*\\[?(\\d{2}).*$', '\\1', ifelse(grepl('\\[', code), sub('.*\\[', '', code), code))))
  grp <- read_csv(file.path(tj_output_dir, 't2_groups.csv'), show_col_types = FALSE) %>%
    select(group, export_share, household_share, b2b_share)
  ind <- d %>% distinct(code, name, first_div) %>% mutate(group = io_group_sic2(first_div)) %>% left_join(grp, by = 'group') %>%
    mutate(reach = case_when(group %in% c('public_providential', 'excluded', 'real_estate') ~ 'held fixed or left out',
                             export_share >= 0.2 ~ 'tradable', household_share >= 0.5 ~ 'local services',
                             TRUE ~ 'business to business'))
  ldiff <- function(y0, y1) d %>% filter(year %in% c(y0, y1)) %>% group_by(code) %>% filter(n() == 2) %>% arrange(year) %>%
    summarise(d_oph = diff(log(oph)), d_hours = diff(log(hours)), hours0 = first(hours), .groups = 'drop') %>%
    mutate(period = paste0(y0, '-', y1))
  long <- ldiff(1997, 2019) %>% left_join(ind, by = 'code')
  stacked <- bind_rows(ldiff(1997, 2002), ldiff(2002, 2007), ldiff(2007, 2012), ldiff(2012, 2017)) %>% left_join(ind, by = 'code')
  mkt <- function(x) x %>% filter(reach != 'held fixed or left out', is.finite(d_oph), is.finite(d_hours))
  fit <- function(x, f, label) {
    m <- lm(f, data = x, weights = hours0)
    ct <- summary(m)$coefficients
    tibble(sample = label, term = rownames(ct), estimate = ct[, 1], se = ct[, 2], n = nrow(x), r2 = summary(m)$r.squared)
  }
  regs <- bind_rows(
    fit(mkt(long), d_hours ~ d_oph, 'Long difference 1997-2019, market industries'),
    fit(mkt(long), d_hours ~ 0 + reach + d_oph:reach, 'Long difference 1997-2019, slope by reach'),
    fit(mkt(stacked), d_hours ~ period + d_oph, 'Stacked 5-year differences, market industries'),
    fit(mkt(stacked), d_hours ~ period + reach + d_oph:reach, 'Stacked 5-year differences, slope by reach'),
    fit(long %>% filter(is.finite(d_oph), is.finite(d_hours)), d_hours ~ d_oph, 'Long difference 1997-2019, all industries'))
  list(long = long, stacked = stacked, regs = regs, industries = ind)
}, depends = c('code/tradeable_jobs/functions_io.R', 'code/tradeable_jobs/17_t6_own_jobs.R', file.path(tj_output_dir, 't2_groups.csv')))

tj_write(t6$long, 't6_industries_1997_2019.csv')
tj_write(t6$regs, 't6_regressions.csv')
