# F0: the flow model in R (functions_flow.R), checked against the TypeScript build.
# Runs the baseline and the ten experiments (E1-E8b) to t = 40, and compares every standard results row
# (economy, place, producer, money) at periods 0, 1, 4, 5, 6, 10, 20 and 40 with the TypeScript's own
# output (flow_model/reference_ts_rows.csv.gz, from `npm run experiments` at commit 70c3804).
# Differences are relative to the TypeScript value, with a floor so that values that are zero up to
# rounding (a current account of £0.0003 in a £52bn economy) don't count: a millionth of base-year GDP for
# money and people, and 1e-9 for rates, prices and amounts per job or per resident.

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_flow.R')

fm_check <- tj_cached('flow_model_check', {
  base <- fm_params(); sc <- fm_scenarios()
  runs <- c(list(baseline = NULL), setNames(lapply(sc$experiments, function(e) e$scenario), vapply(sc$experiments, function(e) e$id, '')))
  rows <- bind_rows(lapply(names(runs), function(nm) fm_run_rows(fm_run(base, runs[[nm]], sc$lastPeriod)) %>% mutate(run = nm)))
  ref <- read_csv(file.path(fm_dir, 'reference_ts_rows.csv.gz'), show_col_types = FALSE)
  gdp0 <- rows$value[rows$run == 'baseline' & rows$t == 0 & rows$variable == 'gdp']
  small_scale <- grepl('rate|price|per_job|per_resident', ref$variable)
  cmp <- ref %>% mutate(floor = ifelse(small_scale, 1e-9, 1e-6 * gdp0)) %>%
    left_join(rows, by = c('run', 't', 'table', 'entity', 'variable'), suffix = c('_ts', '_r')) %>%
    mutate(rel = abs(value_r - value_ts) / pmax(abs(value_ts), floor))
  list(rows = rows, cmp = cmp)
}, depends = c('code/tradeable_jobs/functions_flow.R', 'code/tradeable_jobs/22_flow_model.R',
               file.path(fm_dir, 'flow_params_spec_v1.json'), file.path(fm_dir, 'flow_scenarios.json'),
               file.path(fm_dir, 'reference_ts_rows.csv.gz')))

fm_check_summary <- fm_check$cmp %>% group_by(run, table) %>%
  summarise(rows = n(), missing = sum(is.na(value_r)), max_rel_diff = max(rel, na.rm = TRUE), .groups = 'drop')
fm_headline <- fm_check$rows %>% filter(table == 'economy', variable %in% c('gdp', 'gni', 'unemployment_rate', 'government_balance'),
                                        t %in% c(4, 5, 40)) %>%
  select(run, t, variable, value) %>% pivot_wider(names_from = variable, values_from = value)

tj_write(fm_check_summary, 'flow_check_against_typescript.csv')
tj_write(fm_headline, 'flow_experiments_headline.csv')
