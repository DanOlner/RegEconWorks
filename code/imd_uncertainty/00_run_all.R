# Rebuild the whole IMD uncertainty pipeline from scratch, then render the report
# Run from the project root: Rscript code/imd_uncertainty/00_run_all.R
# - Downloads go to local/imd_raw/ the first time (about 3 GB, most of it DfT's all-years road casualty files)
# - Slow simulations are cached in local/imd_uncertainty/cache/; this script clears the cache first so
#   everything is recomputed. Expect 40 minutes or so
# - Outputs for other people (CSV) go to docs/chunks/imd_uncertainty/outputs/
# The report (docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd) sources the same scripts, so
# rendering it on its own also works: it reuses the cache, or builds it if missing
source('code/imd_uncertainty/functions.R')

unlink(cache_dir, recursive = TRUE)

scripts <- c(
  '01_rebuild_imd.R',             # stages 5 to 7 from published files, and all five local authority measures
  '02_income_rank_intervals.R',   # rough first look (Income domain only)
  '03_nominal_weights.R',         # nominal weights and what the open data allow
  '04_shrinkage_rebuild.R',       # shrinkage rebuilt for Income and Employment
  '05_shrinkage_inversion_test.R',# synthetic test of running shrinkage backwards
  '06_rare_event_reliability.R',  # inversion applied to crime and road casualties
  '07_income_employment_mc.R',    # Monte Carlo: Income and Employment error to IMD and local authority ranks
  '08_inversion_real_counts.R',   # inversion tested against the published counts
  '09_iod2019_shrinkage.R',       # shrinkage reading tested on the IoD 2019, and the pooling question
  '10_stage4_rebuild.R',          # stage 4 (indicators to domains) rebuilt from File 8
  '11_road_casualties.R',         # road casualty indicator rebuilt from DfT open data
  '12_census_indicators.R',       # overcrowding and adult skills from Census 2021 tables
  '13_supplementary_mc.R',        # IDACI and IDAOPI rank ranges
  '14_coverage_test.R',           # do the 90% ranges cover the truth?
  '15_full_mc.R',                 # Monte Carlo through stages 4 to 7, in three layers
  '16_lad_confidence_sets.R'      # formal confidence sets for local authority ranks (csranks)
)

for (s in scripts) {
  message('\n== ', s, ' (', format(Sys.time(), '%H:%M'), ')')
  source(file.path('code/imd_uncertainty', s), local = new.env())
}

if (!isFALSE(getOption('imd.render', TRUE))) {
  message('\n== Rendering the report (', format(Sys.time(), '%H:%M'), ')')
  status <- system2('quarto', c('render', 'docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd'))
  if (status != 0) stop('quarto render failed')
}
message('Done (', format(Sys.time(), '%H:%M'), ')')
