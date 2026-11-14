# Tradeable jobs: code

Code for the tradeable jobs chunk.

- **The plan** (model equations, claims, steps): [tradeable_jobs_plan.md](../../docs/chunks/tradeable_jobs/tradeable_jobs_plan.md).
- **The results:** [tradeable_jobs_firstlook.qmd](../../docs/chunks/tradeable_jobs/tradeable_jobs_firstlook.qmd).
- **Round 2** (supply chains, production chains, payment flows): the plan is [tradeable_jobs_further_tests_plan.md](../../docs/chunks/tradeable_jobs/tradeable_jobs_further_tests_plan.md) and the results so far are in [tradeable_jobs_round2.qmd](../../docs/chunks/tradeable_jobs/tradeable_jobs_round2.qmd).

## How to run

Run everything from the repo root.

```sh
Rscript code/tradeable_jobs/00_run_all.R                # everything, from scratch, then render the report
python3 -I code/tradeable_jobs/get_papers.py           # optional: the papers themselves, as readable markdown
```

**Time.** A full rebuild takes about 30 minutes: round 1 about 15, Model F's experiments a few minutes (run in parallel across cores), the demand calibration grid about 6. Rendering on its own reuses the cache.

**Requirements.**

- R packages: dplyr, tidyr, readr, readxl, ggplot2, jsonlite, plus tidyverse, knitr and ggrepel for the report. The solvers are base R.
- `get_papers.py` needs `curl`, `pdftotext` and `pdftoppm` (poppler).

## What goes where

- **Downloads:** `local/tradeable_jobs/data_raw/` (gitignored). These are BRES from Nomis (NM_189_1, NUTS 2016 level 3, SIC 3-digit, 2015–2019), ASHE tables 22.5a (ad hoc 12453) and 16.5a, the 2019 input-output analytical tables, and the GDP deflator (YBGB).
- **Cache:** `local/tradeable_jobs/cache/`. Results are keyed on the md5 of the script and its function files. `options(tj.refresh = TRUE)` reruns everything.
- **Papers:** `local/tradeable_jobs/papers_raw/` and `papers_md/`. They're copyright, so they aren't committed.
- **Outputs (CSV):** `docs/chunks/tradeable_jobs/outputs/`.
- **More downloads for round 2:** the ONS payment flows by region (`data_raw/payments/`, about 180 MB zipped), Scotland's supply–use tables (`data_raw/scotland_io/`), the ONS interregional trade estimates (`data_raw/interregional/`) and ONS labour productivity by industry division (`data_raw/ons_productivity/`).
- **Firm-level aggregates (T11a):** `local/tradeable_jobs/companieshouse/` (gitignored). The firm data come from the companieshouseopen project's report outputs, read in place; set `options(tj.ch_reports = '<path>')` if they aren't at `~/Code/companieshouseopen/local/reports`.

## Scripts

| File | Does |
|---|---|
| `functions_common.R` | Caching, downloads, skewness, writing outputs |
| `functions_v2020.R` | Model A (with, from round 2, tradables' purchases of the non-tradable as inputs): any number of city types (tradable or non-tradable), mobile or immobile labour, general agglomeration function, two ways of financing government spending. Solver, entry gains, adjustment along the boundary, edges of the equilibrium set. |
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
| `functions_io.R` | Round 2: the 2019 input–output analytical tables (product table, Leontief and Ghosh inverses, imports), CPA to SIC links, BRES employment by product, the 19 sector groups |
| `12_t2_domar_tradability.R` | T2: Domar weights against tradability; where each product's gain lands; the sector groups and input coefficients for Model F |
| `functions_ch.R` | Round 2: reading the Companies House report outputs (read-only), SIC division to sector group, the Melitz–Polanec decomposition, clustered regressions |
| `13_t11a_firm_aggregates.R` | T11a: spread of GVA per job by group, long tail against frontier, the 2019–24 decomposition, responsiveness, pass-through to pay, place after sector. Writes aggregates only, to the gitignored `local/tradeable_jobs/companieshouse/`; does nothing if the Companies House outputs aren't on the machine |
| `functions_payments.R` | Round 2: the ONS industry-to-industry payment flows by region (download, yearly sums, where each industry's business income comes from) |
| `14_t4_payment_tradability.R` | T4: a payment-based measure of tradability within the UK, checked against Scotland's input–output tables and ONS interregional trade estimates; round 1's regression with it |
| `15_t3_chain_labour.R` | T3: jobs and value added embodied along each product's UK supply chain; chain GVA per job; the jobs behind exports |
| `functions_modelF.R` | Model F: the Rice and Venables engine with intermediate inputs between sectors, fixed-price inputs, a choice of trade closure; calibration from T2's groups; outcomes on the real and official lenses |
| `16_modelF.R` | T1 with T7, T8 and T9 (model half): checks (round 1 engine, Hulten), national and local productivity experiments by group, the policy proxies, with and without supply chains, mobile and immobile labour |
| `16b_modelF_closure.R` | The national experiments under Rice and Venables's own trade closure, against Model F's |
| `17_t6_own_jobs.R` | T6: hours growth against output-per-hour growth across UK industries, 1997–2019 (ONS, experimental) |
| `18_t5_local_sourcing.R` | T5 (limited): the share of each industry's business spending paid to its own region, from the payment flows |
| `19_t10_breakeven.R` | T10: break-even cost ratios per point of productivity against a frontier push, national and for the lagging place |
| `20_t11b_moments.R` | T11b: Model F's spread of revenue productivity by sector, place and place by sector, against the firm data |
| `21_modelF_demand.R` | Model F with demand calibrated to T6: a grid over households' and firms' substitution elasticities and foreign demand's, the best fit to T6's own-jobs responses, and the experiments and break-even ratios with it |
| `functions_flow.R` | F0: the "where GVA is booked" flow model (model spec v1), ported from its TypeScript build: compiling parameters, prices, the period solver, commuting, the run loop with scenarios, identity checks, results rows; plus optional price-elastic exports and a wage curve (off by default) |
| `flow_model/` | The flow model's inputs: the calibrated spec-v1 parameters and the experiments' scenarios as JSON, exported from the TypeScript by `export-inputs.ts`; and the TypeScript's own results rows (`reference_ts_rows.csv.gz`) for the check |
| `22_flow_model.R` | Runs the flow model's baseline and ten experiments and checks every standard results row against the TypeScript's |
| `23_t9_flow_slack.R` | T9: inward investment, local procurement and productivity in the flow model, in base, slack and tight economies, with the original model and an extended one (price-elastic exports, a wage curve), nationally and by place |
| `24_modelF_local_sigma.R` | Model F with an elasticity of 3 between places for local services (trade costs moved to keep their cross-place share) |
| `25_modelA_supply_chains.R` | T7: Venables's city model with tradables buying non-tradable inputs; the equilibrium range as the input share and non-tradable productivity rise |
| `26_modelF_agglomeration.R` | Model F with agglomeration elasticities 0.02 and 0.03, on the best-calibrated setting |
| `00_run_all.R` | Clears the cache, runs 01–26, renders both reports |
| `get_papers.py` | Downloads and converts the three papers to readable markdown |
