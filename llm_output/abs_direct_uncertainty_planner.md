# Uncertainty direct from the ABS: data check and wrangling plan

Claude-drafted planning doc, 19 October 2026. Follows the idea in [ABS_uncertainty_journal.md](../docs/chunks/uncertainty_from_the_ABS/ABS_uncertainty_journal.md): stop grafting ABS error rates onto region-by-industry GVA and work with the ABS figures and their standard errors directly.

This first section covers (1) what the ABS publishes at ITL1, checked against the live ONS files today, and (2) a plan for a new data-prep script that produces the same kinds of tables the old work used, but staying inside the ABS. Questions for Dan are in section 4.

**Status, 19 Oct 2026:** the data-prep script is built and run. Section 6 covers what it does, the defaults chosen for the open questions, and what the checks found.

## 1. What the ABS gives us at ITL1 (checked 19 Oct 2026)

### Files

| Dataset | File (latest) | Released | Years | Geographies |
|---|---|---|---|---|
| Regional results, Sections A to S (values) | `absregionalsectionas2024.xlsx` | 4 June 2026 | 2008 to 2024 | 12 ITL1, England, GB, UK |
| Regional results, quality measures (SE and CoV) | `absregionalqualitymeasures2024.xlsx` | 4 June 2026 | 2012 to 2024 | 12 ITL1, England, UK (no GB) |
| Regional results, revisions and change on previous year | `absregionalsrevisionschanges2024.xlsx` | 4 June 2026 | revisions to 2023; YoY change 2008 to 2024 | 12 ITL1 + national, but broad sections only (no two-digit) |
| National quality measures | `absnationalqualitymeasures.xlsx` | 26 May 2026 | 2008 to 2024 | UK only, SE and CoV down to four-digit SIC, plus response rates by section and year |

**Yes, there is an extra year.** The 2024 regional results came out on 4 June 2026. The old script points at the 2023 edition (and at `current/` for the values file, which now serves 2024).

The values file has a new **"All Regions" sheet** with all 15 geographies stacked (24,990 rows), so we no longer need to loop over per-region sheets.

### Variables at ITL1

Only four, all £m at current prices:

- Total turnover
- Approximate GVA at basic prices (aGVA)
- Total purchases of goods, materials and services
- Total employment costs

Each has a standard error and a coefficient of variation (as a ratio) from 2012 onward. Values for 2008 to 2011 have no quality measures.

What is *not* there at ITL1:

- Employment counts. ONS removed these from the publication and point to BRES instead.
- Business counts.
- Any volume or deflated measure. Everything is nominal.
- Section K (finance), and the public parts of P and Q. Section A is support activities only, as before.

So any productivity-style measure (aGVA per worker) or real growth would mean stepping outside the ABS.

### Geography and sectors

- ITL1 codes are `TLC` to `TLN`, the same as the region-by-industry data. England is `TLB`, the UK is `UK`, and GB is `GB` (values file only).
- Each geography × year has 98 rows: the 78 two-digit divisions (01 is `01 (Part)`), 17 section rows (`A (Part)`, `B`, `C`, ..., `P (Part)`, `Q (Part)`, `R`, `S`) and three aggregates (`A to S (Exc K)`, `B to E`, `H to S (Exc K)`).
- Sections D, L and P are single divisions (35, 68 and 85) and are published *only* as section rows. So the two-digit rows alone are not a complete partition of the economy: they miss energy, real estate and education. The old `abs_gva_se_combo.csv` lacks these three too. The new script copies them down as division rows, giving 81 division-level sectors.
- The aggregates are spelled differently in the two files: `A to S (Exc K)` and `B to E` in the values file, `A-S (Exc K)` and `B-E` in the quality file. These need harmonising before joining. Every two-digit and section row has a matching quality row.

### Suppression and coverage

Cell markers are `[c]` (confidential), `[low]` (less than half the rounding unit) and `[x]` (not available).

Share of two-digit × 12-region cells (936 per year) where both value and SE are numeric:

| Year | Turnover | aGVA | Purchases | Employment costs |
|---|---|---|---|---|
| 2012 | 0.88 | 0.86 | 0.86 | 0.87 |
| 2016 | 0.88 | 0.88 | 0.86 | 0.89 |
| 2020 | 0.89 | 0.82 | 0.80 | 0.88 |
| 2023 | 0.87 | 0.82 | 0.81 | 0.86 |
| 2024 | 0.88 | 0.81 | 0.82 | 0.87 |

aGVA suppression has crept up over time. Section-level rows are much more complete: the whole-economy total and `B to E`, `F`, `G`, `I`, `J`, `L`, `N`, `Q` are 100% present with SEs, and the weakest are `D` (about 81%) and `E` (about 85%).

Two other things matter for later steps:

- **127 two-digit aGVA cells are negative** (2012 to 2024). The log-normal draws and `log(value)` slopes in the old code can't use them. The old code silently held them fixed or dropped them.
- **Typical CoVs, median across all cells:** turnover 8.6%, aGVA 10.0%, purchases 10.6%, employment costs 7.2%. For aGVA in 2024 the interquartile range is 6.5% to 18.4%, with the 95th percentile at 41%.

### Revisions between editions

Comparing the 2024 edition against `data/abs_gva_se_combo.csv` (2023 edition):

- 2012 to 2022 are identical in both values and SEs.
- **2023 was revised:** 93% of two-digit aGVA cells changed, with a median absolute revision of 1.7% and a 90th percentile of 11%. SEs also changed (median 3.8%).
- Suppression status flipped for about 50 cells.

This is ONS's planned revision. Technical report section 6.1 says it comes from late-responding businesses and corrections by respondents, and that each year's figures are revised once, in the following year's release. It is not a methods change:

- Earlier years don't move. 2012 to 2021 are identical between the 2022, 2023 and 2024 editions.
- 2022's revision (2022 edition → 2023 edition) was the same size: region × two-digit median 1.9%, 90th percentile 11.5%.
- UK-level two-digit revisions are nearly as big (2023: median 1.5%, 90th percentile 6.5%; motor vehicles, division 29, fell 32%). But regional cells also shift within their division: the UK division revision explains only 6% of regional revision variance for 2023 and 27% for 2022. That fits late returns from multi-site businesses being split across their own sites. ONS doesn't say whether the apportionment model is re-run.
- Compared with the 2023-edition SEs, 84% of region × two-digit aGVA revisions are within 1 SE and 93% within 2 SE (median 0.18 SE). Revisions are a separate error source that the published SEs don't include.

2023 also had a separate, unplanned correction. The original 2023 release (8 May 2025, `previous/v13`) contained "a processing error ... a methods problem in the system used to collect and process the business survey data" (ONS notices of 25 June and 18 September 2025). It was corrected on 18 September 2025 (`previous/v14`). The fix raised UK whole-economy aGVA by 0.72% (all four variables moved; employment costs +1.1%), touched 2023 only, and shifted region × two-digit cells by a median of 1.4% (90th percentile 7.9%). `data/abs_gva_se_combo.csv` matches v14 exactly, so the old chunk used corrected data.

Implications for the script: use v14, not v13, for any 2023-edition comparison; add a `provisional` flag for the latest year in each edition (2024 now); and consider widening uncertainty for the provisional year using the empirical revision distribution.

So each year's first published figure gets revised once, a year later. ONS keeps earlier editions on the dataset's "previous versions" page: v8 to v14 are `.xlsx` (2020 to 2023 editions) and v1 to v7 are older `.xls` files. That means a first-estimate-versus-revised history at two-digit level is buildable.

### Checks that shape the plan

1. **The regions sum to the UK.** At the `A to S (Exc K)` level, the 12 regions sum to the published UK figure within 0.0002% in every year, 2008 to 2024. Within-ABS shares and LQs therefore have a coherent denominator. We should use the published totals rather than summing visible cells, which undercount wherever cells are suppressed.
   - This is additive by construction, not balancing. The regions are domains of one national sample, with reporting-unit returns apportioned to local units, and the "UK" row in the regional file is the sum over all local units. Technical report section 5.8 says the regional estimates are designed to add up to the national all-industry total, which follows from apportionment preserving each business's own total. In the published files they don't quite: whole-economy aGVA differs from the national release by -0.4% to +0.6% in every year from 2008 to 2024, and by 0.9% within the same (original) 2023 vintage. This isn't explained anywhere I found; worth asking ABAPS@ons.gov.uk. At industry level the two differ by design, because national figures use reporting-unit classification and regional figures use local-unit classification. At two-digit level, the regions sum to the regional UK row within £4m (rounding) in all 651 cases where no region is suppressed.
   - So use the regional file's own UK row as the national denominator, not the national ABS publication.
2. **Sampling errors are effectively independent across divisions.** The published section SE divided by `sqrt(sum of division SE^2)` has a median of 1.004, with a 5th to 95th percentile range of 0.95 to 1.06 (n = 1,799 section × region × year cells with no suppressed divisions). This means:
   - SEs for any custom sector grouping can be built as `sqrt(sum(SE^2))`. That's a proper replacement for the old GVA-weighted mean of CoVs.
   - The independent draws across sectors in the Monte Carlo LQ code are justified.
3. **Regions are mildly negatively correlated within a division.** The UK SE divided by `sqrt(sum of 12 regional SE^2)` has a median of 0.935 (5th to 95th percentile 0.75 to 1.61). Treating regions as independent is slightly conservative for sums across regions. That's fine for now, but worth a sentence in the write-up.
4. **The accounting identity nearly holds.** `turnover - purchases - aGVA` has a median of -0.5% of turnover (5th to 95th percentile -5.6% to +2.4%). If we treat aGVA ≈ turnover − purchases, the implied correlation between turnover and purchases errors has a median of 0.89, and only 2.3% of cells give an impossible |ρ| > 1. So we can back out approximate covariances and put SEs on ratios such as aGVA/turnover. Employment costs aren't in the identity, so the labour share needs an assumed correlation.
   - The identity is only approximate by design. The technical report's formula (section 8.1, "Calculation of approximate GVA in the ABS") is turnover + movement in stocks + own-staff capital work + insurance claims received + other subsidies received + business rates + Vehicle Excise Duty − purchases − Work Programme receipts − total net taxes (total taxes for service industries). aGVA is at basic prices, so product duties come off. That deduction is large in a few divisions: pooled UK 2012 to 2024, (turnover − purchases − aGVA) is 62% of turnover for tobacco (12), 23% for refined petroleum (19), 13% for beverages (11), 5% for gambling (92) and 3% for wholesale (46). Those divisions must be excluded from the covariance trick.
5. **The published CoV is SE/value, at varying precision.** In the 2024 edition, 2022 to 2024 are full precision (99.5% match SE/|value| exactly) and 2012 to 2021 are rounded to 2dp (97% match within rounding). The remaining mismatches are tiny or negative cells: ONS computes CoV from unrounded values and keeps the sign. Computing CoV ourselves from the SE loses nothing, but for cells of a few £m any CoV is noise.
6. **The old hard-coded cell ranges would silently drop 2024.** `A7:I1575` covers 16 years × 98 rows and `A7:M16471` covers 12 years. The new script should read to the end of each sheet.

## 2. Shapes the old work used

From [code/ABS_error_rates.R](../code/ABS_error_rates.R):

- `data/abs_gva_se_combo.csv`: `SIC, Description, Country_Code, Country_and_Region, Year, GVA, GVA_SE, gva_min95, gva_max95, CoV100`. Two-digit, aGVA only, 2012 to 2023.
- `data/itl1_cp_withestimatederrorratefromABS.csv` and `_cv_`: `ITL_code, Region_name, SIC07_code, SIC07_description, year, value, CoV100, SE, gva_min95, gva_max95`. This is the shape every downstream function expects (`simulate_LQ_with_CIs`, `simulate_slopes`, `plot_sector_gva_with_errors`, the pairwise heatmaps and the focal LQ and slope plots). The values were region-by-industry GVA using region-by-industry sector groupings, with ABS CoVs grafted on.

The new script should produce a table in that second shape, but with ABS values and ABS SEs, so the existing functions run on it unchanged.

## 3. Plan for the new script

Proposed name: `code/ABS_direct_dataprep.R`. It would do data prep only, with no plots. Analysis and plotting would go in separate scripts that read its outputs, so this doesn't turn into another 3,700-line file.

### Step 0: setup and caching downloads

- Put the URLs in a named list at the top. Use the dated edition paths where ONS provides them (for example `/2024/absregionalqualitymeasures2024.xlsx`). The values file only has `current/` plus `previous/vN`, so record its edition from the cover sheet.
- Download into `local/abs_raw/`, which is gitignored, and skip files that are already there. ONS's Cloudflare rate-limited me (error 1015) after a handful of requests today, so re-downloading on every run will be fragile.
- Read the release date from each Cover Sheet and carry it as an `edition` column.

### Step 1: read the values

- Read the "All Regions" sheet only, with `skip = 6` and `col_types = "text"`, to the end of the sheet.
- Rename the columns to `SIC_raw, SIC_description, ITL_code, Region_name, year, turnover, aGVA, purchases, employment_costs`.
- Pivot long to one row per SIC × geography × year × variable, with numeric `value` plus `value_flag` (`[c]`, `[low]`, `[x]` or NA). Keeping the flags lets us show the suppression itself.

### Step 2: read the quality measures

- Read the "Section Division by Region" sheet, columns 1 to 13 (14 and 15 are empty), with `skip = 6`, to the end.
- Pivot long to `SE` and `SE_flag` per variable. Drop the published CoV, since it's recomputed exactly in step 4.
- Harmonise the aggregate labels to the values-file spelling.

### Step 3: harmonise sector codes

- Add a `level` column: `total`, `aggregate`, `section` or `division`.
- Add `SIC_code`: the two-digit string for divisions (`"01"` from `01 (Part)`) and the letter for sections.
- Give every division its parent `section` letter. There's a working division-to-section mapping in this session's check scripts.
- Add a `partial_coverage` flag for A, 01, P and Q.
- Optionally, a small `data/abs_siclookup.csv` with short names for plot labels, like `regxind_siclookup.csv`. The ABS descriptions differ from the region-by-industry ones, so that file can't be reused directly.

### Step 4: join and derive

- Join values to quality on `SIC_raw × ITL_code × year × variable`.
- Derive:
  - `CoV100 = 100 * SE / abs(value)`
  - `min95` and `max95` as `value ± 1.96 * SE`
  - `has_se` (SE present and > 0)
  - `positive` (value > 0), needed for log-normal draws and log slopes.
- Keep values back to 2008 (with `has_se = FALSE`) but default all analysis to 2012 to 2024. As well as the SEs starting in 2012, the ABS notes say purchases (and so aGVA) changed apportionment method between 2011 and 2012, which leaves a small discontinuity.

### Step 5: a "suppressed remainder" pseudo-sector

(Called "remainder" in the built code, to avoid confusion with regression residuals. Decided 19 Oct 2026, after testing the alternative below.)

**What it does, in plain English**

- ONS hides ("suppresses", shown as `[c]`) some region × sector figures, so nobody can work out an individual business's numbers. For aGVA, 12.9% of two-digit cells in the 12 regions are hidden (2012 to 2024).
- The hidden amounts still count in the totals ONS *does* publish. For example, manufacturing in the North East (section C) and the North East's whole-economy total both include them.
- So for each section, the combined size of its hidden cells is: published section total minus the visible two-digit cells in it. That's the **suppressed remainder**. We know what the hidden cells add up to, but not how that splits between them.
- Each remainder becomes one extra row, labelled e.g. "Suppressed remainder: section C", for that region, year and variable. Sometimes the section total is itself hidden (some of B, D and E). Then the leftover goes into a single whole-economy remainder row for that region-year instead.
- **Why bother?** Anything that adds sectors up is otherwise too small by the hidden amount: regional totals, national totals, shares, and LQ denominators. With remainder rows, sums match the published totals to within £7m (rounding). `add_location_quotient_and_proportions` builds its totals by summing whatever rows it's given, so it needs this.
- **Its uncertainty.** Sampling errors are independent across sectors (check 2), so variances add: `SE_remainder^2 = SE_section^2 - sum of visible SE^2`. When that comes out at or below zero (independence only holds approximately), the SE is set to NA, meaning it can't be derived, rather than zero, which would claim the remainder is known exactly. 531 of the 2,497 remainder rows from 2012 on have no SE; the simulation functions hold those fixed.
- **What it is not.** It isn't an estimate of any individual hidden cell. Remainder rows are there to make totals right. They shouldn't be plotted, ranked or given LQs as if they were real sectors: filter on `is_remainder` (legacy file) or `level == "remainder"` (long table).

**The alternative tested first: estimating hidden cells from neighbouring years**

The idea was to estimate a hidden cell from the same region × sector in the years either side, where it is published. Tested on aGVA, 12 regions × two-digit, 2012 to 2024, using `data/abs_itl1_long.csv`. The script is [code/ABS_direct_suppression_test.R](../code/ABS_direct_suppression_test.R) (sections 1 to 4); it prints results and writes nothing.

- **Suppression is persistent, so there often isn't a neighbouring year to use.** Of 1,634 hidden cells, only 45% have the same cell published in an adjacent year, and only 14% on both sides. 18% are never published in any year. Half sit in series hidden in at least 10 of the 17 years. Even allowing neighbours up to 3 years away, 41% of hidden cells have nothing to work from.
- **Where neighbours exist, the estimates are rough.** We can test this on published cells, where the true answer is known: estimate each from the years either side and compare. Interpolating the cell's share of its section misses by a median 9.5% (90th percentile 37%), and only half the estimates land within 1 SE of the truth. For series that are sometimes hidden (more like the real hidden cells), the median miss is 14%. So this adds roughly as much error again as the sampling error.
- **On the real hidden cells it's worse.** The neighbouring-year estimates for a section's hidden cells should add up to the known remainder. Only 46% come within ±20% of it (10th to 90th percentile of the ratio: 0.45 to 1.54).
- **A hybrid does best, but only covers some cases.** We hid the two smallest sectors in fully published sections and rebuilt them three ways:

  | Method | Median error | Within 1 SE |
  |---|---|---|
  | Neighbouring years alone | 14% | 49% |
  | Known remainder, split in proportion to neighbouring-year shares | 10% | 61% |
  | Known remainder, split equally | 30% | 25% |

  The remainder fixes the total and the neighbouring years give the split. But it only works where every hidden cell in a section-year has a neighbour within 3 years: 45% of section-years.

**Decision:** use remainder rows as the default, and don't attempt cell-level estimates. The hybrid split is a possible later option, as extra flagged columns, for analyses that need individual hidden sectors.

### Step 6: revisions layer

- Download the 2023 edition (`previous/v14`) of the values file, and the 2023 quality file, which is already linked.
- For year 2023: `revision = 2024 edition - 2023 edition` for all four variables, plus `revision / SE` as a rough score. This answers "how big are revisions compared to the sampling error?", which isn't something the old chunk could look at.
- Possible extension: loop back over v8 to v13 (`.xlsx`) for a first-versus-revised history from about 2019. The v1 to v7 `.xls` files have older layouts and would be more work. See question 4.

### Step 7: outputs

| File | Contents | Notes |
|---|---|---|
| `data/abs_itl1_long.csv` | Master long table: `edition, ITL_code, Region_name, level, section, SIC_code, SIC_description, partial_coverage, year, variable, value, value_flag, SE, SE_flag, CoV100, min95, max95, has_se, positive` | Roughly 66k rows for 12 ITL1 + UK, 2012 to 2024, all levels and four variables. Large but smaller than the 40MB `slopes_mc_raw_draws.csv` already committed. |
| `data/abs_itl1_aGVA_legacyshape.csv` | Divisions (plus residuals if switched on), aGVA, 12 regions, 2012 to 2024, in exactly the old columns: `ITL_code, Region_name, SIC07_code, SIC07_description, year, value, CoV100, SE, gva_min95, gva_max95` | Drop-in input for the existing simulation and plot functions. |
| `data/abs_itl1_ratios.csv` | Ratios with approximate SEs (step 8) | Optional, see question 5. |
| `data/abs_itl1_revisions.csv` | Step 6 output | |

Alongside these, a helper `abs_legacy_shape(df, variable = "aGVA", level = "division")` would push turnover, purchases or employment costs through the same functions. One wart: the bounds columns would still be called `gva_min95` and `gva_max95` for compatibility. A later tidy-up could rename them in the functions.

The old files (`abs_gva_se_combo.csv` and the `itl1_*` files) stay untouched, because the existing chunk depends on them.

### Step 8: ratios with SEs

- **aGVA/turnover and purchases/turnover.** Use the delta method, with covariances implied by the identity:
  - `Cov(T,P) = (SE_T^2 + SE_P^2 - SE_G^2) / 2`
  - `Cov(G,T) = SE_T^2 - Cov(T,P)`
  - `Var(G/T) ≈ (G/T)^2 * (SE_G^2/G^2 + SE_T^2/T^2 - 2*Cov(G,T)/(G*T))`
  - Clip the implied ρ to [-1, 1] and flag the cells where clipping was needed.
  - Exclude the duty-heavy divisions (11, 12, 19, 92, and check 46), where aGVA is far from turnover − purchases.
- **Employment costs/aGVA** (a labour-share proxy) and **aGVA − employment costs**. There's no identity to lean on here, so show sensitivity to an assumed correlation (ρ = 0, 0.5, 0.9) or bound it. Interpretation caveats:
  - aGVA − employment costs is gross operating surplus (before depreciation, interest, dividends and corporation tax). It also contains business rates, VED and subsidies received, since aGVA keeps all three.
  - Employment costs exclude payments to working proprietors, so the owners' earnings in sole traders and partnerships sit in the "profit" residual. Self-employment-heavy sectors will look less labour-intensive than they are.
  - It can go negative. In libraries and museums (91), employment costs are 433% of aGVA, pooled 2012 to 2024.

### Step 9: checks built into the script

These would be `stopifnot` calls or printed diagnostics:

- 98 SIC rows per geography × year in the values data.
- The regions sum to the UK at `A to S (Exc K)` within 0.01%.
- Every 2012+ value row has a quality row (GB excepted).
- The recomputed CoV matches the published CoV.
- 2012 to 2022 aGVA and SE match `data/abs_gva_se_combo.csv` exactly. This passed today, and a failure would mean ONS has revised further back.
- The division-to-section quadrature ratio, printed as a diagnostic so a future edition that breaks the independence assumption gets noticed.

## 4. Questions and decisions

Decisions from Dan, 19 Oct 2026, except question 2, which is still open.

1. **Nominal or real?** The ABS is current prices only; the old growth slopes and pairwise year heatmaps used chained-volume region-by-industry values.

   **Decided: nominal.** Stick to what the survey actually measures. How hard "real" is gets picked apart later, as its own topic. Growth results need labelling as nominal growth.
2. **Main sector unit (open).** The question is which "building block" sector to use for comparisons (LQs, growth, telling regions apart). It's a trade-off between detail and certainty. Here's what each option means for aGVA, 12 regions, 2012 to 2024 (figures from section 5 of [code/ABS_direct_suppression_test.R](../code/ABS_direct_suppression_test.R)):

   | Level | Sectors | Hidden ([c]) | Median CoV | Year-on-year changes distinguishable from noise (95%) |
   |---|---|---|---|---|
   | Two-digit divisions | 81 (78 + D, L, P) | 12.9% | 9.9% | 23% |
   | Sections | 17 | 3.5% | 5.7% | 28% |
   | Whole economy | 1 | 0% | 1.5% | n/a |

   - **Two-digit divisions** give the most detail, and each has its own survey SE. But one cell in eight is hidden, so time series have gaps and some sectors (energy, mining, tobacco, refining) are mostly missing in some regions. Cells are small, so a quarter have CoVs above 17%. Most year-on-year movements in a region × sector can't be told apart from sampling noise.
   - **Sections** are far more complete and about twice as precise. But they hide a lot. Manufacturing (C) lumps 24 divisions together, from food to aerospace, so a region's distinctive manufacturing strengths disappear into an average. Precision doesn't buy as much as it sounds, either: even at section level, only 28% of year-on-year changes are distinguishable.
   - **Custom groupings** sit in between: groups of divisions chosen to fit a question, like the region-by-industry bins or a "cluster". SEs can be built properly by adding variances (check 2). But the grouping is itself a choice that needs justifying. And a group containing a hidden cell needs the remainder treatment or is incomplete.
   - **Practical implication.** This needn't be either/or. The long table holds every level, so an analysis can lead with sections for headline comparisons and drill down to divisions with the uncertainty shown. The legacy-shape file (and so the old simulation functions) currently uses divisions; switching it to sections is a small change to `abs_legacy_shape()`.
3. **Suppressed cells (step 5).** Tested estimating hidden cells from neighbouring years first. It doesn't work well enough: there's often no neighbouring year, and where there is, the estimates are rough.

   **Decided: remainder rows**, explained in plain English in step 5.
4. **Revisions.** **Decided: as built.** That's the planned revisions to 2022 and 2023 plus the 2023 error correction.
5. **Ratios (step 8).** **Decided: later.**
6. **England and UK rows.** **Decided: keep both** in the long table. The legacy-shape file stays ITL1 only.

## 5. Later, from the journal (not this script)

- **ITL2/ITL3 extrapolation.** Scaling SEs down a geography level needs:
  - business or local-unit counts by ITL2 × SIC × size band (UK Business Counts on Nomis is the IDBR-based source);
  - the ABS sample design (stratification and any census strata), from the ABS technical report.

  The national quality file's response rates by section and year are a useful input too: about 75 to 80% before COVID, 53% in 2019, 69.9% in 2024.
- **A caveat to carry through.** Regional ABS figures come from apportioning reporting-unit returns to local units with an employment-based model (see [abs_v_regbyindustry.md](abs_v_regbyindustry.md), section 5). The published SEs cover sampling error, not that apportionment model. The gap will matter more at ITL2 and ITL3.

## 6. Build status (19 Oct 2026)

### Files

- [code/ABS_direct_functions.R](../code/ABS_direct_functions.R): readers (work on the 2022, 2023 and 2024 editions), SIC harmonising, the D/L/P copy-down, suppressed remainders, derived columns, the legacy-shape helper and edition comparison.
- [code/ABS_direct_dataprep.R](../code/ABS_direct_dataprep.R): downloads (cached in `local/abs_raw/`, gitignored), joins, checks, outputs. Runs in about 20 seconds once the files are cached.
- [code/ABS_direct_suppression_test.R](../code/ABS_direct_suppression_test.R): the neighbouring-years test behind step 5, and the sector-level trade-off figures in question 2. Reads `data/abs_itl1_long.csv` and prints results only.
- Outputs:
  - `data/abs_itl1_long.csv` (17 MB): all four variables, 12 ITL1 + England + UK, 2008 to 2024, all SIC levels plus remainder rows.
  - `data/abs_itl1_aGVA_legacyshape.csv` (1.5 MB): 91 sectors (78 two-digit, the D/L/P copies and 10 remainder types), 12 regions, 2012 to 2024. It has the old columns plus `is_remainder` and `provisional`.
  - `data/abs_itl1_revisions.csv` (3 MB).

### How the section 4 decisions show up in the code

1. Nominal: nothing is deflated.
2. Sector unit (still open): the legacy-shape file uses two-digit divisions; every level is in the long table.
3. Remainder rows are on (`include_remainders <- TRUE`). Suppressed two-digit cells are dropped from the legacy-shape file, so its sums match the published totals.
4. Revisions: the planned revisions for 2022 and 2023 and the 2023 error correction. Going further back means adding editions to the `abs_files` table, though older `.xls` layouts may need reader changes.
5. Ratios (step 8) are not built.
6. England and UK are kept in the long table. ABS region names are kept ("East of England", not "East").

### What the checks found

- Every check passes:
  - 98 rows per geography × year.
  - Every 2012+ value row has a quality row.
  - The regions sum to the UK within 0.0002%.
  - Divisions plus remainders add up to the published whole-economy totals within £7m (rounding).
  - The section-vs-quadrature ratio has a median of 1.004.
  - 2012 to 2022 match `abs_gva_se_combo.csv` 100% for both values and SEs.
  - There are no back revisions to earlier years.
- **Remainder SEs.** 531 of the 2,497 remainder rows from 2012 on have no derivable SE (set to NA, so simulations hold them fixed):
  - 381 are section remainders where the visible two-digit variances already exceed the section variance. The median overshoot is 4%, consistent with independence only holding approximately, and these remainders are small (a median 3.2% of the section).
  - 94 are section remainders where a visible cell has a suppressed SE.
  - 56 are whole-economy remainders.
  
  Where an SE is derivable, remainder CoVs are higher than for ordinary two-digit cells (median 14% vs 9%). A possible fallback for the NA cases is to borrow the section's CoV.
- **Smoke test.** `simulate_LQ_with_CIs` and `simulate_slopes`, extracted unchanged from `ABS_error_rates.R`, run on the legacy-shape file. For example, 2024 fabricated metal LQs run from West Midlands 2.36 (95% interval 2.21 to 2.54) to London 0.10. The pre-existing `rlnorm` NA warnings are harmless: `ifelse` evaluates draws for rows without SEs and then discards them. The only missing outputs are:
  - five tobacco LQs, where every visible regional value is 0;
  - 15 slope series with fewer than three positive years.
