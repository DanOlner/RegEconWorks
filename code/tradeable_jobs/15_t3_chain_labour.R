# Round 2, test T3: the labour and value added embodied in each product's whole UK supply chain
# (vertical integration, Pasinetti), from the 2019 input-output tables and BRES employees.
#   jobs per £m of output, by product:        l_j = employees_j / output_j
#   jobs embodied per £m of final demand:     lambda_k = sum_j l_j L[j, k]      (domestic chain only)
#   value added embodied per £ of final use:  nu_k = sum_j v_j L[j, k]          (the rest leaks to imports and taxes)
#   chain GVA per job (the flow model's lens 3): nu_k / lambda_k, against the product's own GVA per job
# Where the jobs sit: for final demand in product k, the share of its embodied jobs in each supplying
# group; and for all UK exports, which groups the jobs embodied in them are in.
# National only: a regional version would need regional coefficients, and T4 showed the payment flows
# cover too little of business-to-business trade to supply them.

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_uk.R')
source('code/tradeable_jobs/functions_io.R')
source('code/tradeable_jobs/12_t2_domar_tradability.R')

t3 <- tj_cached('t3_chain', {
  io <- io_tables(); p <- t2$products
  stopifnot(identical(p$cpa, io$products$cpa))
  l <- ifelse(p$output > 0, p$employees / p$output, 0)           # jobs per £m
  v <- p$gva / p$output
  L <- io$L
  lambda <- as.vector(l %*% L); nu <- as.vector(v %*% L)
  fd_total <- with(p, fd_households + fd_government + fd_investment + fd_exports)
  grp <- p$group
  share_in <- function(k) tapply(l * L[, k], grp, sum) / lambda[k]    # where product k's embodied jobs sit
  own_share <- vapply(seq_along(lambda), function(k) sum((l * L[, k])[grp == grp[k]]) / lambda[k], 0)
  self_share <- l * diag(L) / lambda
  products <- p %>% select(cpa, name, group, group_name, foundational, limit, reach, employees, output, gva, export_share) %>%
    mutate(jobs_per_m = l, chain_jobs_per_m = lambda, chain_va_per_pound = nu,
           own_gva_per_job = ifelse(employees > 0, 1e6 * gva / employees, NA_real_),
           chain_gva_per_job = ifelse(lambda > 0, 1e6 * nu / lambda, NA_real_),
           chain_multiplier = ifelse(l > 0, lambda / l, NA_real_),
           share_jobs_own_product = self_share, share_jobs_own_group = own_share,
           final_demand = fd_total)

  # Jobs embodied in each category of final demand, by supplying group
  FD <- as.matrix(p[, c('fd_households', 'fd_government', 'fd_investment', 'fd_exports')])
  emb <- (l * (L %*% FD))                                            # jobs in product j serving each final use
  colnames(emb) <- c('households', 'government', 'investment', 'exports')
  by_group <- as_tibble(emb) %>% mutate(group = grp) %>% group_by(group) %>% summarise(across(everything(), sum), .groups = 'drop') %>%
    left_join(io_group_labels, by = 'group') %>%
    mutate(across(c(households, government, investment, exports), ~ .x / sum(.x), .names = '{.col}_share'),
           employees = households + government + investment + exports)

  # For final demand in the tradable products (export share 25%+), how many of the embodied jobs are in
  # other groups, and which
  trad <- p$reach == 'International'
  trad_jobs <- as.vector(l * (L[, trad, drop = FALSE] %*% fd_total[trad]))
  tradable_chain <- tibble(group = grp, jobs = trad_jobs) %>% group_by(group) %>% summarise(jobs = sum(jobs), .groups = 'drop') %>%
    left_join(io_group_labels, by = 'group') %>% mutate(share = jobs / sum(jobs))
  trad_in_own_products <- sum((l * L[, trad, drop = FALSE] %*% fd_total[trad])[trad]) / sum(trad_jobs)

  # Groups: chain against own GVA per job, final-demand weighted
  groups <- products %>% filter(final_demand > 0) %>% group_by(group) %>%
    summarise(own_gva_per_job = sum(gva) / sum(employees),
              chain_gva_per_job = 1e6 * sum(chain_va_per_pound * final_demand) / sum(chain_jobs_per_m * final_demand),
              chain_multiplier = sum(chain_jobs_per_m * final_demand) / sum(jobs_per_m * final_demand),
              share_jobs_outside_group = 1 - sum(share_jobs_own_group * chain_jobs_per_m * final_demand) / sum(chain_jobs_per_m * final_demand),
              .groups = 'drop') %>%
    mutate(own_gva_per_job = 1e6 * own_gva_per_job) %>% left_join(io_group_labels, by = 'group')

  checks <- tibble(check = c('employees in chains of final demand = employees', 'max |lambda - l (I-A)^-1 by solve|'),
                   value = c(sum(emb) / sum(l * p$output), max(abs(lambda - as.vector(solve(t(diag(length(l)) - io$A), l))))))
  list(products = products, by_group = by_group, tradable_chain = tradable_chain, trad_in_own_products = trad_in_own_products,
       groups = groups, checks = checks)
}, depends = c('code/tradeable_jobs/functions_io.R', 'code/tradeable_jobs/15_t3_chain_labour.R',
               'code/tradeable_jobs/12_t2_domar_tradability.R'))

tj_write(t3$products, 't3_products.csv')
tj_write(t3$by_group, 't3_jobs_by_final_use.csv')
tj_write(t3$tradable_chain, 't3_tradable_chain_jobs.csv')
tj_write(t3$groups, 't3_groups.csv')
