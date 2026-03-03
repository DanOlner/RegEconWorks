# EXPLAINERS
library(tidyverse)
library(zoo)
library(patchwork)

# Grab some functions from the regionalecontools repo
source('https://raw.githubusercontent.com/DanOlner/RegionalEconomicTools/refs/heads/gh-pages/functions/misc_functions.R')

# And some for processing SIC codes into the correct bins
source('code/data_process_functions.R')

options(scipen = 999)


# CLAUDE CODE SECTION----

# ============================================================================
# AR(1) SLOPE UNCERTAINTY EXPLAINER
# ============================================================================
# Step-by-step walkthrough of how we propagate ABS measurement uncertainty
# through slope estimation, and why AR(1) correlation matters.
#
# The main analysis (ABS_error_rates.R) uses simulate_slopes() which:
# 1. Takes GVA time series with known standard errors from ABS
# 2. Draws plausible alternative GVA values via Monte Carlo
# 3. Fits log-linear trends to each draw
# 4. Uses the spread of simulated slopes as "measurement uncertainty"
# 5. Combines this with OLS regression uncertainty in quadrature
#
# The key twist: measurement errors may be correlated across years
# (e.g. the same firms appear in the ABS sample year after year).
# AR(1) correlation (rho) controls this. The effect on slope uncertainty
# is non-monotonic and counter-intuitive:
#   - Moderate rho (e.g. 0.7) WIDENS slope spread — smooth, persistent
#     error drifts create pseudo-trends that the slope picks up.
#   - Only very high rho (close to 1) narrows slopes — near-perfect
#     correlation acts as a pure level shift that doesn't affect slope.
# This is the classic autocorrelation problem in time series regression.
# ============================================================================


## Section 1: Pick a single example series ----
# We'll use London, Scientific R&D — a sector where measurement uncertainty
# has a big impact on whether the growth trend is statistically significant.

itl1.cv <- read_csv('data/itl1_cv_withestimatederrorratefromABS.csv')

example <- itl1.cv %>%
  filter(Region_name == "Yorkshire and The Humber",
         qg('fabricated metal',SIC07_description))

cat("Example series: Y&H, fabricated metal\n")
cat("Years:", min(example$year), "-", max(example$year), "\n")
cat("GVA range:", round(min(example$value)), "-", round(max(example$value)), "£m\n")
cat("Typical CoV:", round(mean(example$CoV100), 1), "%\n\n")

# Plot the raw series with ABS error bars
p_series <- ggplot(example, aes(x = year, y = value)) +
  geom_ribbon(aes(ymin = gva_min95, ymax = gva_max95), alpha = 0.2, fill = "steelblue") +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  labs(title = "London: Scientific R&D — GVA with ABS measurement uncertainty",
       subtitle = "Shaded band = 95% CI from ABS standard errors",
       x = "Year", y = "GVA (£m, chained volume)") +
  theme_minimal()

# Fit OLS log-linear trend
ols_fit <- lm(log(value) ~ year, data = example)
ols_slope <- coef(ols_fit)["year"]
ols_se    <- summary(ols_fit)$coefficients["year", "Std. Error"]

cat("OLS slope (log scale):", round(ols_slope, 5), "\n")
cat("  = approx", round((exp(ols_slope) - 1) * 100, 2), "% annual growth\n")
cat("OLS SE:", round(ols_se, 5), "\n")
cat("OLS 95% CI:", round(ols_slope - 1.96 * ols_se, 5), "to",
    round(ols_slope + 1.96 * ols_se, 5), "\n")
cat("Crosses zero?", ols_slope - 1.96 * ols_se < 0 & ols_slope + 1.96 * ols_se > 0, "\n\n")

# Add trend line to plot
example_with_trend <- example %>%
  mutate(trend = exp(predict(ols_fit)))

p_series_with_trend <- p_series +
  geom_line(data = example_with_trend, aes(y = trend),
            colour = "red", linewidth = 0.8, linetype = "dashed") +
  annotate("text", x = min(example$year) + 1, y = max(example$value) * 0.95,
           label = paste0("OLS trend: ", round((exp(ols_slope) - 1) * 100, 1), "% p.a."),
           hjust = 0, colour = "red", size = 3.5)

print(p_series_with_trend)


## Section 2: Log-normal parameterisation ----
# Why log-normal? GVA can't be negative, and the ABS errors are proportional
# to the level (that's what CoV means). A normal distribution centred on
# the GVA value with SD = SE could produce negative draws. Log-normal avoids this
# and naturally gives right skew for larger uncertainties.
#
# The trick: parameterise log-normal so its MEAN = observed GVA and its
# spread matches the ABS SE.
#
# Given: value (GVA), SE
#   sigma^2 = log(1 + (SE/value)^2)     — log-normal shape parameter
#   mu      = log(value) - sigma^2 / 2  — log-normal location parameter
#
# These ensure: E[X] = exp(mu + sigma^2/2) = value  (mean matches observed)
#               Var[X] ≈ SE^2 for small CoV         (spread matches SE)

example_params <- example %>%
  mutate(
    lnorm_sigma2 = log(1 + (SE / value)^2),
    lnorm_sigma  = sqrt(lnorm_sigma2),
    lnorm_mu     = log(value) - lnorm_sigma2 / 2
  )

cat("Log-normal parameters for each year:\n")
example_params %>%
  select(year, value, SE, CoV100, lnorm_mu, lnorm_sigma) %>%
  mutate(across(c(lnorm_mu, lnorm_sigma), ~round(., 4))) %>%
  print(n = Inf)

# Visual comparison: log-normal vs normal for one year
demo_year <- example_params %>% filter(year == 2018)
x_range <- seq(demo_year$value * 0.4, demo_year$value * 1.8, length.out = 500)

densities <- tibble(
  x = rep(x_range, 2),
  density = c(
    dlnorm(x_range, meanlog = demo_year$lnorm_mu, sdlog = demo_year$lnorm_sigma),
    dnorm(x_range, mean = demo_year$value, sd = demo_year$SE)
  ),
  Distribution = rep(c("Log-normal", "Normal"), each = length(x_range))
)

p_distributions <- ggplot(densities, aes(x = x, y = density, colour = Distribution)) +
  geom_line(linewidth = 1) +
  geom_vline(xintercept = demo_year$value, linetype = "dashed", alpha = 0.5) +
  geom_vline(xintercept = 0, linetype = "dotted", colour = "red", alpha = 0.5) +
  annotate("text", x = 0, y = max(densities$density) * 0.9,
           label = "Zero\n(impossible)", colour = "red", hjust = -0.1, size = 3) +
  labs(title = paste0("Year ", demo_year$year, ": Log-normal vs Normal (GVA = ",
                      round(demo_year$value), ", SE = ", round(demo_year$SE), ")"),
       subtitle = "Log-normal stays positive; Normal can go negative for high CoV",
       x = "GVA (£m)", y = "Density") +
  theme_minimal() +
  theme(legend.position = "top")

print(p_distributions)


## Section 3: Independent draws (rho = 0) ----
# With rho = 0, each year's simulated GVA is drawn independently.
# This means year-to-year measurement errors are uncorrelated:
# a high draw in 2015 tells you nothing about whether 2016 will be high or low.
#
# Consequence: some simulated series will randomly tilt — high early, low late
# (or vice versa) — producing slopes very different from the OLS slope.

set.seed(42)
n_spaghetti <- 20

# Draw 20 independent simulated series
spaghetti_indep <- map_dfr(1:n_spaghetti, function(i) {
  example_params %>%
    mutate(
      sim_value = ifelse(
        !is.na(SE) & SE > 0,
        rlnorm(n(), meanlog = lnorm_mu, sdlog = lnorm_sigma),
        value
      ),
      sim_id = i
    )
})

# Plot spaghetti
p_spaghetti_indep <- ggplot() +
  geom_ribbon(data = example, aes(x = year, ymin = gva_min95, ymax = gva_max95),
              alpha = 0.15, fill = "steelblue") +
  geom_line(data = spaghetti_indep, aes(x = year, y = sim_value, group = sim_id),
            alpha = 0.3, colour = "orange") +
  geom_line(data = example, aes(x = year, y = value), linewidth = 1) +
  geom_point(data = example, aes(x = year, y = value), size = 2) +
  labs(title = "Independent draws (rho = 0): 20 simulated series",
       subtitle = "Orange lines = plausible GVA series given ABS measurement uncertainty",
       x = "Year", y = "GVA (£m)") +
  theme_minimal()

print(p_spaghetti_indep)

# Fit slopes to each simulated series
slopes_indep <- map_dfr(1:n_spaghetti, function(i) {
  sim_i <- spaghetti_indep %>% filter(sim_id == i)
  fit <- lm(log(sim_value) ~ year, data = sim_i)
  tibble(sim_id = i, slope = coef(fit)["year"])
})

# Fit slopes from more draws for a smoother histogram
set.seed(42)
n_histo <- 200

slopes_indep_many <- map_dfr(1:n_histo, function(i) {
  sim_data <- example_params %>%
    mutate(sim_value = ifelse(
      !is.na(SE) & SE > 0,
      rlnorm(n(), meanlog = lnorm_mu, sdlog = lnorm_sigma),
      value
    ))
  fit <- lm(log(sim_value) ~ year, data = sim_data)
  tibble(sim_id = i, slope = coef(fit)["year"])
})

p_slopes_indep <- ggplot(slopes_indep_many, aes(x = slope)) +
  geom_histogram(bins = 30, fill = "orange", alpha = 0.6, colour = "white") +
  geom_vline(xintercept = ols_slope, colour = "black", linewidth = 1, linetype = "dashed") +
  geom_vline(xintercept = 0, colour = "red", linewidth = 0.5) +
  annotate("text", x = ols_slope, y = Inf, label = "OLS slope", vjust = 2, hjust = -0.1) +
  labs(title = "Distribution of slopes from independent draws (rho = 0)",
       subtitle = paste0("SD of simulated slopes = ", round(sd(slopes_indep_many$slope), 5),
                         " — this is the measurement uncertainty contribution"),
       x = "Slope (log scale)", y = "Count") +
  theme_minimal()

print(p_slopes_indep)

cat("Independent draws (rho = 0):\n")
cat("  Slope SD from MC:", round(sd(slopes_indep_many$slope), 5), "\n")
cat("  OLS SE:          ", round(ols_se, 5), "\n\n")


## Section 4: AR(1) correlated draws (rho = 0.7) ----
# In reality, ABS measurement errors are probably correlated across years.
# The ABS samples overlapping sets of firms, so if the sample happens to
# over-represent high-GVA firms in 2015, it likely does so in 2016 too.
#
# We model this with an AR(1) process on the latent "error direction".
# Counter-intuitive result: moderate AR(1) correlation (rho = 0.7)
# actually WIDENS the slope distribution compared to independent errors.
# Why? The smooth, persistent error drifts create pseudo-trends that
# the regression slope picks up. Independent errors are noisier but
# cancel out more effectively across the time series.
#
# Only very high rho (close to 1) narrows slopes — when errors are
# near-perfectly correlated, they act as a pure level shift that
# doesn't affect the slope at all. Section 7 below shows this curve.

# --- Step 4a: The AR(1) z-sequence ---
# Generate a sequence of standard normals with AR(1) correlation:
#   z[1] ~ N(0, 1)
#   z[t] = rho * z[t-1] + sqrt(1 - rho^2) * N(0, 1)
#
# The sqrt(1 - rho^2) scaling ensures Var(z[t]) = 1 for all t (stationary).
# Higher rho = smoother sequence = more persistent shifts.

rho <- 0.7
n_years <- nrow(example_params)

set.seed(123)
# Show 5 example z-sequences
z_examples <- map_dfr(1:5, function(seq_id) {
  z <- numeric(n_years)
  z[1] <- rnorm(1)
  for (t in 2:n_years) {
    z[t] <- rho * z[t - 1] + sqrt(1 - rho^2) * rnorm(1)
  }
  tibble(year = example_params$year, z = z, sequence = paste0("Seq ", seq_id))
})

# Also show independent z for comparison
z_indep <- map_dfr(1:5, function(seq_id) {
  tibble(year = example_params$year, z = rnorm(n_years),
         sequence = paste0("Seq ", seq_id))
})

p_z_compare <- (
  ggplot(z_indep, aes(x = year, y = z, colour = sequence)) +
    geom_line(linewidth = 0.8) + geom_point(size = 1.5) +
    geom_hline(yintercept = 0, linetype = "dotted") +
    labs(title = "Independent z-sequences (rho = 0)", y = "z value") +
    theme_minimal() + theme(legend.position = "none") +
    ylim(-3, 3)
) / (
  ggplot(z_examples, aes(x = year, y = z, colour = sequence)) +
    geom_line(linewidth = 0.8) + geom_point(size = 1.5) +
    geom_hline(yintercept = 0, linetype = "dotted") +
    labs(title = "AR(1) z-sequences (rho = 0.7)", y = "z value", x = "Year") +
    theme_minimal() + theme(legend.position = "none") +
    ylim(-3, 3)
) +
  plot_annotation(
    title = "Latent z-sequences: independent vs AR(1)",
    subtitle = "AR(1) sequences are smoother — errors persist across years"
  )

print(p_z_compare)

# --- Step 4b: Gaussian copula transform ---
# The z-values are standard normal. To get log-normal GVA draws:
#   1. z → pnorm(z) = u    (uniform on [0, 1])
#   2. u → qlnorm(u, mu, sigma) = simulated GVA   (log-normal marginal)
#
# This "Gaussian copula" preserves the AR(1) correlation structure
# while ensuring each year's marginal distribution is log-normal with
# the correct mean and spread.

# Demonstrate the transform for one z-sequence
demo_z <- z_examples %>% filter(sequence == "Seq 1")
demo_transform <- demo_z %>%
  left_join(example_params %>% select(year, value, SE, lnorm_mu, lnorm_sigma),
            by = "year") %>%
  mutate(
    u = pnorm(z),              # Step 1: normal CDF → uniform
    sim_value = qlnorm(u, meanlog = lnorm_mu, sdlog = lnorm_sigma)  # Step 2: inverse CDF → log-normal
  )

cat("Copula transform for one sequence (Seq 1):\n")
demo_transform %>%
  select(year, z, u, value, sim_value) %>%
  mutate(across(c(z, u), ~round(., 3)),
         shift_pct = round((sim_value / value - 1) * 100, 1)) %>%
  print(n = Inf)

cat("\nNotice: when z is persistently positive (or negative), ALL years shift",
    "in the same direction.\nBut the drift is not perfectly uniform — it creates",
    "smooth pseudo-trends\nthat the regression slope picks up, WIDENING the slope",
    "distribution vs independent errors.\n\n")

# --- Step 4c: Correlated spaghetti ---
set.seed(42)

# Helper: generate one AR(1) correlated series
draw_ar1_series <- function(params, rho) {
  n <- nrow(params)
  z <- numeric(n)
  z[1] <- rnorm(1)
  for (t in 2:n) {
    z[t] <- rho * z[t - 1] + sqrt(1 - rho^2) * rnorm(1)
  }
  params %>%
    mutate(sim_value = ifelse(
      !is.na(SE) & SE > 0,
      qlnorm(pnorm(z), meanlog = lnorm_mu, sdlog = lnorm_sigma),
      value
    ))
}

spaghetti_ar1 <- map_dfr(1:n_spaghetti, function(i) {
  draw_ar1_series(example_params, rho = 0.7) %>% mutate(sim_id = i)
})

p_spaghetti_ar1 <- ggplot() +
  geom_ribbon(data = example, aes(x = year, ymin = gva_min95, ymax = gva_max95),
              alpha = 0.15, fill = "steelblue") +
  geom_line(data = spaghetti_ar1, aes(x = year, y = sim_value, group = sim_id),
            alpha = 0.3, colour = "purple") +
  geom_line(data = example, aes(x = year, y = value), linewidth = 1) +
  geom_point(data = example, aes(x = year, y = value), size = 2) +
  labs(title = "AR(1) correlated draws (rho = 0.7): 20 simulated series",
       subtitle = "Purple lines show smooth persistent drifts — these create pseudo-trends affecting slopes",
       x = "Year", y = "GVA (£m)") +
  theme_minimal()

# Side-by-side spaghetti comparison
p_spaghetti_compare <- (
  p_spaghetti_indep + labs(title = "Independent (rho = 0)") +
    coord_cartesian(ylim = range(c(spaghetti_indep$sim_value, spaghetti_ar1$sim_value)))
) | (
  p_spaghetti_ar1 + labs(title = "AR(1) correlated (rho = 0.7)") +
    coord_cartesian(ylim = range(c(spaghetti_indep$sim_value, spaghetti_ar1$sim_value)))
) +
  plot_annotation(
    title = "Independent vs AR(1) simulated series",
    subtitle = "Independent errors are noisy but cancel out; correlated errors drift smoothly, creating pseudo-trends"
  )

print(p_spaghetti_compare)


## Section 5: Side-by-side slope distribution comparison ----
# Now the key result: moderate AR(1) correlation WIDENS the slope distribution.
# The smooth persistent drifts from AR(1) errors masquerade as trends.

set.seed(42)

# 200 slopes from AR(1) draws
slopes_ar1_many <- map_dfr(1:n_histo, function(i) {
  sim_data <- draw_ar1_series(example_params, rho = 0.7)
  fit <- lm(log(sim_value) ~ year, data = sim_data)
  tibble(sim_id = i, slope = coef(fit)["year"])
})

# Combine for overlaid density plot
slopes_compare <- bind_rows(
  slopes_indep_many %>% mutate(method = "Independent (rho = 0)"),
  slopes_ar1_many   %>% mutate(method = "AR(1) (rho = 0.7)")
)

# Compute SDs first so we can add reference lines to the plot
sd_indep <- sd(slopes_indep_many$slope)
sd_ar1   <- sd(slopes_ar1_many$slope)

p_slopes_compare <- ggplot(slopes_compare, aes(x = slope, fill = method)) +
  geom_histogram(aes(y = after_stat(density)), bins = 35, alpha = 0.5,
                 colour = "white", position = "identity") +
  geom_vline(xintercept = ols_slope, linewidth = 1, linetype = "dashed") +
  geom_vline(xintercept = 0, colour = "red", linewidth = 0.5) +
  # Show ±1 SD ranges as bracketing lines
  geom_vline(xintercept = ols_slope + c(-1, 1) * sd_indep,
             colour = "orange", linewidth = 0.6, linetype = "dotted") +
  geom_vline(xintercept = ols_slope + c(-1, 1) * sd_ar1,
             colour = "purple", linewidth = 0.6, linetype = "dotted") +
  annotate("text", x = ols_slope, y = Inf, label = "OLS slope", vjust = 2, hjust = -0.1) +
  annotate("text", x = 0, y = Inf, label = "Zero growth", vjust = 2, hjust = 1.1,
           colour = "red", size = 3) +
  scale_fill_manual(values = c("Independent (rho = 0)" = "orange",
                               "AR(1) (rho = 0.7)" = "purple")) +
  labs(title = "Slope distributions: independent vs AR(1) correlated draws",
       subtitle = "AR(1) is WIDER — correlated errors create pseudo-trends. Dotted lines = ±1 SD.",
       x = "Slope (log scale)", y = "Density", fill = NULL) +
  theme_minimal() +
  theme(legend.position = "top")

print(p_slopes_compare)

cat("Slope SD comparison:\n")
cat("  Independent (rho = 0): ", round(sd_indep, 5), "\n")
cat("  AR(1) (rho = 0.7):    ", round(sd_ar1, 5), "\n")
cat("  Change:                ", round((sd_ar1 / sd_indep - 1) * 100, 1), "% wider\n\n")


## Section 6: Quadrature combination ----
# The final step combines TWO independent sources of uncertainty:
#
# 1. OLS regression uncertainty (se_ols): how precisely we can estimate
#    the slope even if the data were perfectly measured. This comes from
#    the scatter of points around the trend line.
#
# 2. Measurement uncertainty (slope_sd): how much the slope would change
#    if we re-measured GVA with different ABS samples. This is what the
#    MC simulation captures.
#
# These are independent, so we combine in quadrature (Pythagorean addition):
#   se_combined = sqrt(se_ols^2 + slope_sd^2)

cat("=== Final uncertainty decomposition ===\n\n")

# Compute for both rho values
se_combined_indep <- sqrt(ols_se^2 + sd_indep^2)
se_combined_ar1   <- sqrt(ols_se^2 + sd_ar1^2)

cat("Source                    | rho = 0    | rho = 0.7\n")
cat("--------------------------|------------|----------\n")
cat(sprintf("OLS SE                    | %10.5f | %10.5f\n", ols_se, ols_se))
cat(sprintf("MC slope SD               | %10.5f | %10.5f\n", sd_indep, sd_ar1))
cat(sprintf("Combined SE (quadrature)  | %10.5f | %10.5f\n", se_combined_indep, se_combined_ar1))
cat(sprintf("SE inflation ratio        | %10.2fx  | %10.2fx\n",
            se_combined_indep / ols_se, se_combined_ar1 / ols_se))
cat("\n")

# Does the 95% CI cross zero?
ci_ols   <- c(ols_slope - 1.96 * ols_se, ols_slope + 1.96 * ols_se)
ci_indep <- c(ols_slope - 1.96 * se_combined_indep, ols_slope + 1.96 * se_combined_indep)
ci_ar1   <- c(ols_slope - 1.96 * se_combined_ar1,   ols_slope + 1.96 * se_combined_ar1)

cat("95% CI crosses zero?\n")
cat("  OLS only:              ", ci_ols[1] < 0 & ci_ols[2] > 0, "\n")
cat("  Combined (rho = 0):    ", ci_indep[1] < 0 & ci_indep[2] > 0, "\n")
cat("  Combined (rho = 0.7):  ", ci_ar1[1] < 0 & ci_ar1[2] > 0, "\n\n")

# Visual: stacked bars showing uncertainty decomposition
decomp <- tibble(
  scenario = factor(c("OLS only", "Combined\n(rho = 0)", "Combined\n(rho = 0.7)"),
                    levels = c("OLS only", "Combined\n(rho = 0)", "Combined\n(rho = 0.7)")),
  ols_var = ols_se^2,
  mc_var = c(0, sd_indep^2, sd_ar1^2)
) %>%
  pivot_longer(cols = c(ols_var, mc_var), names_to = "source", values_to = "variance") %>%
  mutate(
    source = factor(ifelse(source == "ols_var", "OLS regression", "Measurement (MC)"),
                    levels = c("Measurement (MC)", "OLS regression"))
  )

p_decomp <- ggplot(decomp, aes(x = scenario, y = variance, fill = source)) +
  geom_col(width = 0.6) +
  scale_fill_manual(values = c("OLS regression" = "steelblue", "Measurement (MC)" = "orange")) +
  labs(title = "Variance decomposition: OLS regression vs measurement uncertainty",
       subtitle = "Stacked bars show variance contributions (SE² components that add in quadrature)",
       x = NULL, y = "Variance (slope²)", fill = NULL) +
  theme_minimal() +
  theme(legend.position = "top")

print(p_decomp)

# Final confidence interval comparison
ci_plot_data <- tibble(
  scenario = factor(c("OLS only", "Combined (rho = 0)", "Combined (rho = 0.7)"),
                    levels = c("Combined (rho = 0)", "Combined (rho = 0.7)", "OLS only")),
  slope = ols_slope,
  se = c(ols_se, se_combined_indep, se_combined_ar1),
  lo95 = slope - 1.96 * se,
  hi95 = slope + 1.96 * se
)

p_ci_compare <- ggplot(ci_plot_data, aes(y = scenario, x = slope)) +
  geom_vline(xintercept = 0, colour = "red", linewidth = 0.5) +
  geom_errorbarh(aes(xmin = lo95, xmax = hi95), height = 0.2, linewidth = 0.8) +
  geom_point(size = 3) +
  annotate("text", x = 0, y = 3.4, label = "Zero growth", colour = "red", size = 3) +
  labs(title = "95% confidence intervals: effect of measurement uncertainty on slope",
       subtitle = "Adding measurement uncertainty widens CIs; AR(1) correlation widens them further",
       x = "Slope (log scale = approx. annual growth rate)", y = NULL) +
  theme_minimal()

print(p_ci_compare)

cat("\n=== Summary ===\n")
cat("1. ABS measurement errors add uncertainty beyond what OLS captures\n")
cat("2. If errors are independent (rho = 0), they add noise but cancel out fairly well across years\n")
cat("3. Moderate AR(1) correlation (rho = 0.7) WIDENS slope spread — smooth drifts create pseudo-trends\n")
cat("4. Only very high rho (near 1) narrows slopes — near-uniform level shifts don't affect slope\n")
cat("5. Both sources combine in quadrature: se_combined = sqrt(se_ols^2 + slope_sd^2)\n")
cat("6. The choice of rho matters: see Section 7 for how slope SD varies across the full rho range\n")


## Section 7: Slope SD vs rho — the full curve ----
# How does slope uncertainty from measurement error vary across the full
# range of rho from 0 (independent) to ~1 (near-perfect correlation)?
#
# Analytically, for OLS slope with AR(1) errors and T evenly-spaced years:
#   Var(slope) = sigma^2 * [sum_s sum_t c_s c_t rho^|s-t|] / [sum(c^2)]^2
# where c_t = (t - t_bar) are the OLS contrast weights.
#
# This is non-monotonic: it rises from rho=0, peaks around rho=0.8-0.9
# (for T=11), then drops sharply toward 0 as rho -> 1.

# Compute analytically for a range of rho values
T_years <- n_years
t_vals  <- 1:T_years
t_bar   <- mean(t_vals)
c_vals  <- t_vals - t_bar  # OLS contrast weights (unnormalised)
ss      <- sum(c_vals^2)   # = sum of squared deviations

rho_grid <- seq(0, 0.99, by = 0.01)

# For each rho, compute Var(slope) / sigma^2 analytically
slope_var_ratio <- map_dbl(rho_grid, function(r) {
  # Build the AR(1) correlation matrix
  S <- outer(1:T_years, 1:T_years, function(i, j) r^abs(i - j))
  # Var(slope) proportional to c' S c / (sum c^2)^2
  as.numeric(t(c_vals) %*% S %*% c_vals) / ss^2
})

# Normalise relative to rho=0 (where ratio = 1/ss)
relative_var <- slope_var_ratio / slope_var_ratio[1]

# Also get MC estimates at a few rho values to validate
set.seed(42)
rho_mc_points <- c(0, 0.3, 0.5, 0.7, 0.9, 0.95, 0.99)
# rho_mc_points <- seq(from = 0.1, to = 0.95, by = 0.05)
n_mc <- 200

mc_sds <- map_dfr(rho_mc_points, function(r) {
  slopes <- map_dbl(1:n_mc, function(i) {
    if (r == 0) {
      sim_data <- example_params %>%
        mutate(sim_value = ifelse(
          !is.na(SE) & SE > 0,
          rlnorm(n(), meanlog = lnorm_mu, sdlog = lnorm_sigma),
          value
        ))
    } else {
      sim_data <- draw_ar1_series(example_params, rho = r)
    }
    coef(lm(log(sim_value) ~ year, data = sim_data))["year"]
  })
  tibble(rho = r, mc_sd = sd(slopes))
})

# Normalise MC SDs relative to rho=0
mc_sd_at_0 <- mc_sds$mc_sd[mc_sds$rho == 0]
mc_sds <- mc_sds %>% mutate(relative_sd = mc_sd / mc_sd_at_0)

analytic_curve <- tibble(
  rho = rho_grid,
  relative_sd = sqrt(relative_var)  # SD is sqrt of variance ratio
)

p_rho_curve <- ggplot() +
  geom_line(data = analytic_curve, aes(x = rho, y = relative_sd),
            linewidth = 1, colour = "steelblue") +
  geom_point(data = mc_sds, aes(x = rho, y = relative_sd),
             size = 3, colour = "red") +
  geom_hline(yintercept = 1, linetype = "dashed", alpha = 0.5) +
  annotate("text", x = 0.05, y = 1.05, label = "rho = 0 baseline",
           hjust = 0, size = 3, alpha = 0.6) +
  labs(title = "Slope SD vs rho: the non-monotonic relationship",
       subtitle = paste0("Blue = analytic (T=", T_years,
                         "); Red dots = MC validation (", n_mc, " draws). ",
                         "Peak around rho = ",
                         rho_grid[which.max(analytic_curve$relative_sd)]),
       x = "rho (AR(1) correlation)", y = "Slope SD (relative to rho = 0)") +
  scale_x_continuous(breaks = seq(0, 1, 0.1)) +
  theme_minimal()

print(p_rho_curve)

# Find and report the peak and crossover
peak_rho <- rho_grid[which.max(analytic_curve$relative_sd)]
peak_mult <- max(analytic_curve$relative_sd)
crossover_rho <- rho_grid[min(which(analytic_curve$relative_sd < 1 & rho_grid > peak_rho))]

cat("=== Slope SD vs rho analysis ===\n")
cat("  Peak at rho =", peak_rho, "where SD is", round(peak_mult, 2), "x the independent baseline\n")
cat("  Crossover (SD drops below independent) at rho =", crossover_rho, "\n")
cat("  At rho = 0.99, SD is", round(analytic_curve$relative_sd[rho_grid == 0.99], 2),
    "x baseline\n\n")
cat("Implication: unless measurement errors are very highly correlated (rho >",
    crossover_rho, "),\n")
cat("AR(1) correlation INCREASES the impact of measurement uncertainty on slopes.\n")
cat("This is the classic autocorrelation problem in time series regression:\n")
cat("smooth persistent errors masquerade as trends.\n")

