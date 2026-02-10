# run.R — Entrypoint script for the Expected vs Observed Flows module.
# Running this script should reproduce all results and save outputs to outputs/.
#
# Usage: source("run.R") or Rscript run.R

# Load shared functions
# source("../../R/flow_analysis.R")
# source("../../R/data_processing.R")

# Load data
# df <- read.csv("../../data/example_flows.csv")

# Run analysis
# results <- your_analysis_function(df)

# Save outputs
# write.csv(results, "outputs/results.csv", row.names = FALSE)
# ggsave("outputs/figure_1.png", plot = your_plot)

message("Module 'expected-vs-observed' complete. Outputs saved to outputs/.")
