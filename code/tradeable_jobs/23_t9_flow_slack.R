# T9, slack half: local against national in the flow model (functions_flow.R), where output follows demand,
# wages and prices don't respond to unemployment, and people out of work stay out of work. It is the
# demand-driven, slack counterpart to Model F, which has full employment.
#
# Two starting economies: the base (5% unemployment in every place), and a slack one where all exports fall
# 20% from period 1 (E6's slump brought forward: unemployment 11-17%). In each, every policy below starts at
# period 5, and the economy at period 40 is compared with the same economy without the policy.
#   D1  inward investment in the town: component exports +20%
#   D2  local procurement in every place (E7) and D2t in the town only: public services buy 0.04 less
#       imported goods per unit, 0.02 more each from local everyday services and local utilities
#   S1-S5  +5% labour productivity (jobs per unit / 1.05) in: the town's components (tradable), the town's
#       everyday services, the town's utilities and transport, the city's business services (sold to firms
#       everywhere), everyday services in every place
# Outcomes, nationally and by place: GDP and GVA at the workplace (the official lens), GVA per job, jobs,
# unemployment, disposable income, and real disposable income: deflated by a cost-of-living index for each
# place, the base-year household basket at current prices. The town's share of the national change in real
# disposable income measures how much of the gain stays local.

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_flow.R')

t9f <- tj_cached('t9_flow_slack', {
  base <- fm_params(); sc <- fm_scenarios()
  ch <- function(period, path, op, v) { x <- list(period = period, path = as.list(path)); x[[op]] <- v; x }
  e7 <- sc$experiments[[which(vapply(sc$experiments, function(e) e$id, '') == 'E7')]]$scenario$changes
  e7_town <- Filter(function(c) c$path[[2]] == 'M.PRV', e7)
  prod <- function(...) lapply(c(...), function(id) ch(5, c('producers', id, 'jobsPerUnit'), 'scale', 1 / 1.05))
  policies <- list(
    `D1 Inward investment in the town: component exports +20%` = list(ch(5, c('exports', 'mix', 'M.CMP'), 'scale', 1.2)),
    `D2 Local procurement, every place (E7)` = e7,
    `D2t Local procurement, the town only` = e7_town,
    `S1 Productivity +5%: the town's components (tradable)` = prod('M.CMP'),
    `S2 Productivity +5%: the town's everyday services` = prod('M.RET'),
    `S3 Productivity +5%: the town's utilities and transport` = prod('M.UTL'),
    `S4 Productivity +5%: the city's business services (sold to firms everywhere)` = prod('C.BIZ'),
    `S5 Productivity +5%: everyday services in every place` = prod('C.RET', 'M.RET', 'R.RET'))
  economies <- list(`Base: 5% unemployment` = list(),
                    `Slack: exports down 20% from period 1` = list(ch(1, c('exports', 'total'), 'scale', 0.8)))
  q0 <- NULL; p0 <- NULL
  measures <- function(rec) {
    r <- rec$result; econ <- rec$econ; hh <- r$households; dom <- seq_len(econ$nd)
    cpi <- as.vector(q0 %*% r$prices) / as.vector(q0 %*% p0)
    gva <- vapply(seq_along(econ$places), function(w) sum(r$producers$gva[dom][econ$place_of[dom] == w]), 0)
    tibble(place = c(econ$places, 'all'),
           gva = c(gva, r$macro$gdp_production), jobs = c(r$workplaces$jobs, sum(r$workplaces$jobs)),
           unemployed = c(hh$unemployed, sum(hh$unemployed)), labour_force = c(hh$labour_force, sum(hh$labour_force)),
           disposable_income = c(hh$disposable_income, sum(hh$disposable_income)),
           real_disposable_income = c(hh$disposable_income / cpi, sum(hh$disposable_income / cpi)),
           residents = c(hh$population, sum(hh$population)), gni = r$macro$gni, cpi = c(cpi, NA))
  }
  out <- list()
  for (en in names(economies)) {
    cf_runs <- fm_run(base, list(changes = economies[[en]]), 40)
    if (is.null(q0)) { q0 <- cf_runs[[1]]$result$households$quantities; p0 <- cf_runs[[1]]$result$prices }
    cf <- measures(cf_runs[[41]])
    for (pn in names(policies)) {
      pr <- fm_run(base, list(changes = c(economies[[en]], policies[[pn]])), 40)
      m <- measures(pr[[41]])
      out[[length(out) + 1]] <- m %>% left_join(cf, by = 'place', suffix = c('', '_cf')) %>% mutate(economy = en, policy = pn)
    }
  }
  bind_rows(out) %>%
    mutate(d_gva = gva - gva_cf, d_gva_pct = gva / gva_cf - 1, d_gva_per_job_pct = (gva / jobs) / (gva_cf / jobs_cf) - 1,
           d_jobs = jobs - jobs_cf, d_unemployment_rate = unemployed / labour_force - unemployed_cf / labour_force_cf,
           d_real_di = real_disposable_income - real_disposable_income_cf,
           d_real_di_pct = real_disposable_income / real_disposable_income_cf - 1,
           d_cpi_pct = cpi / cpi_cf - 1, d_gni_pct = gni / gni_cf - 1, cf_unemployment_rate = unemployed_cf / labour_force_cf) %>%
    group_by(economy, policy) %>%
    mutate(town_share_of_real_gain = d_real_di[place == 'M'] / d_real_di[place == 'all']) %>% ungroup()
}, depends = c('code/tradeable_jobs/functions_flow.R', 'code/tradeable_jobs/23_t9_flow_slack.R',
               file.path(fm_dir, 'flow_params_spec_v1.json'), file.path(fm_dir, 'flow_scenarios.json')))

tj_write(t9f %>% select(economy, policy, place, cf_unemployment_rate, d_gva, d_gva_pct, d_gva_per_job_pct, d_jobs,
                        d_unemployment_rate, d_real_di, d_real_di_pct, d_cpi_pct, d_gni_pct, town_share_of_real_gain),
         't9_flow_slack.csv')
