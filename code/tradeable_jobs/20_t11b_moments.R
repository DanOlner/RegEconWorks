# Round 2, test T11b: does Model F's revenue productivity vary across places and sectors as UK firms' does?
# The model's physical productivity draws (a_is, sd 0.2 as Rice and Venables) aren't observable; what the
# data measure is revenue productivity, GVA per worker. In Model F that is (1 - input shares) rev_is / L_is,
# proportional to the wage, so prices and wages absorb most of the physical differences.
# For each baseline (three draws, people mobile and immobile), log GVA per worker by place and sector is
# split, weighting by employment, into a sector effect, a place effect and the place-by-sector rest:
# the standard deviations of each, against the firm data's crossed random effects (T11a: industry, ITL2
# region, region by group), where those are on this machine.

source('code/tradeable_jobs/functions_common.R')
source('code/tradeable_jobs/functions_uk.R')
source('code/tradeable_jobs/functions_io.R')
source('code/tradeable_jobs/functions_rv2023.R')
source('code/tradeable_jobs/functions_modelF.R')
source('code/tradeable_jobs/16_modelF.R')

t11b <- tj_cached('t11b_moments', {
  gr <- read_csv(file.path(tj_output_dir, 't2_groups.csv'), show_col_types = FALSE)
  cf <- read_csv(file.path(tj_output_dir, 't2_group_coefficients.csv'), show_col_types = FALSE)
  cal <- mf_calibrate(gr, cf); S <- length(cal$sectors)
  bind_rows(lapply(101:103, function(seed) bind_rows(lapply(c('frechet', 'immobile'), function(mob) {
    set.seed(seed); a0 <- rv_draw_a(mf_N, S, 0.2)
    sp <- mf_from_cal(cal, a0, phi = mf$phi, q_fixed = mf$q0, mobility = mob); so <- mf_solve(sp)
    o <- mf_outcomes(so, sp)
    d <- expand_grid(place = factor(seq_len(mf_N)), sector = factor(cal$sectors)) %>%
      mutate(y = log(as.vector(t(o$gva)) / as.vector(t(so$Ls))), w = as.vector(t(so$Ls)), la = log(as.vector(t(a0))))
    m <- lm(y ~ place + sector, data = d, weights = w)
    wsd <- function(v, w) sqrt(sum(w * (v - weighted.mean(v, w))^2) / sum(w))
    pe <- coef(m)[grepl('^place', names(coef(m)))]; se <- coef(m)[grepl('^sector', names(coef(m)))]
    tibble(seed = seed, mobility = mob,
           sd_place_by_sector = wsd(resid(m), d$w), sd_place = sd(c(0, pe)), sd_sector = sd(c(0, se)),
           sd_physical_rest = wsd(resid(lm(la ~ place + sector, data = d, weights = w)), d$w),
           cor_revenue_physical = cor(resid(m), resid(lm(la ~ place + sector, data = d, weights = w))))
  })))) %>% group_by(mobility) %>% summarise(across(-seed, mean), .groups = 'drop')
}, depends = c('code/tradeable_jobs/functions_modelF.R', 'code/tradeable_jobs/16_modelF.R', 'code/tradeable_jobs/20_t11b_moments.R'))

# The firm data's moments, if T11a's tables are on this machine
t11b_firms <- local({
  f <- file.path('local/tradeable_jobs/companieshouse', 't11a_place_vc.csv')
  if (file.exists(f)) read_csv(f, show_col_types = FALSE) %>% filter(model == 'ITL2') %>% select(term, sd) else NULL
})

tj_write(t11b, 't11b_model_moments.csv')
