# Adding per-year GVA uncertainty to OLS growth rate slopes

Claude-drafted doc based on prompt back and forth [here](https://github.com/DanOlner/RegEconWorks/blob/master/llm_convos/2026-02-26_1036_The_user_opened_the_file_UsersdanolnerCodeRegecon_.md), 26th Feb 2026.

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
- Correlation across years: the simulation treats each year's draw as independent. In reality, measurement errors might be correlated across years (same firms in sample, similar methodology). If errors are positively correlated at moderate levels (e.g. rho = 0.7), the simulation actually *understates* slope uncertainty — correlated errors create smooth pseudo-trends that widen the slope distribution (see "Correction" section below). Only very high correlation (rho near 1) narrows slopes by acting as a pure level shift.
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

**Key question to resolve:** Whether to treat year-to-year measurement errors as independent (current assumption) or introduce some correlation structure. Independent is simpler but — counter-intuitively — produces *narrower* slope CIs than moderate AR(1) correlation. This is because moderate positive correlation (e.g. rho = 0.7) creates smooth persistent drifts that masquerade as trends, widening the slope distribution. Only very high correlation (rho near 1) narrows slopes by acting as a near-uniform level shift. See the "Correction" section below for the full analysis.

---

## Addendum: handling autocorrelation in the MC draws

The caveat above is about whether measurement errors are correlated across years. If the ABS samples overlap year-to-year, then the "noise" in 2018's GVA estimate is not independent of 2019's — both are partly driven by the same firms being over/under-represented. The effect of this correlation on slope uncertainty is non-monotonic and counter-intuitive — see the "Correction" section below for the full analysis. In short: moderate correlation *widens* slope uncertainty (not narrows it), so independent draws are actually the *conservative lower bound* on measurement-driven slope noise.

Several lightweight options that work with what we already have:

### A. Correlated draws via a simple AR(1) structure on the measurement error

Instead of drawing each year's perturbation independently, draw a correlated sequence. The idea:

1. Pick a correlation parameter `rho` (e.g. 0.5, 0.7, 0.9 — or let the user toggle it).
2. For each sector/region, generate a correlated standard-normal sequence `z[1], ..., z[T]` where `z[t] = rho * z[t-1] + sqrt(1 - rho^2) * eps[t]`, with `eps[t] ~ N(0,1)`.
3. Transform: `sim_value[t] = qlnorm(pnorm(z[t]), meanlog = lnorm_mu[t], sdlog = lnorm_sigma[t])`.

This uses the Gaussian copula trick: the marginal distribution for each year is still the correct log-normal (matching the observed value and SE), but the draws are correlated across time. The relationship between rho and slope uncertainty is non-monotonic: moderate rho (0.3-0.9) *widens* slope CIs (smooth drifts create pseudo-trends); only very high rho (near 1) narrows them (near-uniform level shift). See the "Correction" section below.

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

---

## How the AR(1) correlated draws work (and what they don't do)

### What the AR(1) controls — and what it doesn't

The AR(1) correlation parameter `rho` in `simulate_slopes()` controls how the *simulated GVA values* are drawn. It has nothing to do with the slope estimation itself — that's still plain OLS (`log(sim_value) ~ year`) every time. The AR(1) sits upstream of the regression, shaping the input data.

### The two stages

1. **Draw perturbed GVA values** for each year (using ABS standard errors). This is where `rho` matters.
2. **Fit OLS** on the perturbed values to get a slope. This is unchanged.

### What `rho` does to the draws

Each region x sector group has ~12 years of data. Each year has an observed GVA and an ABS standard error. In each MC iteration we need to pick a "what if" GVA for every year. The question is whether those 12 perturbations should be independent or connected.

**Independent draws (rho = 0):** Year 2012 might be drawn high, 2013 low, 2014 high, 2015 low... The perturbations bounce around randomly. This can create artificial tilts — if by chance the early years are drawn low and the late years high, the slope steepens. Across many draws, these random tilts create a wide spread of slopes. This is why the initial MC envelope was so large.

**Correlated draws (rho > 0):** The AR(1) process generates a sequence of standard normals where each one is pulled toward the previous one: `z[t] = rho * z[t-1] + sqrt(1 - rho^2) * noise`. If z[2012] happens to be +1.5 (drawing GVA high), then z[2013] will tend to be positive too — the series drifts smoothly. But this drift is not uniform: it creates smooth waves that look like real economic trends over 11 years. The regression picks these pseudo-trends up, *widening* the slope distribution compared to independent draws. Only very high rho (near 1) produces near-uniform level shifts that don't affect the slope. See the "Correction" section below for the analytic proof.

### The Gaussian copula step

The correlated z-values are standard normals. We need each year's simulated GVA to come from the correct log-normal distribution (matching that year's observed value and SE). The Gaussian copula does this in two steps:

1. `pnorm(z)` transforms the correlated normal to a uniform [0,1] — preserving the correlation structure.
2. `qlnorm(uniform, meanlog, sdlog)` maps the uniform to the correct log-normal for that year.

The result: each year's marginal distribution is exactly right (same mean and spread as the ABS uncertainty implies), but the draws are correlated across time.

### Why this matters for the ABS context

If the same firms are sampled year after year (which they largely are in the ABS), then if 2018's GVA estimate is biased high, 2019's probably is too — the measurement errors are positively correlated. Independent draws ignore this and produce choppy perturbations. However, contrary to initial intuition, the correlated case doesn't shrink the envelope — it *widens* it for moderate rho values, because the smooth persistent drifts create pseudo-trends that the slope regression picks up. The `rho` parameter lets you ask "what if measurement errors are 50% correlated year-to-year?" and see how the envelope changes.

### What rho does NOT do

- It doesn't change the regression method (still OLS).
- It doesn't model autocorrelation in the *real* GVA process (that's what Newey-West or state space models would do).
- It doesn't estimate `rho` from the data — it's a user-specified assumption. We don't know the true correlation of ABS measurement errors, so `rho` is a scenario parameter: "what if errors are this correlated?"

### Combining both uncertainty sources: quadrature, not min/max envelope

#### The envelope approach (abandoned)

An earlier version took the min/max of per-draw CIs (`slope ± 1.96 * se`) across all MC draws. This was problematic: with 500 draws, even one outlier draw with an unusually large OLS SE pushes the envelope out. The result was dominated by tail behaviour rather than typical uncertainty, and it didn't respond properly to `rho` — even with correlated draws, 500 chances to hit an extreme produced wide envelopes regardless.

#### The quadrature approach (current)

We have two independent sources of uncertainty about the growth rate slope:

1. **OLS regression uncertainty** (`se_ols`): with only ~12 time points, the scatter around the trend line means the slope isn't pinned down precisely. This is the standard OLS standard error from the original data.

2. **Measurement uncertainty** (`slope_sd`): the SD of slopes across MC draws. This measures how much the slope wobbles when you perturb each year's GVA within its ABS-reported standard error.

Because these two sources are independent (ABS sampling error has nothing to do with how well 12 points pin down a line), we combine them in quadrature:

```
se_combined = sqrt(se_ols^2 + slope_sd^2)
```

The 95% CI is then `slope ± 1.96 * se_combined`.

**Why this works well:**

- **Guaranteed to widen CIs**: `sqrt(a^2 + b^2) >= a`, so the combined CI is always at least as wide as vanilla OLS. Sectors with small ABS SEs (precise data) will have `slope_sd ≈ 0` and `se_combined ≈ se_ols` — measurement uncertainty barely registers. Sectors with large ABS SEs will show noticeably wider combined CIs.
- **Responds properly to rho**: the relationship is non-monotonic. Moderate rho (e.g. 0.7) → slopes wobble *more* → larger `slope_sd` → larger `se_combined`. Very high rho (near 1) → slopes wobble less → smaller `slope_sd`. This correctly captures the autocorrelation effect on trend estimation.
- **Stable**: uses the SD of the slope distribution (a central tendency measure) rather than extreme quantiles, so it's not dominated by outlier draws.

**Sanity check**: Northern Ireland, which has good ABS coverage and small standard errors, shows vanilla OLS and combined CIs that are nearly identical — the measurement uncertainty contribution is negligible. This is exactly what we'd expect.

#### Caveats

- **Assumes normality**: the `± 1.96 * se_combined` CI assumes the total error is roughly normal. The OLS slope is approximately normal by CLT, and the MC slope distribution should be roughly symmetric. Could be checked by plotting MC slope distributions for sectors with large ABS SEs.

- **Uses original se_ols, not per-draw SEs**: we keep only the slope from each MC draw and use the original `se_ols`. This assumes the OLS SE doesn't change much when you perturb the data — fine for small ABS SEs, and on average similar even for larger ones.

- **Slight double-counting**: each MC draw fits OLS on perturbed data, so `slope_sd` captures measurement uncertainty *plus* some interaction with regression noise. Adding `se_ols` in quadrature on top could slightly double-count the regression noise component. In practice this is small — regression noise is mostly constant across draws (same number of points, similar scatter) so it averages out and `slope_sd` is dominated by the measurement perturbation effect.

---

## Comparing slopes properly: z-test on the difference, not CI overlap

### Why CI overlap is the wrong test

The grid plots and significance counts compare growth rate slopes between regions. The original approach (inherited from `slopeDiffGrid`) checked whether the 95% CIs of two slopes physically overlapped. This is a common but flawed heuristic:

- Two 95% CIs can overlap and the difference can still be statistically significant.
- The overlap test is actually *more conservative* than a proper test — it's roughly equivalent to testing at the ~83% level, not 95%.
- This means the grids were systematically under-reporting real differences.

The reason: CI overlap asks whether each estimate's interval reaches the other's territory. But neither interval is centred on the *difference* — they're centred on their own point estimates. The proper question is whether the difference itself is distinguishable from zero.

### The z-test on the slope difference

For two slopes with their standard errors, the correct test is:

```
z = (slope_A - slope_B) / SE_diff

where SE_diff = sqrt(SE_A^2 + SE_B^2)
```

If `|z| > 1.645` the difference is significant at 90%. If `|z| > 1.960`, significant at 95%. The denominator `SE_diff` is the standard error of the *difference*, computed from the two individual SEs under independence (which holds — the slopes are estimated from different regions' data).

This is more powerful than the overlap test because `sqrt(a^2 + b^2) < a + b` — the SE of the difference is smaller than the sum of the two SEs, so the test can detect smaller differences as significant.

### How this works in the grid plots

The grid plots (`plot_focal_comparison`, `plot_focal_comparison_split`) and the significance counter (`count_sig_pairs`) all now use the z-test. For each pair of regions within a sector:

1. Compute the slope difference: `focal_slope - comparator_slope`
2. Compute the SE of the difference: `sqrt(focal_se^2 + comparator_se^2)`
3. Compute z and compare to the critical value for the chosen CI level

This is done twice — once with `se_ols` (vanilla OLS) and once with `se_combined` (OLS + measurement uncertainty in quadrature). The grid cells show:
- **Green**: focal region's slope is significantly *higher* (z > critical value)
- **Red**: focal region's slope is significantly *lower* (z < -critical value)
- **Grey**: not distinguishable (|z| < critical value)

### Visualising the z-test: the slope difference plot

Individual CI plots can be misleading — two slopes' error bars might look separated, but the z-test says "not significant" (or vice versa). The proper visualisation shows the *difference* as a single point with its own CI:

```
difference ± 1.96 * SE_diff
```

If this CI crosses zero, the slopes are not significantly different. This is implemented in the worked example section of ABS_error_rates.R, which shows both panels side by side:
- Left: the two individual slopes with their CIs (for context)
- Right: the slope difference with its CI (the actual test — does it cross zero?)

### Multiple comparisons caveat

With ~70 sectors × ~11 comparator regions ≈ 770 tests per grid, at 95% confidence you'd expect ~38 false positives even if all slopes were identical. The grids are best read for *patterns* (whole rows or columns lighting up) rather than individual cells. The 90%/95% diagonal split helps: cells significant at both levels are much less likely to be false positives.

A formal correction like Benjamini-Hochberg (BH) FDR could be applied to the z-scores. BH controls the *expected false discovery rate* — it guarantees that at most 5% of the coloured cells are false positives, rather than each individual cell having a 5% false positive rate. It works by ranking all p-values, applying progressively lenient thresholds, and keeping only those that survive. Implementation would be straightforward (`p.adjust(p_values, method = "BH")` in R).

However, the BH cutoff is itself unstable for cells near the threshold — resampling the data and re-running would shuffle p-value rankings, flipping marginal cells in and out of significance across runs. The strong results survive every time; the marginal ones are genuinely ambiguous regardless of correction method.

**Decision: leave BH for now.** The purpose of the grids is to contrast vanilla OLS with the uncertainty-augmented version — a relative comparison that is robust regardless of where the significance threshold falls, because the same multiple-comparison issue affects both panels equally. The 90%/95% diagonal split already provides a practical robustness check (cells significant at both levels are much more credible). BH would be a useful addition for any standalone claims about individual sector/region pairs, but that's not the current aim.

---

## Future work: LQ slopes with propagated measurement uncertainty

### The question

We have per-year LQ uncertainty from the MC simulation (each draw produces a full set of LQs). Can we fit `log(LQ) ~ year` slopes to examine LQ change over time, and propagate the measurement uncertainty into those slopes — analogous to what we did for GVA growth rate slopes?

### Why not smooth LQs first?

An initial idea was to take moving averages of LQ and LQ_sd, then work from those. Testing showed the differences between "average LQ directly" vs "average underlying GVA then compute LQ" can be very large — LQ is a ratio of shares, so small denominator shifts swing things substantially. Stacking smoothing on top of the MC simulation would be two layers of approximation away from the actual data. Better to work with single-year LQs where the MC uncertainty is directly tied to the underlying GVA draws.

### Proposed approach

1. **For each MC draw**, we already compute a full set of LQ values across all regions/sectors/years (inside `simulate_LQ_with_CIs`). Currently only the summary quantiles are returned; the raw per-draw LQs are discarded.

2. **Keep the raw per-draw LQs** and fit `log(LQ) ~ year` per region × sector × draw to get a slope for each draw.

3. **Summarise across draws**: take the SD of slopes (`slope_sd`) as the measurement uncertainty contribution.

4. **Combine with OLS SE via quadrature**: `se_combined = sqrt(se_ols^2 + slope_sd^2)`, exactly as for GVA slopes. This gives `lq_slopes_combined` analogous to `slopes_combined`.

5. **Plug into existing visualisations**: the focal comparison grids, forest plots, SE inflation heatmaps etc. all work on `slope + se` data, so the LQ slope version would slot straight in.

### AR(1) correlated draws

The correlation structure in LQ draws is more complex than for raw GVA because LQ is a ratio — even if you apply AR(1) to the underlying GVA draws, the resulting LQ correlation structure won't be a simple AR(1). But it will be *induced correctly* if you apply the correlated draws at the GVA level and then compute LQs from those.

So the cleanest path: apply the existing AR(1) Gaussian copula correlated draws at the GVA level (as `simulate_slopes` already does with the `rho` parameter), then compute LQs from those correlated GVA draws, then fit slopes to the LQ series. This means modifying `simulate_LQ_with_CIs` to accept `rho` and use the same correlated draw machinery.

### Implementation sketch

```r
simulate_LQ_slopes <- function(data, n_sims = 500, seed = 42, rho = 0) {
  # 1. Pre-compute log-normal params (same as existing)
  # 2. For each sim:
  #    a. Draw GVA values (with AR(1) if rho > 0)
  #    b. Compute LQs from drawn GVAs (per year)
  #    c. Fit log(LQ) ~ year per region x sector
  #    d. Store slope + se per draw
  # 3. Return raw slopes for summarisation
}

# Then:
lq_slopes_mc_summary <- lq_slopes_raw %>%
  group_by(Region_name, SIC07_description) %>%
  summarise(slope_sd = sd(slope, na.rm = TRUE))

lq_slopes_combined <- lq_slopes_ols %>%
  left_join(lq_slopes_mc_summary) %>%
  mutate(se_combined = sqrt(se_ols^2 + slope_sd^2))
```

### Status: parked

This is a natural next step but a meaningful chunk of work. The per-year LQ comparison grids (`plot_focal_LQ_split`) are already working and useful. The LQ slope version would add the time-trend dimension. Return to this when the current GVA slope analysis is fully written up.

---

## Correction: AR(1) correlation widens slope uncertainty, not narrows it

*Added March 2026. This corrects the intuition stated in several places above (now updated inline).*

### The original (wrong) intuition

The original reasoning was: "if measurement errors are positively correlated, the whole GVA series shifts up or down together, which barely changes the slope. So correlated draws should *narrow* the slope distribution compared to independent draws."

This is only true for very high rho (near 1). For moderate rho values like 0.7 — which is the plausible range for ABS measurement error correlation — the effect is the **opposite**: AR(1) correlation *widens* the slope distribution.

### Why moderate AR(1) widens slopes: the pseudo-trend effect

Think about a specific example: Yorkshire & Humber, fabricated metals, 11 years of GVA data.

**Independent errors (rho = 0):** The ABS over-estimates GVA in 2014, but in 2015 it draws a fresh sample and might under-estimate. In 2016 it over-estimates again, 2017 under, etc. The errors jump around randomly. When you fit a slope through this noisy series, the random ups and downs roughly cancel — some push the slope up, others push it down. The slope is noisy but not systematically biased in any direction.

**AR(1) errors (rho = 0.7):** Now the ABS over-estimates in 2014, and because the sample overlaps heavily, it *keeps* over-estimating in 2015, 2016, 2017... then gradually drifts back toward truth, and maybe undershoots for a few years from 2019-2022. You get a smooth hump: too high in the middle, about right at the edges (or vice versa — too low in the middle, about right at the edges, or high early and low late).

That smooth hump *looks like a real economic signal* to the regression. A run of positive errors in the first half followed by a drift to negative errors in the second half is indistinguishable from a genuine decline. The slope picks it up as if it were real.

The key intuition: **independent noise averages out across the time series, but correlated noise organises itself into smooth waves that mimic trends.** Those waves are long enough (relative to 11 years) to project strongly onto the slope direction. It's the same reason you can see "patterns" in a random walk that aren't really there — the persistence creates structure at the timescale that matters for trend estimation.

The only escape is rho very close to 1, where the error is essentially the same every year — a pure level shift. That shifts the whole series up or down uniformly, which doesn't change the slope at all. But rho = 0.7 is in the worst zone: correlated enough to create smooth drifts, but not correlated enough for those drifts to be flat.

### Analytic proof

For OLS slope estimation with AR(1) errors over T evenly-spaced years:

```
Var(slope) = sigma^2 * c' R c / (c' c)^2
```

where `c_t = (t - t_bar)` are the OLS contrast weights and `R` is the AR(1) correlation matrix with `R_{ij} = rho^|i-j|`.

Computing this for T=11:

| rho | Var(slope) / Var(slope, rho=0) |
|-----|-------------------------------|
| 0.0 | 1.00 |
| 0.3 | 1.45 |
| 0.5 | 1.98 |
| 0.7 | 2.33 |
| 0.85| ~2.4 (peak) |
| 0.9 | 1.64 |
| 0.95| ~1.0 (crossover) |
| 0.99| ~0.3 |

The relationship is non-monotonic: variance rises from rho=0, peaks around rho=0.85, then drops sharply toward 0 as rho approaches 1. The crossover point (where AR(1) slope SD equals the independent baseline) is around rho ≈ 0.95 for T=11.

This is the classic result in time series econometrics: positive autocorrelation in regression errors inflates the variance of slope estimates. OLS with independent errors gives the *minimum* slope variance; any positive autocorrelation makes it worse.

### Implications for the analysis

1. **Independent draws (rho = 0) are the conservative lower bound** on measurement-driven slope noise, not the upper bound as originally assumed. If ABS errors are actually correlated, the true measurement uncertainty is *larger* than what independent draws produce.

2. **The comparison between OLS-only and MC-augmented CIs is robust**: regardless of rho, the MC simulation adds measurement uncertainty on top of OLS. With rho > 0, it adds *more*. So the qualitative finding — "adding measurement uncertainty widens CIs and erases some significant differences" — holds and is strengthened by correlation.

3. **Rho remains a scenario parameter**: we still don't know the true ABS measurement error correlation. But now we know the direction of the effect: any plausible positive rho makes the measurement uncertainty contribution larger, not smaller.

### Code implementing this analysis

See `code/explainers.R`, Section 7 ("Slope SD vs rho — the full curve"), which computes the analytic curve and validates it against MC simulation. Also see the comparison plots added to `code/ABS_error_rates.R` after `simulate_slopes`, which run the full simulation at both rho=0 and rho=0.7 and compare slope SDs across all region × sector pairs.
