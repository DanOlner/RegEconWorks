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
  '12_t2_domar_tradability.R'    # T2: Domar weights against tradability, sector groups for Model F
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
