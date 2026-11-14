# Rebuild the whole tradeable jobs pipeline from scratch, then render the report.
# Run from the project root: Rscript code/tradeable_jobs/00_run_all.R
# - The papers themselves: python3 -I code/tradeable_jobs/get_papers.py (not needed for the analysis)
# - Data downloads (BRES from Nomis, ASHE and input-output tables from ONS) go to
#   local/tradeable_jobs/data_raw/ the first time (gitignored)
# - Results are cached in local/tradeable_jobs/cache/; this script clears the cache first, so expect about
#   15 minutes. options(tj.render = FALSE) skips the render.
# The reports (docs/chunks/tradeable_jobs/tradeable_jobs_firstlook.qmd for round 1, tradeable_jobs_round2.qmd
# for round 2) source the same scripts, so rendering one on its own also works: it reuses the cache, or
# builds it if missing. Round 2's scripts read round 1's outputs (uk_sectors.csv), so run 09 first.
# 13 reads the companieshouseopen report outputs (read-only; options(tj.ch_reports = ...) sets where) and
# writes aggregates only, to the gitignored local/tradeable_jobs/companieshouse/. Without them it does nothing.

source('code/tradeable_jobs/functions_common.R')
unlink(tj_cache_dir, recursive = TRUE)
dir.create(tj_cache_dir, recursive = TRUE, showWarnings = FALSE)

scripts <- c(
  '01_v2020_parameter_check.R',  # which agglomeration slope the papers used
  '02_v2020_curves.R',           # Model A curves and the 2018 paper's statements about them
  '03_v2020_shocks.R',           # import competition, export boom, fiscal contraction and expansion
  '04_v2020_ablations.R',        # which ingredient each claim needs (Model A)
  '05_v2018_two_sector.R',       # Model B: two tradable sectors, two skills, the lozenge
  '06_rv2023_table1.R',          # Model C: elasticities, Table 1, comparative statics
  '07_rv2023_simulations.R',     # Model C: Table 2a, 20 runs
  '08_ricardian_benchmarks.R',   # Model D: DFS, the RV2023 engine with switches, agglomeration
  '09_uk_sparsity.R',            # Model E: UK replication with BRES and ASHE, plus export shares
  '10_leverage.R',               # how far costs can fall in lagging places, against cluster premiums
  '11_synthesis.R',              # claims against benchmarks, verdicts by version
  # round 2
  '12_t2_domar_tradability.R',   # T2: Domar weights against tradability, sector groups for Model F
  '13_t11a_firm_aggregates.R',   # T11a: firm-level aggregates by group (needs the Companies House outputs)
  '14_t4_payment_tradability.R', # T4: tradability within the UK from payment flows; Scottish and interregional checks
  '15_t3_chain_labour.R',        # T3: jobs and value added embodied along each product's UK supply chain
  '16_modelF.R',                 # T1: Model F, the Rice and Venables engine with supply chains; T7, T8, T9 (model half)
  '16b_modelF_closure.R',        # Model F under Rice and Venables's own trade closure, for comparison
  '17_t6_own_jobs.R',            # T6: productivity growth against own hours, UK industries 1997-2019
  '18_t5_local_sourcing.R',      # T5 (limited): how locally each industry buys, from the payment flows
  '19_t10_breakeven.R',          # T10: break-even cost ratios per point of productivity, national and local
  '20_t11b_moments.R',           # T11b: Model F's revenue productivity against the firm data's
  '21_modelF_demand.R',          # Model F with demand calibrated to T6 (CES households and inputs, export elasticity)
  '22_flow_model.R',             # F0: the flow model in R, checked row by row against its TypeScript build
  '23_t9_flow_slack.R',          # T9: demand and productivity policies in the flow model; base, slack and tight economies
  '24_modelF_local_sigma.R',     # Model F with an elasticity of 3 between places for local services
  '25_modelA_supply_chains.R',   # T7: supply chains in Venables's city model (Model A)
  '26_modelF_agglomeration.R',   # Model F with agglomeration (0.02, 0.03)
  '27_solvers.R',                # equilibrium solvers for multiple equilibria: test case, bifurcation scan, full model
  '28_strong_agglomeration_draws.R'  # strong agglomeration (0.3) over six productivity draws: equilibria and policy switching
)
for (s in scripts) {
  message('== ', s)
  t0 <- Sys.time()
  source(file.path('code/tradeable_jobs', s), local = new.env())
  message('   ', round(difftime(Sys.time(), t0, units = 'mins'), 1), ' min')
}

if (!isFALSE(getOption('tj.render'))) {
  system2('quarto', c('render', 'docs/chunks/tradeable_jobs/tradeable_jobs_firstlook.qmd'))
  system2('quarto', c('render', 'docs/chunks/tradeable_jobs/tradeable_jobs_round2.qmd'))
}
