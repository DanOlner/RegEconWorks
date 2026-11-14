# IMD uncertainty work log

A dated record of the work on IMD rank uncertainty: what was done, the decisions and why, the dead ends and bugs, and what is still open. Written by Claude Code; Dan's own notes would go in a separate journal, as with the ABS chunk.

The plan and its status table are in [llm_output/imd_uncertainty_review_and_plan.md](../../../llm_output/imd_uncertainty_review_and_plan.md). The findings are in the report, [imd_uncertainty_firstlook.qmd](imd_uncertainty_firstlook.qmd). What each script does is in [code/imd_uncertainty/README.md](../../../code/imd_uncertainty/README.md).

## 10 November 2026

All of the work so far happened in one Claude Code session.

- **Conversation:** [llm_convos/2026-11-10_0213_Start_a_research_md_for_a.md](../../../llm_convos/2026-11-10_0213_Start_a_research_md_for_a.md), exported with `scripts/export_all_convos.py`. The scan rated it clean, but it stays unpublished until it is uncommented in `llm_convos/.gitignore`, so the link only works locally until then.
- **Models:** Claude Opus 5.5 for the research note, the first report and the second round. Claude Fable 5.2 for the review in between.
- **Commits:**
  - "IMD uncertainty draft 1" (e967d76): the research note, the first report and scripts `01` to `07`.
  - "IMD uncertainty draft 2" (db0de2b): the review, round 2 and this log, before its conversation link was added.

### What was asked, in order

1. Start a research note on the datasets behind the IMD, how they are weighted into domains and sub-domains, and how the domains make the IMD, with questions for Dan.
2. Put the R code in a new `code/imd_uncertainty/` folder.
3. Write a Quarto report covering what secure and non-open data mean for IMD uncertainty, and whether the error can be reverse engineered from LSOAs being pulled towards their local authorities.
4. Review that report and write a plan (Fable 5.2).
5. Do as much of the plan as possible without GeoDS or Stat-Xplore logins, keeping all code in the project so the pipeline to the report is reproducible.
6. Write this log, after exporting the conversation.

### What was produced

- [llm_output/imd_rank_uncertainty_research.md](../../../llm_output/imd_rank_uncertainty_research.md): all 55 indicators, weights, construction, error sources, related work, options, 12 questions.
- [code/imd_uncertainty/](../../../code/imd_uncertainty/): `functions.R`, scripts `01` to `16`, `00_run_all.R` and a README.
- [imd_uncertainty_firstlook.qmd](imd_uncertainty_firstlook.qmd) and its HTML: first version (round 1), rewritten in round 2.
- [llm_output/imd_uncertainty_review_and_plan.md](../../../llm_output/imd_uncertainty_review_and_plan.md): review of round 1, plan, and a progress table for round 2.
- [llm_output/imd_uncertainty_questions_for_iod_team.md](../../../llm_output/imd_uncertainty_questions_for_iod_team.md): draft questions for MHCLG and the research team. Not sent.
- [outputs/](outputs/): CSV files of LSOA and local authority rank ranges, about 22 MB in all.

### Round 1: research note and first report (Opus 5.5)

- Downloaded IoD 2025 Files 6 to 10 and checked that stages 5 to 7 rebuild from them: the exponential transform, the weights (which add to 0.999, as published) and three of the local authority measures.
  - File 10 counts average rank the other way round (N + 1 minus rank).
  - File 10 rounds the proportion in the most deprived 10% to 4 decimal places. Both of these first looked like mismatches.
- Rebuilt the Income and Employment shrinkage from the published counts, wrote `invert_shrinkage()` to run it backwards, tested it on made-up data, applied it to crime and road casualties, and ran a first Monte Carlo of Income and Employment error (500 draws).
- **Decision:** the local authority as shrinkage parent, because the 2025 parent groups (GeoDS LSOA classification supergroups within local authorities) need a login. WebFetch got a 403 and the CKAN resource URLs are hidden.
- **Fixed:** groups with one LSOA gave t² = 0/0, so they now keep w = 1, as the technical report says single-LSOA groups aren't shrunk.

### Review (Fable 5.2)

The review found that no result was reversed, but that:

- the lower bound was too low (independent errors, binomial variance);
- three statements in the report weren't supported;
- "open data" had been read as "what File 8 publishes";
- stage 4 hadn't been rebuilt.

It wrote the plan in phases A to E. Its checks were scratch runs, so each became a task to redo in the repo.

### Round 2: working through the plan (Opus 5.5)

**Findings that changed the picture.**

- **Stage 4 rebuilds** (`10`).
  - The normal score is Φ⁻¹(rank / (N + 1)) with ties averaged. Found by testing three formulas against the Health domain; the other two miss by up to 0.08.
  - Wider barriers is the sum of five normal scores, with each composite item re-standardised first. Found by regression: every coefficient is 1 and there's no intercept.
- **Road casualties look unshrunk** (`11`). Rebuilt from DfT STATS19, the unshrunk rate matches the published indicator (rank correlation 0.982). 1,274 of the 1,278 LSOAs published at exactly 0 had no casualties, and shrinkage would lift them off zero. This contradicts paragraph 4.9.30 and is question 5 for the research team.
- **The inversion works on real data** (`08`). It recovers the published Income, Employment, IDACI and IDAOPI counts to within rounding for 84% to 90% of LSOAs, with standard errors within a few percent.
- **The IoD 2019 test** (`09`).
  - It supports the supergroup explanation for Income: the 2019 pull correlation is 0.85 against a benchmark of 0.81.
  - It doesn't fit 2019 Employment (0.34 against 0.83). That's unexplained and is question 6.
  - The pooled-or-average test is mixed: in 2019 the pull is the right size only if pooled; in 2025 its shape favours the average.
- **Two error models** (`07`).
  - The Indices' own model gives a median LSOA range of 1,306 ranks.
  - Correlated errors with design effect 2 give 2,237.
  - The coverage test (`14`) shows the ranges hold at 89.5% when the model is right, and fall to 65.8% when the real error is the correlated kind and the analysis assumes the own model.
- **Layers** (`15`).
  - The median LSOA range goes from 1,306 to 1,609 with open-data error in the other domains, and to 2,885 with assumed errors.
  - Local authority ranges move only when shared errors are added: 3 to 16 ranks on average score.

**Decisions and why.**

- **Correlation model:** sqrt(employment count ÷ income count) in each LSOA, median 0.62. It's what the correlation would be if every employment-deprived person were also in the Income count and people came and went independently. It's an assumption until Stat-Xplore can measure it.
- **Design effect 2:** the Income count changes a benefit unit at a time. A round number, also waiting for Stat-Xplore.
- **Crime reading:** the annual average count is the main case. The report's wording (4.7.10 to 4.7.13) and the 2025 Employment test point that way, and pooled counts are run as a variant (layer 2b).
- **Road casualty denominator:** residents plus BRES 2023 employment, standing in for the non-resident workplace population. This overstates it a little, because BRES also counts residents who work locally.
- **Road casualty error:** plain weighted-Poisson error, with no shrinkage, because the indicator behaves as if unshrunk.
- **Burglary:** Census households stand in for at-risk properties.
- **Assumed errors in layer 3:** order-of-magnitude guesses, listed in a table in the report and in `assumed_errors` in `15_full_mc.R`. They are meant to show which kinds of error matter, not to estimate them.
- **Delta method in `15`:** each draw adds the change in the rebuilt score to the published score, so rounding in File 8 doesn't move the starting point.
- **Centring on the published ranking:** tied published values are spread across their rounding interval in published-rank order, so that a run with no noise gives back the published ranks.
- **Caching:** results are keyed on the md5 of the script and of `functions.R`, so editing either reruns the result. The slow road casualty allocation ignores `functions.R`.

**Dead ends and workarounds.**

- **DfT per-year files** exist only from 2021. The 2019 and 2020 data come from the all-years files (about 2.5 GB with the other downloads; gitignored).
- **BRES at 2021 LSOAs** is empty for 2022 on Nomis ("These figures are missing"), so 2023 is used.
- **The 100 m boundary split.** `st_is_within_distance()` took 40 seconds per 500 points, which would have meant hours for all collisions. Intersecting 100 m buffers is about 25 times faster and agreed for 99.6% of a test sample.
- **Police.uk crime rebuild:** not attempted. The archive is large and its categories don't match the IoD's.

**Bugs, and what caught them.** The zero-noise checks (no noise must give back the published ranks) caught three of these, so keep those checks when extending the code.

- **`untie_by_rank()` clamped every value to 0 to 1.** That's right for rates but scrambled negative domain scores. Bounds are now an argument, set only for rates. Caught by the zero-noise check in `15`.
- **Floating-point error.** `(published + rebuilt) - zero` isn't exactly the published value, and the tiny difference broke ties in the rounded affordability values, reordering thousands of normal scores. The change is now computed first, in brackets. Caught by the same check.
- **Tiny untied rates were clamped.** A 1e-5 floor tied them again; it's now 1e-9. Caught by the zero-noise check in `13`. The remaining "mismatches" there were ranks that File 7 itself gives to two LSOAs (36 for IDACI).
- **`library(matrixStats)` masked `dplyr::count`.** It's now called as `matrixStats::`.
- **`tibble()` reads a just-created column ahead of an outer variable of the same name.** This hit `measure` and `indicator` several times. Fixed with local copies.
- **One-draw arrays dropped a dimension.** Fixed by wrapping in `matrix()`.
- **`cached()` evaluated scripts in the global environment.** It now uses a fresh environment.
- **`10` reused the name `rebuilt`**, overwriting `04`'s table during the render. Renamed to `stage4_rebuilt`.

**Text corrected in the report** (from the review):

- the "safe side" claim, now true only for too-small denominators and too-coarse groups;
- the cause of under-coverage at small counts, which is mostly there before shrinkage, and a small-count interval doesn't fix it;
- the supergroup explanation, now supported for Income only;
- "every published rank", where one pair is swapped;
- the data-access groups, regrouped so that indicators open at source count as having counts.

**Set up on the machine.**

- Installed the R packages `csranks` and `matrixStats` from CRAN.
- Added a memory note: keep all analysis code in the repo, with a full rebuild path.

### Still open

- **Logins needed:**
  - GeoDS LSOA classification, to rerun shrinkage with the 2025 parent groups;
  - DWP Stat-Xplore, to measure the correlation and design effect.
- **Questions for the research team:**
  - Was road casualties shrunk?
  - How was the 2019 Employment domain shrunk?
  - Were counts pooled over time or averaged?
  - Can posterior standard errors, the parent groups and the at-risk denominators be published?
- **Not checked:** that the 2019 Employment numerator is an average of quarterly counts. That's from memory of the 2019 technical report and is flagged in the report.
- **Not done:**
  - the crime rebuild from police.uk;
  - expected counts for the health ratios;
  - ONS population intervals in place of the assumed denominator error;
  - the method layer (weights, exponential constant, 70/30 split).
- **Before committing:** the CSV outputs are about 22 MB and the HTML 7 MB. Decide what belongs in the repo.
