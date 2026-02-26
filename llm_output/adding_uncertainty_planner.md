# Adding per-year GVA uncertainty to OLS growth rate slopes

Claude-drafted doc based on prompts [here](https://github.com/DanOlner/RegEconWorks/blob/master/llm_convos/2026-02-26_1036_The_user_opened_the_file_UsersdanolnerCodeRegecon_.md), 26th Feb 2026.

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

---

## Addendum: handling autocorrelation in the MC draws

The caveat above is about whether measurement errors are correlated across years. If the ABS samples overlap year-to-year, then the "noise" in 2018's GVA estimate is not independent of 2019's — both are partly driven by the same firms being over/under-represented. Drawing independently from each year's uncertainty distribution ignores this and probably *overstates* how much the slope can wobble (because independent draws can tilt the series unrealistically).

Several lightweight options that work with what we already have:

### A. Correlated draws via a simple AR(1) structure on the measurement error

Instead of drawing each year's perturbation independently, draw a correlated sequence. The idea:

1. Pick a correlation parameter `rho` (e.g. 0.5, 0.7, 0.9 — or let the user toggle it).
2. For each sector/region, generate a correlated standard-normal sequence `z[1], ..., z[T]` where `z[t] = rho * z[t-1] + sqrt(1 - rho^2) * eps[t]`, with `eps[t] ~ N(0,1)`.
3. Transform: `sim_value[t] = qlnorm(pnorm(z[t]), meanlog = lnorm_mu[t], sdlog = lnorm_sigma[t])`.

This uses the Gaussian copula trick: the marginal distribution for each year is still the correct log-normal (matching the observed value and SE), but the draws are correlated across time. High `rho` means the whole series shifts up or down together (narrower slope CIs); low `rho` recovers the independent case (wider slope CIs).

```r
# Pseudocode for correlated draws
draw_correlated <- function(n_years, rho) {
  z <- numeric(n_years)
  z[1] <- rnorm(1)
  for(t in 2:n_years) {
    z[t] <- rho * z[t-1] + sqrt(1 - rho^2) * rnorm(1)
  }
  z
}

# Then in the MC loop, per group:
z <- draw_correlated(n_years, rho = 0.7)
sim_value <- qlnorm(pnorm(z), meanlog = lnorm_mu, sdlog = lnorm_sigma)
```

**Why this is nice for our purposes:** it's a one-parameter knob (`rho`) that the user can adjust in the viewer alongside the CI level. "What if measurement errors are highly correlated (rho=0.9) vs nearly independent (rho=0.1)?" gives immediate intuition about whether the autocorrelation assumption matters for a given sector. And it slots straight into the existing MC loop — just replace the independent `rlnorm()` call with the correlated version.

### B. Block bootstrap on the MC draws

A cruder approach: instead of drawing each year independently, draw in blocks of 2-3 consecutive years from the same perturbation direction. E.g. for a block of size 2, years 2012-2013 share one draw from `{above mean, below mean}`, years 2014-2015 share another, etc. This implicitly introduces positive autocorrelation without parameterising it.

- **Pros:** Very simple, no extra parameters.
- **Cons:** Coarse — block size is arbitrary, and results are sensitive to it. Less interpretable than the `rho` parameter.
- **Verdict:** OK for a quick sanity check ("does blocking change the picture?") but the AR(1) copula approach above is barely more complex and much more flexible.

### C. Just compare independent vs Newey-West on the MC slopes

We already have `get_slope_and_se_safely` with a `neweywest = TRUE` option. A simple test:

1. Run the MC simulation with independent draws as planned.
2. For the *central estimate* (no MC), compare OLS SE vs Newey-West SE on the slopes.
3. If Newey-West SEs are much larger than OLS SEs, that tells us autocorrelation in the *residuals* (which includes measurement error) matters. The MC CIs should then be at least as wide as the Newey-West CIs — if they're not, we're probably underestimating correlation and should use approach A above.

This doesn't fix the MC draws themselves, but it gives a quick diagnostic: "are my MC CIs at least as conservative as Newey-West?" If yes, the independent-draw assumption is probably fine for illustration purposes. If no, bump up the correlation.

### D. Pragmatic recommendation for the scenario tool

For illustration purposes, the simplest path is:

1. **Default: independent draws** (what we'd implement first anyway).
2. **Add rho as a slider** in any interactive viewer (approach A). Default to 0, let user push to 0.3, 0.5, 0.7, 0.9.
3. **Show the Newey-West SE alongside** (approach C) as a reference line — "here's what the slope uncertainty looks like if we only account for residual autocorrelation, ignoring measurement uncertainty entirely."

This gives three layers the user can compare:
- Vanilla OLS SE (no autocorrelation, no measurement uncertainty)
- Newey-West SE (autocorrelation in residuals, no explicit measurement uncertainty)
- MC simulation SE (measurement uncertainty, adjustable autocorrelation via rho)

That three-way comparison is itself a useful finding: for which sectors/regions does it actually matter which approach you use?

---

## Visualisation: comparing original vs uncertainty-augmented slope results

### How the current viz works

**`slopeDiffGrid`** takes a slope+SE dataframe, computes CIs at a given confidence level, then tests all pairwise combinations for CI overlap. It renders a heatmap matrix (sector×sector or place×place) where:
- Cell fill = slope difference (red-white-green diverging scale)
- Cell border = black if CIs *don't* overlap (distinguishable), white if they do
- Axis labels are colour-coded green/red for whether each individual slope is significantly different from zero, with the annualised % change and CI range printed on the label

**`plotSlopeCounts`** builds on this. For a focal place (e.g. South Yorkshire), it runs `slopeDiffGrid` in two passes:
1. *Internal*: sector×sector within the focal place — "which sectors grew significantly differently from each other?"
2. *Cross-place*: for each sector, place×place — "for this sector, did the focal place grow significantly differently from other places?"

It then counts the sig-positive and sig-negative overlaps per sector and shows them as a diverging bar chart (percent of comparisons that are significantly different, split pos/neg). The result is a compact summary: "for each sector, how distinctive is this place's growth?"

### (a) Direct visual comparison: original vs uncertainty-augmented

The most natural approach is to **run `plotSlopeCounts` twice** — once with vanilla OLS slopes and once with MC-augmented slopes — and put them side by side. Specifically:

**Option A1: Side-by-side bar charts.** Two `plotSlopeCounts` panels sharing the same y-axis (sector list). Left = original OLS. Right = MC-augmented. The user immediately sees which sectors' bars shrink (i.e. fewer "significant" differences once measurement uncertainty is included). This is probably the single most informative comparison.

**Option A2: Overlay / dodged bars.** Single chart with dodged bars: one colour for "original OLS" counts, another for "MC-augmented" counts, same sector axis. More compact than side-by-side but potentially cluttered.

**Option A3: Delta chart.** Show only the *change*: for each sector, how many fewer (or more) significant slope differences survive once measurement uncertainty is added? A simple horizontal bar chart where bar length = (original count - MC count). Sectors where bars are longest are the ones where measurement uncertainty matters most for growth comparisons. This is the clearest "what difference did it make?" display.

**Option A4: Confidence interval sweep.** Run the MC simulation and extract slope CIs at 80%, 90%, 95%, 99%. For each CI level, count the number of significant pairwise differences. Plot a curve: x-axis = CI level, y-axis = % of comparisons that remain significant. Steep drops indicate that conclusions are fragile; flat curves indicate robustness. Could facet by sector or show as small multiples.

### (b) Better viz approaches than the full grid or percent-of-overlaps summary

The grid (`slopeDiffGrid`) is comprehensive but dense — with ~70 sectors it's a 70×70 matrix. The bar chart (`plotSlopeCounts`) compresses this to a 1D summary but loses the detail of *which* comparisons survive. Some alternatives:

**Option B1: "Survived vs lost" focused view.** Instead of showing the full grid, show only the comparisons that *change status* between original and MC-augmented. A table or dot plot listing: "Sector X in Place A vs Place B: originally significant (p=...), no longer significant with measurement uncertainty." This highlights the actionable differences — the cases where adding uncertainty actually changes the story.

**Option B2: Slope forest plot with dual CIs.** For a given sector across all regions (or a given region across all sectors), show a forest plot where each row has:
- A point for the slope estimate
- A thin error bar for the original OLS CI
- A wider, lighter error bar for the MC-augmented CI

This directly shows where measurement uncertainty widens the CIs enough to swallow zero or to overlap with another region's CI. Paired with the existing axis colouring (green/red for significantly different from zero), this would show at a glance which places lose their "significant growth" status.

**Option B3: Bump chart / rank change.** If we rank sectors by growth rate within a region, the MC simulation gives a distribution of ranks. Show: central rank vs range of plausible ranks. Sectors with wide rank ranges are the ones where we can't confidently say "this is the Nth fastest growing sector." This reframes the question from "is growth significant?" to "do we even know the ranking?" — often more intuitive for policy audiences.

**Option B4: "Certainty score" heatmap.** Replace the binary overlap/no-overlap in `slopeDiffGrid` with a continuous measure: what fraction of MC iterations show non-overlapping CIs for each pair? Cell colour goes from 0% (never distinguishable) through 50% (coin flip) to 100% (always distinguishable). This preserves the grid layout but replaces the sharp binary with a gradient that better represents the uncertainty. Could use a single-hue sequential scale (white→dark blue) rather than the red-green diverging scale.

**Option B5: The "percent overlap changes" summary — and why it might be enough.** The simplest version: just compute `plotSlopeCounts` for both original and MC slopes, and show the percentage of significant comparisons side by side. If the headline finding is "adding measurement uncertainty reduces the number of significantly different growth comparisons from 45% to 28%", that's a clear, citable result. It could be presented as:
- A single summary table (one row per place, columns = original %, MC %)
- A scatter plot: x = original %, y = MC %, with a 1:1 line. Points below the line = places where measurement uncertainty reduces distinguishability.

This is probably the right starting point. The fancier visualisations (B1-B4) are worth building later for interactive exploration, but the headline number — "what share of growth differences survive?" — is the first thing to compute and report.

### Recommended implementation order

1. **Get the MC slopes** (section 1 above).
2. **Run `plotSlopeCounts` on both** and produce side-by-side or delta bar charts (A1 or A3).
3. **Compute the headline summary** (B5): % of significant comparisons, original vs MC.
4. **Build the forest plot** (B2) for individual deep-dives.
5. **Add the certainty-score heatmap** (B4) if an interactive viewer is built.
6. **Wire up the CI-level sweep** (A4) and rho slider for the scenario tool.
