# Tradeable jobs: code

Code for the tradeable jobs chunk.

- **The plan** (model equations, claims, steps): [tradeable_jobs_plan.md](../../docs/chunks/tradeable_jobs/tradeable_jobs_plan.md).
- **The results:** [tradeable_jobs_firstlook.qmd](../../docs/chunks/tradeable_jobs/tradeable_jobs_firstlook.qmd).

## How to run

Run everything from the repo root.

```sh
Rscript code/tradeable_jobs/00_run_all.R                # everything, from scratch, then render the report
python3 -I code/tradeable_jobs/get_papers.py           # optional: the papers themselves, as readable markdown
```

**Time.** A full rebuild takes about 15 minutes. Rendering on its own reuses the cache.

**Requirements.**

- R packages: dplyr, tidyr, readr, readxl, ggplot2, jsonlite, plus tidyverse, knitr and ggrepel for the report. The solvers are base R.
- `get_papers.py` needs `curl`, `pdftotext` and `pdftoppm` (poppler).

## What goes where

- **Downloads:** `local/tradeable_jobs/data_raw/` (gitignored). These are BRES from Nomis (NM_189_1, NUTS 2016 level 3, SIC 3-digit, 2015–2019), ASHE tables 22.5a (ad hoc 12453) and 16.5a, the 2019 input-output analytical tables, and the GDP deflator (YBGB).
- **Cache:** `local/tradeable_jobs/cache/`. Results are keyed on the md5 of the script and its function files. `options(tj.refresh = TRUE)` reruns everything.
- **Papers:** `local/tradeable_jobs/papers_raw/` and `papers_md/`. They're copyright, so they aren't committed.
- **Outputs (CSV):** `docs/chunks/tradeable_jobs/outputs/`.

## Scripts

| File | Does |
|---|---|
| `functions_common.R` | Caching, downloads, skewness, writing outputs |
| `functions_v2020.R` | Model A: any number of city types (tradable or non-tradable), mobile or immobile labour, general agglomeration function, two ways of financing government spending. Solver, entry gains, adjustment along the boundary, edges of the equilibrium set. |
| `functions_v2018s3.R` | Model B: V2018 section 3 (two tradables, two skills). Newton solver, entry gains, adjustment, the point without coordination failure. |
| `functions_rv2023.R` | Model C/D: Rice and Venables (2023), with switches for mobility, land, rent rebate, trade costs and agglomeration. Sparsity measures, eq. (11) and (13). |
| `functions_dfs.R` | Dornbusch–Fischer–Samuelson (1977) with trade costs and transfers |
| `functions_uk.R` | UK data: BRES, ASHE (area and sector, fixing dropped leading zeros), GDP deflator, export shares from the input-output tables, regressions with HC3 standard errors |
| `01_v2020_parameter_check.R` | Which agglomeration slope the papers used (0.15, not the 2020 appendix's 0.015) |
| `02_v2020_curves.R` | Model A curves; the 2018 paper's statements checked |
| `03_v2020_shocks.R` | Import competition, export boom, fiscal contraction and expansion |
| `04_v2020_ablations.R` | Which ingredient each claim needs (Model A) |
| `05_v2018_two_sector.R` | Model B: equilibrium set, trade shock path, rents |
| `06_rv2023_table1.R` | Model C: elasticities, Table 1, comparative statics against finite differences |
| `07_rv2023_simulations.R` | Model C: Table 2a, 20 runs each |
| `08_ricardian_benchmarks.R` | Model D: DFS experiments, the engine with switches, agglomeration and hysteresis |
| `09_uk_sparsity.R` | Model E: UK replication of RV2023 section 4, plus export shares and London checks |
| `10_leverage.R` | Cost advantage of lagging areas against cluster premiums (C8) |
| `11_synthesis.R` | Claims against both benchmarks, verdicts by version |
| `00_run_all.R` | Clears the cache, runs 01–11, renders the report |
| `get_papers.py` | Downloads and converts the three papers to readable markdown |
