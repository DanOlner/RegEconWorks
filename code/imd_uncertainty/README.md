# IMD rank uncertainty: code

R scripts behind the report [docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd](../../docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd). The background is in [llm_output/imd_rank_uncertainty_research.md](../../llm_output/imd_rank_uncertainty_research.md), and the review that set this round of work is in [llm_output/imd_uncertainty_review_and_plan.md](../../llm_output/imd_uncertainty_review_and_plan.md).

## Running it

Everything runs from the project root.

- `Rscript code/imd_uncertainty/00_run_all.R` rebuilds everything from scratch and renders the report. It clears the cache first, so expect about 40 minutes.
- `quarto render docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd` renders the report on its own. It sources the same scripts and reuses the cache, building whatever is missing.
- Any single script can be sourced on its own; each sources `functions.R` and anything else it needs.

## Where things go

- `local/imd_raw/`: downloads, made the first time they're needed (gitignored). About 3 GB, mostly DfT's all-years road casualty files.
- `local/imd_uncertainty/cache/`: results of the slow simulations (gitignored). A cached result is reused until the script that made it, or `functions.R`, changes. `options(imd.refresh = TRUE)` forces a rerun.
- `docs/chunks/imd_uncertainty/outputs/`: CSV files of LSOA and local authority rank ranges.

For a quick test, set fewer draws first, for example `options(imd.n_draws = 100)`. The cache keeps results for different numbers of draws apart.

## Data used

All open, downloaded by the scripts:

- English Indices of Deprivation 2025, Files 6 to 10 (MHCLG).
- English Indices of Deprivation 2019, Files 6 to 8 (MHCLG), for testing the shrinkage rebuild.
- DfT road safety open data (STATS19), collisions and casualties, 2019 to 2023.
- ONS 2021 LSOA boundaries (Open Geography Portal), for placing collisions.
- Census 2021 tables TS052, TS053 and TS007A (Nomis bulk downloads).
- Business Register and Employment Survey 2023, open access, employment by LSOA (Nomis API).

Not used yet, because they need a login: the GeoDS LSOA classification (the 2025 shrinkage parent groups) and DWP Stat-Xplore.

## Packages

tidyverse, readxl, matrixStats, sf, data.table, csranks, knitr (and Quarto for the report).

## Scripts

| Script | What it does |
|---|---|
| `functions.R` | Downloads, loaders, the IoD method (transform, shrinkage and its inverse, normal scores, stage 4 builders, local authority measures), simulation helpers, caching |
| `01_rebuild_imd.R` | Reruns stages 5 to 7 from the published files and checks all five local authority measures against File 10 |
| `02_income_rank_intervals.R` | Rough first look: Income domain rank intervals |
| `03_nominal_weights.R` | Nominal share of the IMD by indicator, and what the open data allow for each |
| `04_shrinkage_rebuild.R` | Shrinkage rebuilt for Income and Employment from the published counts |
| `05_shrinkage_inversion_test.R` | Synthetic test of running shrinkage backwards |
| `06_rare_event_reliability.R` | The inversion applied to crime (and road casualties, superseded by 11) |
| `07_income_employment_mc.R` | Monte Carlo: Income and Employment error to IMD and local authority ranks, under two error models plus a sensitivity grid |
| `08_inversion_real_counts.R` | The inversion tested against the published Income, Employment, IDACI and IDAOPI counts |
| `09_iod2019_shrinkage.R` | The shrinkage rebuild on the IoD 2019, and whether counts were pooled over time before shrinkage |
| `10_stage4_rebuild.R` | Stage 4 (indicators to domains) rebuilt from File 8 |
| `11_road_casualties.R` | Road casualty indicator rebuilt from DfT open data |
| `12_census_indicators.R` | Overcrowding and adult skills from Census 2021 |
| `13_supplementary_mc.R` | IDACI and IDAOPI rank ranges |
| `14_coverage_test.R` | Whether the simulated 90% ranges contain the true rank 90% of the time |
| `15_full_mc.R` | Monte Carlo through stages 4 to 7 in three layers: Income and Employment; plus open-data chance error; plus assumed errors |
| `16_lad_confidence_sets.R` | Formal confidence sets for local authority ranks (csranks) |
