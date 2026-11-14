# F0: the "where GVA is booked" flow model (modelling_demand, model spec v1), ported to R from its
# TypeScript build (modelling repo, build/src/engine/, commit 70c3804, 12 October 2026).
#
# A stylised, demand-driven flow model: a core city (C), a manufacturing town (M), a rural area (R) and
# the rest of the world (W). Producers set prices by markup, cost or a fixed price; output meets demand
# (households, government, investment, exports) through fixed input coefficients; jobs and wages follow
# output; profits are taxed and paid out as dividends to owners by place; households spend out of income
# and money; commuting links workplaces to places of residence; unemployment is whatever demand leaves.
# Period 0 is the base year; scenarios change parameters from a period on and the model runs to t = 40.
#
# The port follows the TypeScript function by function (names in brackets), and is checked row by row
# against the original's output (22_flow_model.R). Inputs are the calibrated spec-v1 parameters and the
# experiments' scenarios, exported from the TypeScript as JSON (code/tradeable_jobs/flow_model/).
# Not ported: the lenses (§13) beyond what the standard results rows report, and calibration (§12):
# the stored calibration is used.

suppressPackageStartupMessages(suppressWarnings(library(jsonlite)))

fm_dir <- 'code/tradeable_jobs/flow_model'
fm_params <- function() fromJSON(file.path(fm_dir, 'flow_params_spec_v1.json'), simplifyVector = FALSE)
fm_scenarios <- function() fromJSON(file.path(fm_dir, 'flow_scenarios.json'), simplifyVector = FALSE)

fm_max_rel_change <- function(nxt, prev) {               # [maxRelativeChange]
  scale <- pmax(abs(nxt), abs(prev))
  ok <- scale != 0
  if (!any(ok)) return(0)
  ch <- abs(nxt - prev)[ok] / scale[ok]
  if (anyNA(ch)) return(NaN)
  max(ch)
}

# SCENARIOS (scenario.ts) ----
# A change sets, scales or adds to the parameter at its path, from its period on. Path elements that are
# numbers index arrays from 0, as in the TypeScript.
fm_apply_change <- function(params, change) {
  path <- change$path
  key <- function(k) if (is.numeric(k)) k + 1 else k
  get_at <- function(x, p) { for (k in p) x <- x[[key(k)]]; x }
  set_at <- function(x, p, value) {
    if (length(p) == 1) { x[[key(p[[1]])]] <- value; return(x) }
    x[[key(p[[1]])]] <- set_at(x[[key(p[[1]])]], p[-1], value); x
  }
  current <- get_at(params, path)
  if (is.null(current)) stop('Unknown parameter: ', paste(unlist(path), collapse = '.'))
  value <- if (!is.null(change$set)) change$set else if (!is.null(change$scale)) current * change$scale else current + change$add
  set_at(params, path, value)
}
fm_params_at <- function(base, scenario, t) {             # [paramsAt]
  if (is.null(scenario)) return(base)
  ch <- scenario$changes
  periods <- vapply(ch, function(c) c$period, 0)
  keep <- which(periods <= t)
  keep <- keep[order(periods[keep], keep)]
  for (k in keep) base <- fm_apply_change(base, ch[[k]])
  base
}
fm_changes_in_force <- function(scenario, t) if (is.null(scenario)) 0 else sum(vapply(scenario$changes, function(c) c$period <= t, TRUE))

# COMPILE (economy.ts) ----
fm_compile <- function(params) {
  places <- unlist(params$places); row <- params$restOfWorld
  groups <- c(places, row)
  all_ids <- names(params$producers)
  is_dom <- vapply(all_ids, function(id) params$producers[[id]]$place != row, TRUE)
  ids <- c(all_ids[is_dom], all_ids[!is_dom]); n <- length(ids); nd <- sum(is_dom)
  idx <- setNames(seq_len(n), ids)
  pr <- params$producers[ids]
  num <- function(f) vapply(pr, function(p) as.numeric(p[[f]]), 0)
  A <- matrix(0, n, n, dimnames = list(ids, ids))
  owner <- matrix(0, n, length(groups), dimnames = list(ids, groups))
  gov <- rep(FALSE, n)
  for (j in seq_len(n)) {
    p <- pr[[j]]
    for (s in names(p$inputs)) A[idx[[s]], j] <- p$inputs[[s]]
    if (j <= nd) {
      firm <- params$firms[[p$firm]]
      gov[j] <- isTRUE(firm$government)
      if (!gov[j]) for (g in names(firm$owners)) owner[j, g] <- firm$owners[[g]]
    }
  }
  pop <- params$population
  others <- setdiff(places, pop$mainPlace)
  w_total <- sum(vapply(others, function(pl) if (is.null(pop$otherWeights[[pl]])) 0 else pop$otherWeights[[pl]], 0))
  population <- vapply(places, function(pl) if (pl == pop$mainPlace) pop$mainShare * pop$total else
    (1 - pop$mainShare) * pop$total * ((if (is.null(pop$otherWeights[[pl]])) 0 else pop$otherWeights[[pl]]) / w_total), 0)
  dem <- params$demography[places]
  labour_force <- population * vapply(dem, function(d) d$workingAgeShare * d$participation, 0)
  non_working <- population * vapply(dem, function(d) 1 - d$workingAgeShare, 0)
  hh <- params$households
  local_id <- function(place, sector) { id <- paste0(place, '.', sector); if (!id %in% ids) stop('No producer ', id); idx[[id]] }
  essentials <- lapply(places, function(pl) {
    e <- list()
    for (sector in names(hh$essentialsPerResident)) {
      u <- hh$essentialsPerResident[[sector]][[pl]]
      if (!is.null(u) && u != 0) e[[length(e) + 1]] <- list(producer = local_id(pl, sector), units = u)
    }
    e
  })
  exp_q <- setNames(rep(0, n), ids)
  for (id in names(params$exports$mix)) exp_q[id] <- params$exports$total * params$exports$mix[[id]]
  inv <- params$investment$shares
  ip_owner <- setNames(rep(0, length(groups)), groups)
  if (!is.null(params$royalty$ownerFirm)) for (g in names(params$firms[[params$royalty$ownerFirm]]$owners))
    ip_owner[g] <- params$firms[[params$royalty$ownerFirm]]$owners[[g]]
  list(params = params, places = places, groups = groups, ids = ids, n = n, nd = nd, index = idx,
       place_of = vapply(pr, function(p) if (p$place == row) NA_integer_ else match(p$place, places), 0L),
       sector_of = vapply(pr, function(p) p$sector, ''), A = A,
       pricing = vapply(pr, function(p) p$pricing, ''), markup = num('markup'), fixed_price = num('fixedPrice'),
       jobs_per_unit = num('jobsPerUnit'), wage_per_job = num('wagePerJob'),
       depreciation = ifelse(is_dom[ids], num('depreciation'), 0), payout = num('payout'),
       is_government = gov, owner = owner, population = population, labour_force = labour_force, non_working = non_working,
       essentials = essentials, local_discretionary = vapply(places, function(pl) local_id(pl, hh$localSector), 0L),
       gadget = if (hh$gadgetProducer %in% ids) idx[[hh$gadgetProducer]] else NA_integer_,
       provision = vapply(places, function(pl) local_id(pl, params$government$provisionSector), 0L),
       inv_producer = unname(idx[names(inv)]), inv_share = unlist(inv, use.names = FALSE),
       export_q = unname(exp_q),
       royalty_payer = if (!is.null(params$royalty$payer)) idx[[params$royalty$payer]] else NA_integer_,
       ip_owner = unname(ip_owner))
}

# PRICES (prices.ts) ----
fm_prices <- function(econ, start = rep(1, econ$n)) {
  p <- start
  ulc <- econ$wage_per_job * econ$jobs_per_unit
  for (it in 1:10000) {
    inputs <- as.vector(crossprod(econ$A, p))
    nxt <- ifelse(econ$pricing == 'fixed', econ$fixed_price,
                  ifelse(econ$pricing == 'markup', (1 + econ$markup) * (inputs + ulc), inputs + ulc + econ$depreciation))
    if (fm_max_rel_change(nxt, p) < 1e-12) return(nxt)
    p <- nxt
  }
  stop('Prices did not converge')
}

# COMMUTING (commuting.ts) ----
fm_base_commuting <- function(jobs, lf) {
  n <- length(jobs)
  target <- lf * sum(jobs) / sum(lf)
  local <- pmin(jobs, target); surplus <- target - local; unfilled <- jobs - local
  g <- matrix(0, n, n)
  for (w in seq_len(n)) {
    if (jobs[w] == 0) { g[w, w] <- 1; next }
    g[w, w] <- local[w] / jobs[w]
    if (sum(unfilled) == 0) next
    for (r in seq_len(n)) if (r != w) g[w, r] <- surplus[r] * unfilled[w] / sum(unfilled) / jobs[w]
  }
  g
}

# ONE PERIOD (period.ts) ----
fm_household_demand <- function(econ, p, mode, di, hh_money, frozen) {        # [householdDemand]
  hh <- econ$params$households; np <- length(econ$places)
  q <- matrix(0, np, econ$n); cons <- ess <- numeric(np); exceeds <- logical(np)
  for (r in seq_len(np)) {
    res <- econ$population[r]
    e <- 0
    for (x in econ$essentials[[r]]) e <- e + p[x$producer] * x$units * res
    ess[r] <- e
    if (!is.null(frozen)) { q[r, ] <- frozen[r, ]; cons[r] <- sum(p * q[r, ]); next }
    for (x in econ$essentials[[r]]) q[r, x$producer] <- q[r, x$producer] + x$units * res
    planned <- if (mode == 'base') di[r] else hh$alpha1 * di[r] + hh$alpha2 * hh_money[r]
    exceeds[r] <- planned < e
    if (exceeds[r]) planned <- e
    disc <- planned - e
    if (hh$gadgetShare != 0) q[r, econ$gadget] <- q[r, econ$gadget] + hh$gadgetShare * disc / p[econ$gadget]
    loc <- econ$local_discretionary[r]
    q[r, loc] <- q[r, loc] + (1 - hh$gadgetShare) * disc / p[loc]
    cons[r] <- planned
  }
  list(quantities = q, total = colSums(q), consumption = cons, essential_spend = ess, exceeds = exceeds)
}

fm_with_investment <- function(econ, p) {               # [withInvestment]
  B <- econ$A
  for (k in seq_along(econ$inv_producer)) {
    i <- econ$inv_producer[k]
    B[i, seq_len(econ$nd)] <- B[i, seq_len(econ$nd)] + econ$inv_share[k] * econ$depreciation[seq_len(econ$nd)] / p[i]
  }
  B
}

fm_period <- function(econ, p, mode, hh_money, commuting, frozen = NULL, start = NULL) {   # [solvePeriod]
  params <- econ$params; nd <- econ$nd; n <- econ$n
  B <- fm_with_investment(econ, p)
  Linv <- solve(diag(nd) - B[seq_len(nd), seq_len(nd)])
  gp <- params$government
  prov_q <- vapply(seq_along(econ$places), function(r) {
    m <- gp$provisionMultiplier[[econ$places[r]]]; gp$provisionPerResident * (if (is.null(m)) 1 else m) * econ$population[r] }, 0)
  government <- rep(0, n)
  for (r in seq_along(econ$places)) government[econ$provision[r]] <- government[econ$provision[r]] + prov_q[r]
  output <- if (!is.null(start)) start$output[seq_len(nd)] else rep(0, nd)
  di <- if (!is.null(start)) start$di else rep(0, length(econ$places))
  for (it in 1:10000) {
    dem <- fm_household_demand(econ, p, mode, di, hh_money, frozen)
    final <- dem$total[seq_len(nd)] + government[seq_len(nd)] + econ$export_q[seq_len(nd)]
    nxt <- as.vector(Linv %*% final)
    res <- fm_accounts(econ, p, mode, commuting, B, nxt, dem, government, prov_q)
    change <- max(fm_max_rel_change(nxt, output), fm_max_rel_change(res$households$disposable_income, di))
    output <- nxt; di <- res$households$disposable_income
    if (is.nan(change)) stop('Quantities and incomes became NaN')
    if (change < 1e-12) { res$iterations <- it; return(res) }
  }
  stop('Quantities and incomes did not converge')
}

fm_accounts <- function(econ, p, mode, commuting, B, x, dem, government, prov_q) {          # [accounts]
  params <- econ$params; nd <- econ$nd; n <- econ$n; np <- length(econ$places); ng <- length(econ$groups)
  gp <- params$government; roy <- params$royalty
  dom <- seq_len(nd); frn <- if (n > nd) (nd + 1):n else integer(0)
  output <- rep(0, n); output[dom] <- x
  for (i in frn) output[i] <- dem$total[i] + government[i] + sum(B[i, dom] * x)
  inv_total <- sum(econ$depreciation[dom] * x)
  investment <- rep(0, n)
  for (k in seq_along(econ$inv_producer)) investment[econ$inv_producer[k]] <- investment[econ$inv_producer[k]] + econ$inv_share[k] * inv_total / p[econ$inv_producer[k]]
  z <- function() rep(0, n)
  pr <- list(output = output, revenue = z(), inputs_cost = z(), royalty = z(), gva = z(), jobs = z(), wage_bill = z(),
             depreciation = z(), net_profit = z(), profit_tax = z(), dividends = z(), retained = z())
  div_owner <- rep(0, ng); enterprise_surplus <- 0
  unit_inputs <- as.vector(crossprod(econ$A, p))
  for (j in dom) {
    pr$revenue[j] <- p[j] * x[j]
    pr$inputs_cost[j] <- unit_inputs[j] * x[j]
    pr$royalty[j] <- if (!is.na(econ$royalty_payer) && j == econ$royalty_payer) roy$rate * pr$revenue[j] else 0
    pr$gva[j] <- pr$revenue[j] - pr$inputs_cost[j] - pr$royalty[j]
    pr$jobs[j] <- econ$jobs_per_unit[j] * x[j]
    pr$wage_bill[j] <- econ$wage_per_job[j] * pr$jobs[j]
    pr$depreciation[j] <- econ$depreciation[j] * x[j]
    pr$net_profit[j] <- pr$gva[j] - pr$wage_bill[j] - pr$depreciation[j]
    if (econ$is_government[j]) { enterprise_surplus <- enterprise_surplus + pr$net_profit[j]; next }
    pr$profit_tax[j] <- gp$profitTaxRate * max(pr$net_profit[j], 0)
    after <- pr$net_profit[j] - pr$profit_tax[j]
    pr$dividends[j] <- econ$payout[j] * after
    pr$retained[j] <- after - pr$dividends[j]
    div_owner <- div_owner + econ$owner[j, ] * pr$dividends[j]
  }
  for (i in frn) pr$revenue[i] <- p[i] * output[i]
  royalties <- sum(pr$royalty); ip_div <- roy$payout * royalties; ip_owner <- econ$ip_owner * ip_div
  jobs_at <- wages_at <- rep(0, np)
  for (j in dom) { jobs_at[econ$place_of[j]] <- jobs_at[econ$place_of[j]] + pr$jobs[j]; wages_at[econ$place_of[j]] <- wages_at[econ$place_of[j]] + pr$wage_bill[j] }
  gamma <- if (mode == 'base') fm_base_commuting(jobs_at, econ$labour_force) else commuting
  employed <- as.vector(t(gamma) %*% jobs_at); wages_rec <- as.vector(t(gamma) %*% wages_at)
  unemployed <- econ$labour_force - employed
  div_rec <- div_owner[seq_len(np)] + ip_owner[seq_len(np)]
  gross <- wages_rec + div_rec
  inc_tax <- gp$incomeTaxRate * gross
  benefits <- gp$benefitNonWorking * econ$non_working + gp$benefitUnemployed * pmax(unemployed, 0)
  di <- gross - inc_tax + benefits
  hh <- list(population = econ$population, labour_force = econ$labour_force, non_working = econ$non_working,
             employed = employed, unemployed = unemployed, wages_received = wages_rec, dividends_received = div_rec,
             gross_income = gross, income_tax = inc_tax, benefits = benefits, disposable_income = di,
             essential_spend = dem$essential_spend, consumption = dem$consumption, saving = di - dem$consumption,
             quantities = dem$quantities)
  value <- function(q) sum(p * q)
  import_payments <- sum(pr$revenue[frn]); export_payments <- value(econ$export_q)
  ip_paid <- sum(ip_owner[seq_len(ng - 1)])
  row <- list(import_payments = import_payments, royalties = royalties, dividends_received = div_owner[ng],
              export_payments = export_payments, ip_dividends_paid = ip_paid,
              balance = import_payments + royalties + div_owner[ng] - export_payments - ip_paid)
  gdp_prod <- sum(pr$gva[dom]); gdp_inc <- sum(pr$wage_bill[dom] + pr$depreciation[dom] + pr$net_profit[dom])
  consumption <- sum(dem$consumption); prov_spend <- value(government); imports_value <- import_payments + royalties
  govt <- list(income_tax = sum(inc_tax), profit_tax = sum(pr$profit_tax), enterprise_surplus = enterprise_surplus,
               provision_quantity = prov_q, provision_spend = prov_spend, benefits = sum(benefits))
  govt$balance <- govt$income_tax + govt$profit_tax + govt$enterprise_surplus - prov_spend - govt$benefits
  list(prices = p, producers = pr,
       final_demand = list(households = dem$total, government = government, investment = investment, exports = econ$export_q),
       households = hh, dividends_by_owner = div_owner,
       ip = list(royalties = royalties, dividends = ip_div, dividends_by_owner = ip_owner, retained = royalties - ip_div),
       government = govt, rest_of_world = row, firms = list(retained = sum(pr$retained)),
       workplaces = list(jobs = jobs_at, wage_bill = wages_at), commuting = gamma,
       macro = list(gdp_production = gdp_prod,
                    gdp_expenditure = consumption + prov_spend + inv_total + export_payments - imports_value,
                    gdp_income = gdp_inc, consumption = consumption, government_spend = prov_spend, investment = inv_total,
                    exports_value = export_payments, imports_value = imports_value,
                    gni = gdp_prod + ip_paid - div_owner[ng], current_account = -row$balance,
                    unemployment_rate = sum(unemployed) / sum(econ$labour_force)),
       flags = c(paste0(econ$places[dem$exceeds], ': essentials exceed planned consumption'),
                 paste0(econ$places[unemployed < 0], ': labour shortage')))
}

# IDENTITIES (checks.ts) ----
fm_check_identities <- function(t, econ, res, money, tol = 1e-6) {
  pr <- res$producers; m <- res$macro; dom <- seq_len(econ$nd)
  scale <- if (abs(m$gdp_production) > 0) abs(m$gdp_production) else 1
  fd <- res$final_demand
  errs <- c(
    producer = max(abs(pr$revenue[dom] - (pr$inputs_cost + pr$royalty + pr$wage_bill + pr$depreciation + pr$net_profit)[dom])),
    expenditure = abs(m$gdp_production - m$gdp_expenditure), income = abs(m$gdp_production - m$gdp_income),
    final_demand = abs(m$gdp_production - (sum(res$prices * (fd$households + fd$government + fd$investment + fd$exports)) - m$imports_value)),
    balances = abs(sum(res$households$saving) + res$firms$retained + res$government$balance + res$rest_of_world$balance),
    money = abs(sum(money$households) + money$firms + money$government + money$rest_of_world)) / scale
  if (any(!(errs <= tol))) stop('Period ', t, ': accounting identities fail: ', paste(names(errs)[!(errs <= tol)], collapse = ', '))
  invisible(errs)
}

# RUN (run.ts) ----
# Extensions (not in the TypeScript; off by default, when the run is the original model):
#   export_elasticity  export quantities respond to their price against the base year:
#                      q_j = q_j(params) (p_j / p_j,0)^-elasticity
#   wage_curve         wages respond to last period's unemployment where the producer is, as a wage curve:
#                      target factor f* = (max(u_place, u_floor) / u_place,0)^-wage_curve  (Blanchflower-Oswald ~0.1),
#                      and wages move part of the way there each period, f_t = f_{t-1}^(1 - wage_speed) f*^wage_speed,
#                      w_j = w_j(params) f_t. Without the partial adjustment, a tight economy cycles (a cobweb:
#                      high wages cut price-elastic exports, which cuts jobs, which cuts wages, and so on).
fm_ext_default <- list(export_elasticity = 0, wage_curve = 0, u_floor = 0.005, wage_speed = 0.3)

fm_run <- function(base, scenario = NULL, periods = 40, ext = fm_ext_default) {
  ext <- modifyList(fm_ext_default, ext)
  econ0 <- fm_compile(base); np <- length(econ0$places)
  r0 <- fm_period(econ0, fm_prices(econ0), 'base', rep(0, np), NULL)
  hhp <- base$households
  h0 <- (1 - hhp$alpha1) * r0$households$disposable_income / hhp$alpha2
  money0 <- list(households = h0, firms = 0, government = -sum(h0), rest_of_world = 0)
  fm_check_identities(0, econ0, r0, money0)
  records <- list(list(t = 0, econ = econ0, result = r0, money = money0))
  base_comm <- r0$commuting; base_q <- r0$households$quantities
  p_ref <- r0$prices; u_ref <- r0$households$unemployed / r0$households$labour_force
  wf <- rep(1, np)                                         # the wage curve's factor by place
  params <- base; econ <- econ0; in_force <- 0
  for (t in seq_len(periods)) {
    cnt <- fm_changes_in_force(scenario, t)
    if (cnt != in_force) { params <- fm_params_at(base, scenario, t); econ <- fm_compile(params); in_force <- cnt }
    prev <- records[[t]]
    comm <- if (!is.null(params$commuting$override)) do.call(rbind, lapply(params$commuting$override, unlist)) else base_comm
    econ_t <- econ
    if (ext$wage_curve != 0) {
      u_prev <- prev$result$households$unemployed / prev$result$households$labour_force
      f_target <- (pmax(u_prev, ext$u_floor) / u_ref)^(-ext$wage_curve)
      wf <- wf^(1 - ext$wage_speed) * f_target^ext$wage_speed
      dom <- seq_len(econ$nd)
      econ_t$wage_per_job[dom] <- econ$wage_per_job[dom] * wf[econ$place_of[dom]]
    }
    p_t <- fm_prices(econ_t, prev$result$prices)
    if (ext$export_elasticity != 0) econ_t$export_q <- econ$export_q * (p_t / p_ref)^(-ext$export_elasticity)
    res <- fm_period(econ_t, p_t, 'normal', prev$money$households, comm,
                     frozen = if (isTRUE(params$households$freezeConsumption)) base_q else NULL,
                     start = list(output = prev$result$producers$output, di = prev$result$households$disposable_income))
    money <- list(households = prev$money$households + res$households$saving, firms = prev$money$firms + res$firms$retained,
                  government = prev$money$government + res$government$balance,
                  rest_of_world = prev$money$rest_of_world + res$rest_of_world$balance)
    fm_check_identities(t, econ, res, money)
    records[[t + 1]] <- list(t = t, econ = econ_t, result = res, money = money)
  }
  records
}

# RESULTS ROWS (report.ts, periodRows) ----
fm_rows <- function(rec) {
  t <- rec$t; econ <- rec$econ; r <- rec$result; money <- rec$money; hh <- r$households; pr <- r$producers
  mk <- function(table, entity, vals) tibble(t = t, table = table, entity = entity, variable = names(vals), value = unname(unlist(vals)))
  gva <- vapply(seq_along(econ$places), function(w) sum(pr$gva[seq_len(econ$nd)][econ$place_of[seq_len(econ$nd)] == w]), 0)
  services <- vapply(seq_along(econ$places), function(r2) {
    q <- econ$params$government$quality[[econ$places[r2]]]; r$government$provision_quantity[r2] * (if (is.null(q)) 1 else q) / hh$population[r2] }, 0)
  out <- list(mk('economy', 'all', list(
    gdp = r$macro$gdp_production, gni = r$macro$gni, consumption = r$macro$consumption,
    government_spending = r$macro$government_spend, investment = r$macro$investment, exports = r$macro$exports_value,
    imports_including_royalties = r$macro$imports_value, current_account = r$macro$current_account,
    government_balance = r$government$balance, income_tax = r$government$income_tax, profit_tax = r$government$profit_tax,
    benefits = r$government$benefits, royalties = r$ip$royalties, dividends_to_overseas_owners = r$rest_of_world$dividends_received,
    ip_dividends_to_domestic_owners = r$rest_of_world$ip_dividends_paid, unemployment_rate = r$macro$unemployment_rate)))
  for (w in seq_along(econ$places)) out[[length(out) + 1]] <- mk('place', econ$places[w], list(
    residents = hh$population[w], labour_force = hh$labour_force[w], jobs_at_workplace = r$workplaces$jobs[w],
    gva_at_workplace = gva[w], gva_per_job = gva[w] / r$workplaces$jobs[w], employed_residents = hh$employed[w],
    unemployed = hh$unemployed[w], unemployment_rate = hh$unemployed[w] / hh$labour_force[w],
    wages_received = hh$wages_received[w], dividends_received = hh$dividends_received[w], gross_income = hh$gross_income[w],
    income_tax = hh$income_tax[w], benefits = hh$benefits[w], disposable_income = hh$disposable_income[w],
    essential_spending = hh$essential_spend[w], consumption = hh$consumption[w], saving = hh$saving[w],
    residual_income_per_resident = (hh$disposable_income[w] - hh$essential_spend[w]) / hh$population[w],
    public_services_per_resident = services[w], household_money = money$households[w]))
  for (j in seq_len(econ$n)) {
    out[[length(out) + 1]] <- if (j > econ$nd) mk('producer', econ$ids[j], list(price = r$prices[j], imports = pr$output[j], import_payments = pr$revenue[j]))
    else mk('producer', econ$ids[j], list(price = r$prices[j], output = pr$output[j], revenue = pr$revenue[j],
      inputs_cost = pr$inputs_cost[j], royalty = pr$royalty[j], gva = pr$gva[j], jobs = pr$jobs[j], wage_bill = pr$wage_bill[j],
      depreciation = pr$depreciation[j], net_profit = pr$net_profit[j], profit_tax = pr$profit_tax[j], dividends = pr$dividends[j],
      retained = pr$retained[j]))
  }
  out[[length(out) + 1]] <- mk('money', 'all', list(households = sum(money$households), firms = money$firms,
                                                    government = money$government, rest_of_world = money$rest_of_world))
  bind_rows(out)
}
fm_run_rows <- function(records) bind_rows(lapply(records, fm_rows))
