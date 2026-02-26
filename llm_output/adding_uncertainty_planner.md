# Adding per-year GVA uncertainty to OLS growth rate slopes

## Context

We have per-year uncertainty on GVA values (standard errors / coefficients of variation from the ABS quality measures). Currently, OLS slopes on `log(value) ~ year` give annualised growth rates per sector/region, with standard errors coming either from OLS residuals or Newey-West corrections. These SE bars are then compared across places to ask: "has sector X grown significantly more in region A than region B?"

But the OLS residuals only capture year-to-year noise *around the trend*. They don't account for the fact that each year's GVA value is itself uncertain. A region might show apparent growth simply because the early years happened to be under-measured and the later years over-measured. The question is how to fold in the per-year measurement uncertainty.

---

## (1) Monte Carlo simulation approach: resample then OLS

**The idea:** Exactly analogous to the LQ simulation already in ABS_error_rates.R. For each MC iteration:

1. Draw a plausible GVA value for every sector/region/year from the log-normal distribution parameterised by the observed value and SE (as already done for LQs).
2. Fit `log(sim_value) ~ year` via OLS for each sector/region group.
3. Collect the slope from each draw.
4. After N draws, take the median slope and the 2.5th/97.5th percentiles as the simulated CI on the growth rate.

**Pros:**
- Very simple to implement — reuses the existing log-normal draw infrastructure.
- Naturally propagates both sources of uncertainty: the measurement error in each year *and* the trend-fitting uncertainty.
- Easy to vary confidence level (just change the quantile cutoffs: 5th/95th for 90%, 2.5/97.5 for 95%, 0.5/99.5 for 99%).
- Produces a full distribution of slopes, so you can show users density plots, not just point + CI.

**Cons / things to think about:**
- Each MC draw fits OLS independently, so it captures measurement uncertainty but the OLS SE *within* each draw still exists. The MC distribution of slopes will typically be **wider** than vanilla OLS SE but **narrower** than if you also bootstrapped residuals. That's probably fine — we're interested in the *additional* uncertainty from measurement, not replacing the residual uncertainty.
- Actually: the MC slope distribution will reflect both sources. If measurement error is small relative to year-to-year variation, the MC CIs will be similar to the original OLS CIs. If measurement error is large (small sectors), the MC CIs will be noticeably wider. This is exactly the behaviour we want.
- Correlation across years: the simulation treats each year's draw as independent. In reality, measurement errors might be correlated across years (same firms in sample, similar methodology). If errors are positively correlated, the simulation may *overstate* slope uncertainty (because correlated errors shift the whole series up or down rather than tilting it). This is probably conservative, which is OK for a "what if" scenario tool.
- Could optionally add within-draw Newey-West SEs too, giving a "double robust" version — but probably overkill for the scenario-exploration purpose.

**Implementation sketch (R pseudocode):**
```r
simulate_slopes <- function(data, n_sims = 500, seed = 42) {
  set.seed(seed)

  sim_params <- data %>%
    mutate(
      has_se = !is.na(SE) & SE > 0 & value > 0,
      lnorm_sigma2 = ifelse(has_se, log(1 + (SE / value)^2), NA),
      lnorm_sigma  = ifelse(has_se, sqrt(lnorm_sigma2), NA),
      lnorm_mu     = ifelse(has_se, log(value) - lnorm_sigma2 / 2, NA)
    )

  map_dfr(1:n_sims, function(i) {
    sim_data <- sim_params %>%
      mutate(sim_value = ifelse(
        has_se,
        rlnorm(n(), meanlog = lnorm_mu, sdlog = lnorm_sigma),
        value
      ))

    get_slope_and_se_safely(sim_data, Region_name, SIC07_description,
                            y = log(sim_value), x = year) %>%
      mutate(sim_id = i)
  })
}

# Then summarise:
sim_slopes %>%
  group_by(Region_name, SIC07_description) %>%
  summarise(
    slope_median = median(slope),
    slope_p025 = quantile(slope, 0.025),
    slope_p975 = quantile(slope, 0.975)
  )
```

**Verdict:** This is probably the simplest and most flexible approach. It directly answers "what happens to my growth rate estimates if I take measurement uncertainty seriously?" and it's easy to wire into an interactive tool with adjustable CI widths.

---

## (2) Other approaches to incorporate per-year uncertainty into OLS slopes

### 2a. Weighted Least Squares (WLS)

Weight each observation by `1 / SE^2` (or `1 / CoV^2` if working in log space). Years with larger uncertainty get downweighted.

- **Pros:** Analytically simple, one-line change (`lm(..., weights = 1/SE^2)`). Produces correct SEs under heteroscedasticity from measurement error.
- **Cons:** Only adjusts *efficiency* (which years matter most), not the SE on the slope itself in the way we want. The slope SE from WLS reflects residual variation around the weighted fit, not the measurement uncertainty directly. It won't widen CIs in the way the MC approach does. Also, WLS assumes the weights are *known* — it doesn't propagate uncertainty in the weights themselves.
- **Verdict:** Useful as a robustness check (do the slopes change much when we downweight noisy years?) but doesn't directly give "CIs incorporating measurement uncertainty."

### 2b. Errors-in-variables / measurement error models

The classical problem: if `x` is measured with error, OLS is biased. Here it's `y` (GVA) that's measured with error, not `x` (year). Measurement error in `y` doesn't bias OLS slopes — it inflates residual variance and widens SEs. So strictly, OLS slopes are unbiased even with noisy GVA, and the OLS SEs already partly reflect this.

But: the OLS residual variance is an *average* across all years. If some years are much noisier than others (heteroscedastic measurement error), OLS SEs are inefficient. WLS (above) handles that. And if we want to explicitly quantify "how much of the residual variance is measurement error vs real volatility", we'd need a more structured model.

- **Verdict:** Mostly a conceptual reassurance that OLS isn't *biased* by the measurement error in GVA. But it doesn't help us *separate* trend uncertainty from measurement uncertainty, which is what the MC approach does well.

### 2c. Bayesian regression with known measurement error

Formulate as:
```
observed_GVA[t] ~ Normal(true_GVA[t], SE[t])   # measurement model
log(true_GVA[t]) = alpha + beta * year[t]        # trend model
```

This is a proper measurement error model. Could fit with `brms` or `Stan`. It separates measurement noise from trend, gives a posterior on `beta` (the growth rate) that correctly incorporates both sources of uncertainty.

- **Pros:** Statistically the "right" answer. Posterior on beta directly answers the question.
- **Cons:** Much heavier machinery. Requires specifying priors. Slower. Harder to explain to non-stats audiences. Probably overkill for scenario exploration.
- **Verdict:** Worth knowing about as the "gold standard" but the MC simulation approach gives similar answers with much less complexity, especially when the goal is interactive exploration rather than publishable inference.

### 2d. Bootstrap combining both uncertainty sources

A "double bootstrap":
1. Outer loop: draw GVA values from measurement uncertainty (as in MC approach).
2. Inner loop: resample residuals from the OLS fit on the drawn data.
3. Collect slopes.

This captures both measurement uncertainty *and* small-sample trend-fitting uncertainty.

- **Verdict:** More thorough than pure MC but slower (N_outer x N_inner fits). The pure MC approach already captures most of the relevant uncertainty for our purposes.

---

## (3) More robust time series approaches

### 3a. State space models / local linear trend

Instead of fitting a single OLS slope across all years, model the *level* and *trend* as latent states that evolve over time:

```
Level[t] = Level[t-1] + Trend[t-1] + eta_level
Trend[t] = Trend[t-1] + eta_trend
Observed[t] = Level[t] + epsilon[t]   (where epsilon variance = SE[t]^2)
```

The Kalman filter/smoother estimates the latent level and trend at each time point, naturally incorporating the known observation uncertainty (SE[t]).

- **Pros:** Handles time-varying trends (a sector might grow fast early on, slow later). Directly incorporates per-year SEs. Gives filtered/smoothed estimates with CIs at each time point.
- **Cons:** More parameters to tune (process noise variances). With only ~12 years of data (2012-2023), there isn't much information to estimate time-varying trends — the model might overfit or require strong priors. Conceptually more complex to explain.
- **R packages:** `dlm`, `KFAS`, `bsts` (Bayesian structural time series).
- **Verdict:** Interesting for sectors where we suspect the trend has changed direction (e.g. pre/post-COVID). But for comparing average growth rates across places, a single slope is often more interpretable.

### 3b. Generalised Least Squares (GLS) with known heteroscedasticity

Fit `log(GVA) ~ year` but specify the variance structure: `Var(epsilon_t) = SE_t^2 + sigma^2_process`, where `SE_t` is the known measurement SE and `sigma^2_process` is the "real" year-to-year volatility (estimated from the data).

- **R:** `nlme::gls()` with a `varFixed()` or custom `varFunc`.
- **Pros:** Analytically clean. Gives correct SEs on the slope that incorporate heteroscedastic measurement error.
- **Cons:** Assumes the structure is correct. Doesn't give as intuitive a "what if" feel as the MC approach.
- **Verdict:** Good for a robust single estimate. Less flexible for scenario exploration.

### 3c. Scenario-oriented approach: adjustable CI viewer

Given the user's stated interest in interactive exploration ("allowing user to see what difference changing between 90/95/99 CIs makes"), the MC simulation approach from (1) is probably the best foundation. Here's how it maps to a viewer:

1. **Run the MC simulation once** with a large N (e.g. 1000 draws). Store all slope draws per sector/region.
2. **In the viewer**, let the user select a CI level. Compute quantiles on the fly from the stored draws: `quantile(slopes, c((1-CI)/2, (1+CI)/2))`.
3. **Display:** slope point estimate + adjustable error bars. Colour-code pairs where CIs don't overlap (as already done for the year-on-year growth plots).
4. **Add a "measurement uncertainty on/off" toggle:** show vanilla OLS CIs vs MC-augmented CIs side by side, so users can see how much the measurement error matters for each sector.

This is probably the highest-value output: it lets users build intuition about when measurement uncertainty does and doesn't matter for growth rate comparisons.

---

## Summary / recommended path

| Approach | Complexity | Best for |
|----------|-----------|----------|
| MC simulation (1) | Low | Interactive scenario tool, adjustable CIs, direct comparison with vanilla OLS |
| WLS (2a) | Very low | Quick robustness check |
| Bayesian (2c) | High | Publication-quality inference |
| State space (3a) | Medium-high | Time-varying trends, short series with structural breaks |
| GLS (3b) | Medium | Single robust slope estimate |

**Recommended first step:** Implement the MC simulation approach (1). It's a natural extension of the existing LQ simulation code, directly answers the motivating question, and provides the raw material for an interactive viewer with adjustable confidence levels.

**Key question to resolve:** Whether to treat year-to-year measurement errors as independent (current assumption) or introduce some correlation structure. Independent is simpler and probably conservative (wider CIs on slopes). If the ABS samples are largely the same firms year to year, positive correlation would *narrow* the slope CIs (because correlated errors shift the series up/down uniformly rather than tilting it). Starting with independent draws and noting this caveat seems reasonable.
