# Playing around with standard errors for the ABS component of regional GVA
# How much are places actually separarable for sectors?
library(tidyverse)
library(zoo)
library(patchwork)
library(furrr)

plan(multisession, workers = availableCores() - 1)

# Grab some functions from the regionalecontools repo
source('https://raw.githubusercontent.com/DanOlner/RegionalEconomicTools/refs/heads/gh-pages/functions/misc_functions.R')

# And some for processing SIC codes into the correct bins
source('code/data_process_functions.R')

options(scipen = 999)

# DAN CODE----

## Get data----

# From here for regional, including quality measures
# https://www.ons.gov.uk/businessindustryandtrade/business/businessservices/bulletins/nonfinancialbusinesseconomyukandregionalannualbusinesssurvey/2023results?utm_source=chatgpt.com

# Just 2 digit for regional level

# Actual values first
# https://www.ons.gov.uk/businessindustryandtrade/business/businessservices/datasets/uknonfinancialbusinesseconomyannualbusinesssurveyregionalresultssectionsas
url1 <- 'https://www.ons.gov.uk/file?uri=/businessindustryandtrade/business/businessservices/datasets/uknonfinancialbusinesseconomyannualbusinesssurveyregionalresultssectionsas/current/absregionalsectionas2023.xlsx'
p1f <- tempfile(fileext=".xlsx")
download.file(url1, p1f, mode="wb") 

# Each region is in its own sheet. We'll need to read each separately to get all the data for that
# Get sheet names first from the contents
# All ITL1 subregions...
# https://www.reddit.com/r/rstats/comments/nr3xhj/removing_rest_of_string_after_a_certain_character/
sheetnames = readxl::read_excel(path = p1f,range = "Contents!A5:A16") %>%
  pull(`Table 1: North East`) %>%
  str_split_i(., ':', i = 2) %>% #https://stackoverflow.com/a/74727577
  trimws()

# Add North East back in
sheetnames = c(sheetnames,'North East')
  
# getregion = function(region){
#     region = readxl::read_excel(path = p1f,range = paste0(region,"!A8:I1575"))
# }

allregions = map(sheetnames, ~ readxl::read_excel(path = p1f,range = paste0(.,"!A7:I1575"))) %>% 
  bind_rows()

#More process-able names with no spaces
names(allregions) <- gsub(x = names(allregions), pattern = ' ', replacement = '_')

# Replace any non-numeric with NA and make numeric
# Those would be e.g. disclosure issues
# NAs introduced is exactly what we want
allregions = allregions %>% 
  mutate(
    across(6:9, as.numeric)
  )

# Better names plz
names(allregions)[1] = 'SIC'
names(allregions)[6:9] = c('turnover','GVA','goods_materials_services_purchased','employment_costs')


# Then get the error rates from the quality measures excel sheet
# Different structure, single sheet this time
# From https://www.ons.gov.uk/businessindustryandtrade/business/businessservices/datasets/uknonfinancialbusinesseconomyannualbusinesssurveyregionalresultsqualitymeasures
url1 <- 'https://www.ons.gov.uk/file?uri=/businessindustryandtrade/business/businessservices/datasets/uknonfinancialbusinesseconomyannualbusinesssurveyregionalresultsqualitymeasures/2023/absregionalqualitymeasures2023.xlsx'
p1f <- tempfile(fileext=".xlsx")
download.file(url1, p1f, mode="wb") 

# Some of this won't be numeric cos of other codes, will need to fix
qual = readxl::read_excel(path = p1f,range = ("Section Division by Region!A7:M16471"))

names(qual) <- gsub(x = names(qual), pattern = ' ', replacement = '_')

# Replace any non-numeric with NA and make numeric
# Those would be e.g. disclosure issues
# NAs introduced is exactly what we want
qual = qual %>% 
  mutate(
    across(6:13, as.numeric)
  )

# naaaaaames
names(qual)[1] = 'SIC'
names(qual)[6:13] = c(
  'turnover_SE',
  'GVA_SE',
  'goods_materials_services_purchased_SE',
  'employment_costs_SE',
  'turnover_CoV',
  'GVA_CoV',
  'goods_materials_services_purchased_CoV',
  'employment_costs_CoV'
  )



## Find error rates across regions and sectors----

# What sectors have we got? Let's just keep 2 digit
# Use this to keep 2 digit without too much faff
siclookup = read_csv('https://github.com/DanOlner/RegionalEconomicTools/raw/refs/heads/gh-pages/data/SIClookup.csv')

allregions = allregions %>% 
  mutate(SIC = str_sub(SIC,1,2)) %>% 
  filter(SIC %in% unique(siclookup$SIC_2DIGIT_CODE))

qual = qual %>% 
  mutate(SIC = str_sub(SIC,1,2)) %>% 
  filter(SIC %in% unique(siclookup$SIC_2DIGIT_CODE))

# Tick
unique(allregions$SIC)
unique(qual$SIC)


# Stick to finding GVA error rates for the mo
# Add gva in...
# NOTE: ONLY HAVE QUAL FROM 2012 VS 2008 FOR THE NOMINAL DATA
abs_gva = allregions %>% 
  select(-c(goods_materials_services_purchased,turnover,employment_costs)) %>% 
  filter(Year >= 2012) %>% 
  left_join(
    qual %>% select(-contains(c('turnover','goods_','employment','_CoV','Description','Country_and_Region'))),
    by = c('SIC','Country_Code','Year')
  ) %>% 
  mutate(
    gva_min95 = GVA - (GVA_SE * 1.96),
    gva_max95 = GVA + (GVA_SE * 1.96)
  )



# Add in coeff of variation to compare...
# And 95% CI equivalents... hmm nope
abs_gva = abs_gva %>% 
  mutate(
    CoV100 = (GVA_SE / GVA) * 100
    # CoV100_min95 = (GVA_SE / gva_min95) * 100,
    # CoV100_max95 = (GVA_SE / gva_max95) * 100,
  )

# Save for use elsewhere
write_csv(abs_gva,'data/abs_gva_se_combo.csv')


# Quite a lot of missing values - but let's see for a specific year
abs_gva2023 = abs_gva %>% 
  filter(Year == max(Year)) 

# Check sector diffs across regions
dodgewidth = 1

# ggplot(abs_gva2023, aes(y = Description, x = GVA, colour = Country_and_Region)) +
#   geom_point(position = position_dodge()) +
#   geom_errorbar(aes(xmin = gva_min95, xmax = gva_max95), position = position_dodge())

# Try one sector at a time!
ggplot(
  abs_gva2023 %>% filter(qg('fabricated',Description)),
  aes(y = fct_reorder(Country_and_Region,GVA), x = GVA)
  ) +
  geom_point() +
  geom_errorbar(aes(xmin = gva_min95, xmax = gva_max95), width = 0.3)


# And how about how it's changed over time in a few places?
setwidth = 1

ggplot(
  abs_gva %>% filter(qg('construction of buildings',Description)),
  # abs_gva %>% filter(qg('fabricated',Description)),
  aes(y = factor(Year), x = GVA)
) +
  geom_point() +
  geom_errorbar(aes(xmin = gva_min95, xmax = gva_max95), width = 0.3) +
  scale_color_brewer(palette = 'Paired') +
  facet_wrap(~Country_and_Region, ncol=1)
  
# ggplot(
#   abs_gva %>% filter(qg('fabricated',Description)),
#   aes(y = fct_reorder(Country_and_Region,GVA), x = GVA, colour = factor(Year))
# ) +
#   geom_point(position = position_dodge(width = setwidth)) +
#   geom_errorbar(aes(xmin = gva_min95, xmax = gva_max95), width = 0.3, position = position_dodge(width = setwidth)) +
#   scale_color_brewer(palette = 'Paired')



# We want proportions really.
# But that's tricky with error rates
# Partial prob the way forward - 
# If others at 'expected' value, how much can x sector vary?

# Or just use coeffs of variation, obv. 

# Oh also - we can't get sums because a lot of values are missing.
# Do we have totals in the orig sheet?
# Yes, in the first bunch of rows
# Except...

# Let's look at how much different sectors vary, percent wise, for one place
# Drop sectors we have no values for

# Keep only top value sectors to viz
sectorstokeep = abs_gva2023 %>% filter(
  qg('yorkshire',Country_and_Region),
  !is.na(GVA)
) %>% 
  arrange(-GVA) %>%
  slice(1:16) %>% 
  pull(Description)
  

ggplot(
  abs_gva2023 %>% filter(
    qg('yorkshire',Country_and_Region),
    !is.na(GVA),
    Description %in% sectorstokeep
    ),
  aes(y = fct_reorder(Description,GVA), x = GVA)
) +
  geom_point() +
  geom_errorbar(aes(xmin = gva_min95, xmax = gva_max95), width = 0.3) +
  ylab('')



# Version using COV100 95% bounds, for comparison
# Not quite sure this makes sense!
# ggplot(
#   abs_gva2023 %>% filter(
#     qg('yorkshire',Country_and_Region),
#     !is.na(GVA),
#     Description %in% sectorstokeep
#   ),
#   aes(y = fct_reorder(Description,CoV100), x = CoV100)
# ) +
#   geom_point() +
#   geom_errorbar(aes(xmin = CoV100_min95, xmax = CoV100_max95), width = 0.3) +
#   ylab('')




# OK. What's the 2023 GVA from the actual region by industry counts?
# Slightly different sector lists but some overlap
# Might be better to check against sections, no?



## Process data for applying those error rates to ITL1 CP and CV values----

# Outputted these to CSV in yorkshire_n_humber_sectors_dataprep.R in the regecontools repo
itl1.cp = read_csv('https://raw.githubusercontent.com/DanOlner/RegionalEconomicTools/refs/heads/gh-pages/data/regionalGVA/regionalGVA_currentprices_ITL1_SIC_2DIGIT_WIDE_2023.csv')
itl1.cv = read_csv('https://raw.githubusercontent.com/DanOlner/RegionalEconomicTools/refs/heads/gh-pages/data/regionalGVA/regionalGVA_chainedvolume_ITL1_SIC_2DIGIT_WIDE_2023.csv')

# Check sector match. Will have to make numeric, not matching digits
# Quick other checks
abs_gva %>% select(SIC,Description) %>% distinct() %>% View
itl1.cp %>% select(SIC07_code,SIC07_description) %>% distinct() %>% View

table(as.numeric(abs_gva$SIC))

# Of course we have the differing categorisations in the GVA data
# But also a function for that...

# Those will be a the same SICs for both CV and CP
itl1.cp.longsics = make.GVA.SICs.long(itl1.cp)

# Readload abs gva here and sum by those bespoke categories
# We just want a coefficient of variation we can apply to the new numbers...
abs_gva = read_csv('data/abs_gva_se_combo.csv') %>% 
  rename(Region_name = Country_and_Region) %>% 
  mutate(
    SIC07_code_numeric = as.numeric(SIC)#To match longenated GVA SICs
    ) %>% 
  mutate(
    Region_name = ifelse(Region_name == 'East of England', 'East', Region_name)#To match other data
  )

abs_gva.shorterSIClist = abs_gva %>% 
  left_join(
    itl1.cp.longsics %>% select(SIC07_description_fromGVAdata = SIC07_description,SIC07_code_fromGVAdata,SIC07_code_numeric),
    by = 'SIC07_code_numeric'
  )

# Keep and use only the CoV
abs_gva.shorterSIClist = abs_gva.shorterSIClist %>% 
  group_by(Region_name,Year,SIC07_code_fromGVAdata) %>% 
  summarise(
    CoV100 = weighted.mean(CoV100,GVA)
    # across(GVA:gva_max95, sum, .names = "{col}_sum")
    # across(GVA:gva_max95, ~sum(., na.rm = T), .names = "{col}_sum")
  ) %>% ungroup()

# The NAs there we should probably keep - incidates missing values, so sector totals won't be correct
# Merge names from reg GVA data back in
# abs_gva.shorterSIClist = abs_gva.shorterSIClist %>% 
#   left_join(
#     itl1.cp %>% select(SIC07_code_fromGVAdata = SIC07_code,SIC07_description) %>% distinct(),
#     by = 'SIC07_code_fromGVAdata'
#   )

# We should then be able to join back to the itl1.cp and cv data
# Let's just check ITL1 name matches... some fixes, done
table(unique(itl1.cp$Region_name) %in% abs_gva.shorterSIClist$Region_name)
unique(itl1.cp$Region_name)[!unique(itl1.cp$Region_name) %in% abs_gva.shorterSIClist$Region_name]



# Inner join to keep only matches, especially on year
itl1.cp.linked = itl1.cp %>% 
  inner_join(
    abs_gva.shorterSIClist,
    by = c('Region_name','year' = 'Year','SIC07_code' = 'SIC07_code_fromGVAdata')
  ) %>% 
  mutate(
    SE = value * (CoV100/100),#A little unnecessary there!
    gva_min95 = value - (SE * 1.96),
    gva_max95 = value + (SE * 1.96)
  )

# Save...
write_csv(itl1.cp.linked,'data/itl1_cp_withestimatederrorratefromABS.csv')

itl1.cv.linked = itl1.cv %>% 
  inner_join(
    abs_gva.shorterSIClist,
    by = c('Region_name','year' = 'Year','SIC07_code' = 'SIC07_code_fromGVAdata')
  ) %>% 
  mutate(
    SE = value * (CoV100/100),
    gva_min95 = value - (SE * 1.96),
    gva_max95 = value + (SE * 1.96)
  )

# Save...
write_csv(itl1.cv.linked,'data/itl1_cv_withestimatederrorratefromABS.csv')



# While we're here...
# What number of 2-digits do we get from the inner join?
# 73 in the join
unique(itl1.cv.linked$SIC07_description)
# 82 in the orig
unique(itl1.cv$SIC07_description)

# OK - out of public sectors, only health is still present in the ABS data
unique(itl1.cv$SIC07_description)[!unique(itl1.cv$SIC07_description) %in% unique(itl1.cv.linked$SIC07_description)]



# CHECK ON GVA DIFFERENCE BETWEEN REG BY INDUSTRY DATA VS ABS----

# Or: why have I chosen to apply CoV to the regxind data, not just use the original GVA?
# So can compare to the values we're using, though they're constructed to be top down 
# But would be good to check how similar they are.

# We'll just use sectors that directly match
# Not any where we've used the weighted avs above
abs_gva = read_csv('data/abs_gva_se_combo.csv') %>% 
  rename(Region_name = Country_and_Region) %>% 
  mutate(
    SIC07_code_numeric = as.numeric(SIC)#To match longenated GVA SICs
  ) %>% 
  mutate(
    Region_name = ifelse(Region_name == 'East of England', 'East', Region_name)#To match other data
  )

# Check direct matches...
# Only on CP too, these are raw numbers (I believe)
itl1.cp = itl1.cp %>% 
  mutate(
    SIC07_code_numeric = as.numeric(SIC07_code)
  )

# NAs produced there will be the combo sectors we're not going to use anyway
table(unique(itl1.cp$SIC07_code_numeric))

# Falses will be sectors not directly surveyed presumably...
table(unique(itl1.cp$SIC07_code_numeric) %in% abs_gva$SIC07_code_numeric)

# Yep, plus ones that are combinations of SICs
unique(itl1.cp$SIC07_description[!itl1.cp$SIC07_code_numeric %in% unique(abs_gva$SIC07_code_numeric)])


# OK, inner join where we have both
gva.check = abs_gva %>% 
  select(Region_name,year = Year,gva_from_abs = GVA,CoV100,SIC07_code_numeric) %>% 
  inner_join(
    itl1.cp %>% select(-SIC07_code) %>% rename(gva_from_regbyindustry = value),
    by = c('Region_name','year','SIC07_code_numeric')
  )






## Visualise discrepancy between ABS GVA and regional-by-industry GVA----

# Remove rows where either source is missing
gva.check.clean = gva.check %>%
  filter(!is.na(gva_from_abs), !is.na(gva_from_regbyindustry))

# Nominal difference
gva.check.clean = gva.check.clean %>%
  mutate(
    diff_nominal = gva_from_abs - gva_from_regbyindustry,
    diff_pct = ((gva_from_abs - gva_from_regbyindustry) / gva_from_regbyindustry) * 100
  )

# --- Plot 1: Nominal difference by sector (averaged across regions and years) ---
sector_diffs = gva.check.clean %>%
  left_join(
    itl1.cp %>% select(SIC07_code_numeric, SIC07_description) %>% distinct(),
    by = 'SIC07_code_numeric'
  ) %>%
  group_by(SIC07_description) %>%
  summarise(
    mean_diff = mean(diff_nominal, na.rm = TRUE),
    median_diff = median(diff_nominal, na.rm = TRUE),
    mean_pct_diff = mean(diff_pct, na.rm = TRUE),
    median_pct_diff = median(diff_pct, na.rm = TRUE),
    n = n()
  ) %>%
  filter(!is.na(SIC07_description))

p_nominal = ggplot(
  sector_diffs %>% mutate(abs_higher = mean_diff > 0),
  aes(y = fct_reorder(SIC07_description, mean_diff), x = mean_diff, fill = abs_higher)
) +
  geom_col() +
  geom_vline(xintercept = 0, linetype = 'dashed') +
  scale_fill_manual(
    values = c('TRUE' = 'steelblue', 'FALSE' = 'coral'),
    labels = c('TRUE' = 'ABS higher', 'FALSE' = 'Reg-by-Industry higher'),
    name = ''
  ) +
  labs(
    title = "Mean nominal GVA difference: ABS minus Regional-by-Industry",
    subtitle = "Averaged across all ITL1 regions and years",
    x = "Mean difference (£m)",
    y = ""
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 11, face = "bold"),
    plot.subtitle = element_text(size = 9, colour = "grey40"),
    axis.text.y = element_text(size = 7),
    legend.position = "bottom"
  )

p_nominal

# --- Plot 2: Percentage difference by sector ---
p_pct = ggplot(
  sector_diffs %>% mutate(abs_higher = mean_pct_diff > 0),
  aes(y = fct_reorder(SIC07_description, mean_pct_diff), x = mean_pct_diff, fill = abs_higher)
) +
  geom_col() +
  geom_vline(xintercept = 0, linetype = 'dashed') +
  scale_fill_manual(
    values = c('TRUE' = 'steelblue', 'FALSE' = 'coral'),
    labels = c('TRUE' = 'ABS higher', 'FALSE' = 'Reg-by-Industry higher'),
    name = ''
  ) +
  labs(
    title = "Mean percentage GVA difference: ABS minus Regional-by-Industry",
    subtitle = "Averaged across all ITL1 regions and years. % of regional-by-industry value.",
    x = "Mean difference (%)",
    y = ""
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 11, face = "bold"),
    plot.subtitle = element_text(size = 9, colour = "grey40"),
    axis.text.y = element_text(size = 7),
    legend.position = "bottom"
  )

p_pct

# Save plot for use in output
saveRDS(p_pct,'local/abs_v_regbyindustry_gvapercentplot.rds')

# --- Plot 3: Scatter of the two values, coloured by region ---
gva.check.labelled = gva.check.clean %>%
  left_join(
    itl1.cp %>% select(SIC07_code_numeric, SIC07_description) %>% distinct(),
    by = 'SIC07_code_numeric'
  )

ggplot(gva.check.labelled, aes(x = gva_from_regbyindustry, y = gva_from_abs, colour = Region_name)) +
  geom_abline(slope = 1, intercept = 0, linetype = 'dashed', colour = 'grey50') +
  geom_point(alpha = 0.4, size = 1) +
  scale_x_continuous(labels = scales::comma_format()) +
  scale_y_continuous(labels = scales::comma_format()) +
  labs(
    title = "ABS GVA vs Regional-by-Industry GVA",
    subtitle = "Each point = one sector/region/year. Dashed line = 1:1.",
    x = "GVA from Regional-by-Industry (£m)",
    y = "GVA from ABS (£m)",
    colour = "Region"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 11, face = "bold"),
    plot.subtitle = element_text(size = 9, colour = "grey40"),
    legend.position = "right"
  )

# --- Plot 4: Percentage difference distribution by region ---
ggplot(gva.check.labelled, aes(x = diff_pct, y = fct_reorder(Region_name, diff_pct, .fun = median))) +
  geom_boxplot(outlier.size = 0.8, fill = 'steelblue', alpha = 0.3) +
  geom_vline(xintercept = 0, linetype = 'dashed') +
  labs(
    title = "Distribution of % GVA difference by region",
    subtitle = "(ABS - Regional-by-Industry) / Regional-by-Industry × 100",
    x = "Difference (%)",
    y = ""
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 11, face = "bold"),
    plot.subtitle = element_text(size = 9, colour = "grey40")
  )


# CLAUDE CODE SECTION:----

## Look at error rates----

# Start with growth in some key sectors, shall we?
# Let's pick on fabricate metal again

# Load the linked data with error rates
itl1.cv.linked = read_csv('data/itl1_cv_withestimatederrorratefromABS.csv')

# Function to plot sector GVA with error bars across regions over time
plot_sector_gva_with_errors <- function(data, sector_pattern, title_suffix = "", region_pattern = NULL) {

  # Filter to sector using pattern matching (case insensitive)
  sector_data <- data %>%
    filter(grepl(sector_pattern, SIC07_description, ignore.case = TRUE))

  if(!is.null(region_pattern)) {
    sector_data <- sector_data %>%
      filter(Region_name == region_pattern)
  }

  if(nrow(sector_data) == 0) {
    stop(paste("No data found for sector pattern:", sector_pattern))
  }

  # Get the actual sector name for the title
  sector_name <- unique(sector_data$SIC07_description)[1]
  region_label <- if(!is.null(region_pattern)) unique(sector_data$Region_name)[1] else NULL
  title_text <- paste0("GVA with 95% CI: ", sector_name,
                       if(!is.null(region_label)) paste0(" — ", region_label) else "")

  # Create the plot
  p <- ggplot(sector_data, aes(x = year, y = value)) +
    geom_ribbon(aes(ymin = gva_min95, ymax = gva_max95),
                alpha = 0.3, fill = "steelblue") +
    geom_line(colour = "steelblue", linewidth = 0.8) +
    geom_point(colour = "steelblue", size = 1.5) +
    labs(
      title = title_text,
      subtitle = "Shaded area shows uncertainty from ABS coefficient of variation",
      x = "Year",
      y = "GVA (£m, chained volume)",
      caption = "Source: ONS Regional GVA with error rates from Annual Business Survey"
    ) +
    theme_minimal() +
    theme(
      strip.text = element_text(face = "bold", size = 9),
      plot.title = element_text(size = 11, face = "bold"),
      plot.subtitle = element_text(size = 9, colour = "grey40"),
      axis.text.x = element_text(angle = 45, hjust = 1, size = 7)
    )

  # Only facet if showing multiple regions
  if(is.null(region_pattern)) {
    p <- p + facet_wrap(~Region_name, scales = "free_y", ncol = 3)
  }

  return(p)
}

# Plot fabricated metal products
plot_sector_gva_with_errors(itl1.cv.linked, "fabricated metal")
plot_sector_gva_with_errors(itl1.cv.linked, "construction of buildings")
plot_sector_gva_with_errors(itl1.cv.linked, "telecom")
plot_sector_gva_with_errors(itl1.cv.linked, "computer programming")
plot_sector_gva_with_errors(itl1.cv.linked, "computer programming", region_pattern = "West Midlands")
plot_sector_gva_with_errors(itl1.cv.linked, "computer programming", region_pattern = "East")





# Save all combinations of ITL1 / sector separately
combos <- expand_grid(
  sector = unique(itl1.cv.linked$SIC07_description),
  region = unique(itl1.cv.linked$Region_name)
)

pwalk(combos, function(sector, region) {
  tryCatch({
    safe_sector <- gsub('[[:punct:]]| ', '', sector)
    safe_region <- gsub('[[:punct:]]| ', '', region)
    p <- plot_sector_gva_with_errors(itl1.cv.linked, sector, region_pattern = region)
    ggsave(
      filename = paste0("docs/miscimages/chainedvol_growtherror_plots/timeseriesplot_foreachITL1_sectorcombo/", safe_sector, '_', safe_region, '.png'),
      plot = p, width = 6, height = 4
    )
  }, error = function(e) cat("Failed for:", sector, "/", region, "\n", e$message, "\n"))
})




## Year-on-year growth rates with bounds----

# Calculate YoY growth for central value and bounds
# Option (a): growth of each series separately
# Option (b) would be bounds on growth rate itself (more pessimistic)
itl1.cv.growth <- itl1.cv.linked %>%
  arrange(Region_name, SIC07_code, year) %>%
  group_by(Region_name, SIC07_code, SIC07_description) %>%
  mutate(
    # Central value growth
    growth = (value / lag(value)) - 1,
    # Growth of the bounds themselves
    growth_min95 = (gva_min95 / lag(gva_min95)) - 1,
    growth_max95 = (gva_max95 / lag(gva_max95)) - 1,
    # Also calculate "bounds on growth" (option b) - more conservative
    # Worst case low: this year's min vs last year's max
    # Worst case high: this year's max vs last year's min
    growth_bound_low = (gva_min95 / lag(gva_max95)) - 1,
    growth_bound_high = (gva_max95 / lag(gva_min95)) - 1,
    # Boolean: does CI exclude zero? (i.e. growth is distinguishable from no change)
    # Less conservative: based on growth of bounds
    excludes_zero = (growth_min95 > 0 & growth_max95 > 0) | (growth_min95 < 0 & growth_max95 < 0),
    # Conservative: based on bounds on growth rate
    excludes_zero_conservative = (growth_bound_low > 0) | (growth_bound_high < 0)
  ) %>%
  ungroup()


# Function to plot YoY growth rates with uncertainty bounds across regions
plot_sector_growth_with_bounds <- function(data, sector_pattern, use_conservative_bounds = TRUE, region_pattern = NULL) {

  # Filter to sector

  sector_data <- data %>%
    filter(grepl(sector_pattern, SIC07_description, ignore.case = TRUE)) %>%
    filter(!is.na(growth))  # Remove first year (no growth calc possible)

  if(!is.null(region_pattern)) {
    sector_data <- sector_data %>%
      filter(Region_name == region_pattern)
  }

  if(nrow(sector_data) == 0) {
    stop(paste("No data found for sector pattern:", sector_pattern))
  }

  sector_name <- unique(sector_data$SIC07_description)[1]

  # Choose which bounds to use
  if(use_conservative_bounds) {
    sector_data <- sector_data %>%
      mutate(ymin = growth_bound_low, ymax = growth_bound_high)
    bounds_label <- "Conservative bounds (min/max vs max/min)"
  } else {
    sector_data <- sector_data %>%
      mutate(ymin = growth_min95, ymax = growth_max95)
    bounds_label <- "Growth of 95% CI bounds"
  }

  # Build title — include region name if single region
  region_label <- if(!is.null(region_pattern)) unique(sector_data$Region_name)[1] else NULL
  title_text <- paste0("YoY GVA growth: ", sector_name,
                       if(!is.null(region_label)) paste0(" — ", region_label) else "")

  # Plot
  p <- ggplot(sector_data, aes(x = year, y = growth)) +
    geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
    geom_ribbon(aes(ymin = ymin, ymax = ymax),
                alpha = 0.3, fill = "steelblue") +
    geom_line(colour = "steelblue", linewidth = 0.8) +
    geom_point(aes(colour = ymin > 0 | ymax < 0), size = 2.5) +
    scale_colour_manual(
      values = c("FALSE" = "steelblue", "TRUE" = "green"),
      labels = c("FALSE" = "Includes zero", "TRUE" = "Excludes zero"),
      name = "Growth CI"
    ) +
    scale_y_continuous(labels = scales::percent_format()) +
    labs(
      title = title_text,
      subtitle = bounds_label,
      x = "Year",
      y = "Growth rate",
      caption = "Green points: 95% CI excludes zero (distinguishable growth/decline)"
    ) +
    theme_minimal() +
    theme(
      strip.text = element_text(face = "bold", size = 9),
      plot.title = element_text(size = 11, face = "bold"),
      plot.subtitle = element_text(size = 9, colour = "grey40"),
      axis.text.x = element_text(angle = 45, hjust = 1, size = 7),
      legend.position = "bottom"
    )

  # Only facet if showing multiple regions
  if(is.null(region_pattern)) {
    p <- p + facet_wrap(~Region_name, scales = "free_y", ncol = 3)
  }

  return(p)
}

# Plot YoY growth for fabricated metal products
plot_sector_growth_with_bounds(itl1.cv.growth, "fabricated metal")
plot_sector_growth_with_bounds(itl1.cv.growth, "construction of buildings")
plot_sector_growth_with_bounds(itl1.cv.growth, "computer programming")

# Compare with less conservative bounds
# plot_sector_growth_with_bounds(itl1.cv.growth, "fabricated metal", use_conservative_bounds = FALSE)


# DAN CODING: checks on some of the data above----

# Save West Midlands computer prog as example
# write_csv(
#   itl1.cv.growth %>% 
#     filter(
#       qg('west mid', Region_name),
#       qg('computer prog', SIC07_description)
#       ),
#   'claude/wm_computerprog_itl1cv.csv')

# For the 'excludes zero' in the year on year growth trends
# Which sectors manage that the most over the years?
# itl1.cv.growth %>%
#   filter(!is.na())


# Let's also find the slopes so we can look at fastest growing/shrinkaging sectors overall
cv_slopes = get_slope_and_se_safely(
  itl1.cv.linked,
  Region_name,SIC07_description, 
  y = log(value), 
  x = year
)

# Find sector slope averages...
meansectorslopes = cv_slopes %>% 
  group_by(SIC07_description) %>% 
  summarise(meanslope = mean(slope)) %>% 
  arrange(meanslope)


# BACK TO CLAUDE----  

## Pairwise year comparison heatmaps----

# Function to create pairwise year CI overlap matrix for a sector across regions
# Shows which years are distinguishably different from which other years
plot_pairwise_year_heatmap <- function(data, sector_pattern, region_pattern = NULL) {


  # Filter to sector
  sector_data <- data %>%
    filter(grepl(sector_pattern, SIC07_description, ignore.case = TRUE))

  if(!is.null(region_pattern)) {
    sector_data <- sector_data %>%
      filter(Region_name == region_pattern)
  }

  if(nrow(sector_data) == 0) {
    stop(paste("No data found for sector pattern:", sector_pattern))
  }

  sector_name <- unique(sector_data$SIC07_description)[1]

  # For each region, create pairwise year comparisons
  # Two years are "distinguishable" if their 95% CIs don't overlap
  pairwise_results <- sector_data %>%
    select(Region_name, year, value, gva_min95, gva_max95) %>%
    # Self-join to get all year pairs
    inner_join(
      sector_data %>% select(Region_name, year2 = year, value2 = value,
                             gva_min95_2 = gva_min95, gva_max95_2 = gva_max95),
      by = "Region_name",
      relationship = "many-to-many"
    ) %>%
    # Check if CIs overlap: overlap if max of mins < min of maxs
    mutate(
      ci_overlap = pmax(gva_min95, gva_min95_2) < pmin(gva_max95, gva_max95_2),
      distinguishable = !ci_overlap,
      # Also calculate the direction of difference
      direction = case_when(
        !distinguishable ~ "Not distinguishable",
        value > value2 ~ "Year 1 higher",
        value < value2 ~ "Year 1 lower",
        TRUE ~ "Equal"
      )
    )

  # Create heatmap - faceted by region
  p <- ggplot(pairwise_results, aes(x = factor(year), y = factor(year2), fill = distinguishable)) +
    geom_tile(colour = "white", linewidth = 0.3) +
    scale_fill_manual(
      values = c("FALSE" = "grey85", "TRUE" = "steelblue"),
      labels = c("FALSE" = "CIs overlap", "TRUE" = "CIs don't overlap"),
      name = ""
    ) +
    facet_wrap(~Region_name, ncol = 3) +
    labs(
      title = paste0("Pairwise year distinguishability: ", sector_name),
      subtitle = "Blue = 95% confidence intervals do not overlap (years are distinguishable)",
      x = "Year",
      y = "Year",
      caption = "Based on 95% CIs from ABS coefficient of variation"
    ) +
    theme_minimal() +
    theme(
      strip.text = element_text(face = "bold", size = 9),
      plot.title = element_text(size = 11, face = "bold"),
      plot.subtitle = element_text(size = 9, colour = "grey40"),
      axis.text.x = element_text(angle = 45, hjust = 1, size = 7),
      axis.text.y = element_text(size = 7),
      legend.position = "bottom",
      panel.grid = element_blank()
    ) +
    coord_fixed()

  return(p)
}

# Plot pairwise heatmaps
plot_pairwise_year_heatmap(itl1.cv.linked, "computer programming")
plot_pairwise_year_heatmap(itl1.cv.linked, "fabricated metal")

# Single region version
plot_pairwise_year_heatmap(itl1.cv.linked, "computer programming", "West Midlands")


# Version with direction: shows which year is higher when CIs don't overlap
plot_pairwise_year_heatmap_direction <- function(data, sector_pattern, region_pattern = NULL) {

  # Filter to sector
  sector_data <- data %>%
    filter(grepl(sector_pattern, SIC07_description, ignore.case = TRUE))

  if(!is.null(region_pattern)) {
    sector_data <- sector_data %>%
      filter(Region_name == region_pattern)
  }

  if(nrow(sector_data) == 0) {
    stop(paste("No data found for sector pattern:", sector_pattern))
  }

  sector_name <- unique(sector_data$SIC07_description)[1]

  # For each region, create pairwise year comparisons
  pairwise_results <- sector_data %>%
    select(Region_name, year, value, gva_min95, gva_max95) %>%
    inner_join(
      sector_data %>% select(Region_name, year2 = year, value2 = value,
                             gva_min95_2 = gva_min95, gva_max95_2 = gva_max95),
      by = "Region_name",
      relationship = "many-to-many"
    ) %>%
    mutate(
      # Check if either year has missing CI data
      missing_data = is.na(gva_min95) | is.na(gva_max95) | is.na(gva_min95_2) | is.na(gva_max95_2),
      ci_overlap = pmax(gva_min95, gva_min95_2) < pmin(gva_max95, gva_max95_2),
      # Four-way comparison: no data, overlap, column year higher, column year lower
      # Note: x-axis (columns) = year, y-axis (rows) = year2
      # value is for 'year' (column), value2 is for 'year2' (row)
      comparison = case_when(
        missing_data ~ "No CI data",
        ci_overlap ~ "CIs overlap",
        value > value2 ~ "Column year higher",
        value < value2 ~ "Column year lower",
        TRUE ~ "CIs overlap"  # Equal case (unlikely)
      )
    )

  # Create heatmap with four colours
  p <- ggplot(pairwise_results, aes(x = factor(year), y = factor(year2), fill = comparison)) +
    geom_tile(colour = "white", linewidth = 0.3) +
    # Add crosses for missing data cells
    geom_text(data = pairwise_results %>% filter(comparison == "No CI data"),
              aes(label = "×"), colour = "grey50", size = 3) +
    scale_fill_manual(
      values = c("No CI data" = "grey95",
                 "CIs overlap" = "grey75",
                 "Column year higher" = "steelblue",
                 "Column year lower" = "coral"),
      name = ""
    ) +
    facet_wrap(~Region_name, ncol = 3) +
    labs(
      title = paste0("Pairwise year comparison: ", sector_name),
      subtitle = "Blue = column > row, Coral = column < row, Grey = indistinguishable, × = no CI data",
      x = "Year (column)",
      y = "Year (row)",
      caption = "Colour shows direction when 95% CIs don't overlap"
    ) +
    theme_minimal() +
    theme(
      strip.text = element_text(face = "bold", size = 9),
      plot.title = element_text(size = 11, face = "bold"),
      plot.subtitle = element_text(size = 9, colour = "grey40"),
      axis.text.x = element_text(angle = 45, hjust = 1, size = 7),
      axis.text.y = element_text(size = 7),
      legend.position = "bottom",
      panel.grid = element_blank()
    ) +
    coord_fixed()

  return(p)
}

# Plot with direction
plot_pairwise_year_heatmap_direction(itl1.cv.linked, "computer programming")
plot_pairwise_year_heatmap_direction(itl1.cv.linked, "fabricated metal")
plot_pairwise_year_heatmap_direction(itl1.cv.linked, "land transport")#Identified with OLS slopes as shrinking on av

# Single region
plot_pairwise_year_heatmap_direction(itl1.cv.linked, "computer programming", "West Midlands")


# Save each facetted plot for each sector
# "docs/miscimages/chainedvol_growtherror_plots/pairwise_plotsforeachsector"
# dir.create('docs/miscimages/chainedvol_growtherror_plots/pairwise_plotsforeachsector', recursive = TRUE, showWarnings = FALSE)

map(unique(itl1.cv.linked$SIC07_description), ~{
  tryCatch({
    safe_name <- gsub('[[:punct:]]| ', '', .)
    p <- plot_pairwise_year_heatmap_direction(itl1.cv.linked, .)
    ggsave(
      filename = paste0('docs/miscimages/chainedvol_growtherror_plots/pairwise_plotsforeachsector/', safe_name, '.png'),
      plot = p, width = 12, height = 14
    )
  }, error = function(e) cat("Failed for:", ., "\n", e$message, "\n"))
})


# Extract panel pixel coordinates from the facetted plot for the interactive viewer.
# Approach: render the plot into a device, then use grid::convertWidth/Height
# *while inside the device* to resolve all units (including null/relative ones)
# into absolute inches. The key is that the gtable must be drawn first.
# Only needs to run once — the layout is the same for every sector.
extract_panel_coords <- function(p, img_width_in = 12, img_height_in = 14, dpi = 300) {

  img_width_px  <- img_width_in * dpi
  img_height_px <- img_height_in * dpi

  # Build the gtable
  gt <- ggplot_gtable(ggplot_build(p))

  # Open a PNG device at the exact ggsave dimensions, draw the gtable,
  # then measure. Drawing resolves the null units.
  tmp <- tempfile(fileext = ".png")
  png(tmp, width = img_width_px, height = img_height_px, res = dpi)
  grid::grid.draw(gt)

  # Now convert ALL widths and heights to inches (null units are now resolved)
  widths_in  <- sapply(seq_along(gt$widths), function(j) {
    grid::convertWidth(gt$widths[j], "inches", valueOnly = TRUE)
  })
  heights_in <- sapply(seq_along(gt$heights), function(j) {
    grid::convertHeight(gt$heights[j], "inches", valueOnly = TRUE)
  })

  dev.off()
  unlink(tmp)

  # Cumulative positions (left edges and top edges)
  cum_w <- c(0, cumsum(widths_in))   # length = ncol+1
  cum_h <- c(0, cumsum(heights_in))  # length = nrow+1

  # Find panel grobs in the layout
  panel_idx <- grep("^panel-", gt$layout$name)
  panels_layout <- gt$layout[panel_idx, ]

  # Get facet data to map panel names to region names
  build <- ggplot_build(p)
  facet_data <- build$layout$layout

  result <- lapply(seq_len(nrow(facet_data)), function(i) {
    fd <- facet_data[i, ]
    panel_name <- paste0("panel-", fd$COL, "-", fd$ROW)
    pl <- panels_layout[panels_layout$name == panel_name, ]

    # l, r, t, b are column/row indices in the gtable
    x_left   <- cum_w[pl$l]       # left edge of the left column
    x_right  <- cum_w[pl$r + 1]   # right edge of the right column
    y_top    <- cum_h[pl$t]       # top edge of the top row
    y_bottom <- cum_h[pl$b + 1]   # bottom edge of the bottom row

    list(
      region      = as.character(fd$Region_name),
      region_safe = gsub('[[:punct:]]| ', '', as.character(fd$Region_name)),
      left   = round(x_left * dpi),
      right  = round(x_right * dpi),
      top    = round(y_top * dpi),
      bottom = round(y_bottom * dpi)
    )
  })

  return(result)
}

# Build one plot to extract coords (layout is identical for all sectors)
p_for_coords <- plot_pairwise_year_heatmap_direction(itl1.cv.linked, unique(itl1.cv.linked$SIC07_description)[1])
panel_coords_list <- extract_panel_coords(p_for_coords)

# Save as a JS file (not JSON) so the HTML can load it via <script src> —
# this avoids fetch() which is blocked on file:// URLs in most browsers.

# Doesn't work - claude is instead getting dims from the images themselves
# js_json <- jsonlite::toJSON(panel_coords_list, pretty = TRUE, auto_unbox = TRUE)
# writeLines(
#   paste0("const PANEL_COORDS = ", js_json, ";"),
#   'docs/growth_errorgrids_viewer/panel_coords.js'
# )





## Combination time series plot and plot_pairwise_year_heatmap_direction----

# Combine GVA time series with pairwise heatmap for a single region/sector
plot_gva_and_heatmap <- function(data, sector_pattern, region_pattern) {

  p_gva <- plot_sector_gva_with_errors(
    data, sector_pattern,
    region_pattern = region_pattern
  )

  p_heatmap <- plot_pairwise_year_heatmap_direction(
    data, sector_pattern,
    region_pattern = region_pattern
  )

  # Stack: time series on top, heatmap below
  combined <- p_gva / p_heatmap +
    plot_layout(heights = c(1, 1.2))

  return(combined)
}

# Examples
plot_gva_and_heatmap(itl1.cv.linked, "computer programming", "West Midlands")
plot_gva_and_heatmap(itl1.cv.linked, "fabricated metal", "Yorkshire and The Humber")
plot_gva_and_heatmap(itl1.cv.linked, "land transport", "London")


# Save some elsewhere for outputs
# Edit Y&H name to fit
ggsave(
  filename = "~/Code/Regecon_modular_writeup/chunks/uncertainty_in_regionalGVA/images/YNH_growthgrid.png", 
  # filename = "~/Code/Regecon_modular_writeup/chunks/uncertainty_in_regionalGVA/images/YNH_growthgrid.png", 
       plot = plot_gva_and_heatmap(
         itl1.cv.linked %>% mutate(Region_name = ifelse(qg('yorkshire',Region_name),'Yorks & Humber',Region_name)), 
         "fabricated metal", "Yorks & Humber"),
       width = 7,height = 10)

ggsave(
  filename = "~/Code/Regecon_modular_writeup/chunks/uncertainty_in_regionalGVA/images/eastmids_growthgrid.png", 
  # filename = "~/Code/Regecon_modular_writeup/chunks/uncertainty_in_regionalGVA/images/YNH_growthgrid.png", 
       plot = plot_gva_and_heatmap(
         itl1.cv.linked, "fabricated metal", "East Midlands"),
       width = 7,height = 10)




# DAN CODE----

## How much does the introduction of error rates change LQs at ITL1 level?----
itl1.cp.linked = read_csv('data/itl1_cp_withestimatederrorratefromABS.csv')

# Repeat LQ-finding code for central estimate and upper/lower bounds then re-combine
# Let's use the average of the most recent three years
itl1.cp.smoothed = itl1.cp.linked %>% 
  group_by(Region_name,SIC07_description) %>%
  mutate(
    across(c(value,gva_min95,gva_max95), ~rollapply(.,3,mean,align='center',fill=NA), .names = "{col}_3yr_av")
  ) %>%
  ungroup() 
  # filter(!is.na(value_3yr_av)) #Keep only smoothed data years


# Find LQs for the central estimate and 95% bounds
itl1.cp.centralestLQ = itl1.cp.smoothed %>% 
  group_split(year) %>%
  map(add_location_quotient_and_proportions,
      regionvar = Region_name,
      lq_var = SIC07_description,
      valuevar = value) %>%
  bind_rows() 

itl1.cp.min = itl1.cp.smoothed %>% 
  group_split(year) %>%
  map(add_location_quotient_and_proportions,
      regionvar = Region_name,
      lq_var = SIC07_description,
      valuevar = gva_min95) %>%
  bind_rows() 

itl1.cp.max = itl1.cp.smoothed %>% 
  group_split(year) %>%
  map(add_location_quotient_and_proportions,
      regionvar = Region_name,
      lq_var = SIC07_description,
      valuevar = gva_max95) %>%
  bind_rows() 


# No point trying to keep all the 3 different sets of values here...
itl1.cp.3yrLQs = itl1.cp.centralestLQ %>%
  select(ITL_code,Region_name,SIC07_description,year,LQ_centralestimate = LQ) %>% 
  left_join(
    itl1.cp.min %>% select(ITL_code,SIC07_description,year,LQ_min95 = LQ),
    by = c('ITL_code','SIC07_description','year')
  ) %>% 
  left_join(
    itl1.cp.max %>% select(ITL_code,SIC07_description,year,LQ_max95 = LQ),
    by = c('ITL_code','SIC07_description','year')
  )
  

# Let's look at some sectors/places...
ggplot(
  itl1.cp.3yrLQs %>% filter(qg('fabricated',SIC07_description), year == max(year)),
  aes(y = fct_reorder(Region_name,LQ_centralestimate), x = LQ_centralestimate)
) +
  geom_point() +
  geom_errorbar(aes(xmin = LQ_min95, xmax = LQ_max95), width = 0.3)



# No, this is wrong. For LQs, it's tricky: 
# I was trying to find LQs separately for central, min and max but I realise that actually doesn't make sense (having seen the batty CIs) - they won't sum correctly, will they? Think this through a bit.
# - The central GVA estimate gets summed across all places, and against other sector sizes too both regionally and nationally. So the variation in the sizes of those is going to wamp out totals isn't it? Though I'm struggling a bit to visualise how.
# - Possibly I should be **holding all other values constant**, not using mins and maxes for everything

# Or more likely, using the CIs values to simulate what the values could be. That's probably a better idea.
# Let's give Claude a go at that...


# BACK TO CLAUDE----

## Monte Carlo simulation of LQs with uncertainty ----

# APPROACH:
# The naive method (computing LQs separately on central, min95, max95 values) produces
# nonsensical results because LQs are ratios of sums — when you set ALL sectors to their
# min or max simultaneously, the denominators (regional total, national total) shift in
# unrealistic ways that distort the proportions.
#
# Instead, we use Monte Carlo simulation:
# 1. For each iteration, draw a plausible GVA value for every sector/region/year combo
#    from N(value, SE), using a log-normal distribution to avoid negative draws.
# 2. Where SE is missing (NA), hold the value fixed at the central estimate.
# 3. Run the existing add_location_quotient_and_proportions function on each simulated dataset.
# 4. Collect the LQ from each iteration and summarise across iterations
#    (median, 2.5th/97.5th percentiles) to get simulated CIs on the LQ.
#
# This correctly propagates uncertainty through the sums that LQs depend on:
# in any single draw, some sectors are above their mean, some below, producing
# realistic variation in totals rather than the extreme all-high or all-low scenario.
#
# Log-normal note: we parameterise so that the mean of the log-normal equals the
# observed GVA value and the SD on the log scale corresponds to the observed SE.
# This prevents negative draws which are an issue for small sectors with large SEs.

# The problem with normal draws
# If you draw from N(GVA, SE), some draws will be negative — especially when the SE is large relative to the GVA value. Think of a small sector in a small region: maybe GVA = £50m with SE = £30m. Drawing from N(50, 30) means roughly 5% of draws will be below -£8.8m, and you'll regularly get values near zero or below it.
# 
# Negative GVA values are nonsensical for most sectors, and they'd poison the LQ calculation — the sums in the denominator could shrink toward zero or flip sign, producing wildly distorted quotients.
# 
# What the log-normal does
# A log-normal distribution is always positive — it lives on (0, ∞). So no draw can ever be negative, which matches the physical reality that a sector's output can't be less than zero.
# 
# The parameterisation trick
# The tricky bit is: we don't just want any log-normal. We want one whose mean equals the observed GVA and whose spread matches the observed SE. A log-normal with parameters μ and σ (on the log scale) has:
# 
# Mean = exp(μ + σ²/2)
# Variance = [exp(σ²) - 1] × exp(2μ + σ²)
# So the code works backwards from the observed values:
# 
# 
# # σ² on the log scale, derived from the coefficient of variation (SE/GVA)
# lnorm_sigma2 = log(1 + (SE / value)^2)
# 
# # μ on the log scale, adjusted so the mean comes out right
# lnorm_mu = log(value) - lnorm_sigma2 / 2
# That second line is the key: subtracting σ²/2 compensates for the fact that the log-normal mean is higher than exp(μ). Without that correction, your draws would be systematically too high.
# 
# When does it matter?
# For large sectors with small relative SEs (say GVA = £5000m, SE = £200m), normal and log-normal draws are nearly indistinguishable — the probability of a negative draw from the normal is vanishingly small, and both distributions look symmetric at that scale.
# 
# It matters for the long tail of small sectors with big SEs. Those are exactly the cases where the LQ denominators are most sensitive, so getting physically plausible draws there is important for the simulation to behave sensibly.

# Reload data (in case running from here)
itl1.cp.linked = read_csv('data/itl1_cp_withestimatederrorratefromABS.csv')

# Monte Carlo LQ simulation function.
# Takes a data frame (with value, SE columns) and a vector of years to simulate.
# Returns a data frame with central LQ and simulated 95% CI for each region/sector/year.
simulate_LQ_with_CIs <- function(data, years = NULL, n_sims = 500, seed = 42) {

  set.seed(seed)

  # Default: all years in the data
  if(is.null(years)) years <- sort(unique(data$year))

  # Filter to requested years
  sim_input <- data %>% filter(year %in% years)

  # Pre-compute log-normal parameters
  sim_params <- sim_input %>%
    mutate(
      has_se = !is.na(SE) & SE > 0 & value > 0,
      lnorm_sigma2 = ifelse(has_se, log(1 + (SE / value)^2), NA),
      lnorm_sigma = ifelse(has_se, sqrt(lnorm_sigma2), NA),
      lnorm_mu = ifelse(has_se, log(value) - lnorm_sigma2 / 2, NA)
    )

  # Run simulations
  sim_LQs <- vector("list", n_sims)

  for(i in 1:n_sims) {
    if(i %% 50 == 0) cat("Simulation", i, "of", n_sims, "\n")

    sim_data <- sim_params %>%
      mutate(
        sim_value = ifelse(
          has_se,
          rlnorm(n(), meanlog = lnorm_mu, sdlog = lnorm_sigma),
          value
        )
      )

    sim_LQ_result <- sim_data %>%
      group_split(year) %>%
      map(add_location_quotient_and_proportions,
          regionvar = Region_name,
          lq_var = SIC07_description,
          valuevar = sim_value) %>%
      bind_rows()

    sim_LQs[[i]] <- sim_LQ_result %>%
      select(ITL_code, Region_name, SIC07_description, year, LQ) %>%
      mutate(sim_id = i)
  }

  # Summarise simulations
  LQ_sim_summary <- bind_rows(sim_LQs) %>%
    group_by(ITL_code, Region_name, SIC07_description, year) %>%
    summarise(
      LQ_median = median(LQ, na.rm = TRUE),
      LQ_p025 = quantile(LQ, 0.025, na.rm = TRUE),
      LQ_p975 = quantile(LQ, 0.975, na.rm = TRUE),
      LQ_sd = sd(LQ, na.rm = TRUE),
      .groups = 'drop'
    )

  # Central-estimate LQs
  LQ_central <- sim_input %>%
    group_split(year) %>%
    map(add_location_quotient_and_proportions,
        regionvar = Region_name,
        lq_var = SIC07_description,
        valuevar = value) %>%
    bind_rows() %>%
    select(ITL_code, Region_name, SIC07_description, year, LQ_central = LQ)

  # Merge and return
  LQ_central %>%
    left_join(LQ_sim_summary, by = c('ITL_code', 'Region_name', 'SIC07_description', 'year'))
}

# Run for all years (reproduces previous behaviour)
n_sims <- 500
LQ_with_sim_CIs <- simulate_LQ_with_CIs(itl1.cp.linked, years = NULL, n_sims = n_sims)


# Run for first, middle and last years only
all_years <- sort(unique(itl1.cp.linked$year))
# selected_years <- all_years[c(1, ceiling(length(all_years)/2), length(all_years))]
selected_years <- all_years[c(ceiling(length(all_years)/2), length(all_years))]
cat("Simulating for years:", selected_years, "\n")

LQ_selected_years <- simulate_LQ_with_CIs(itl1.cp.linked, years = selected_years, n_sims = n_sims)


## Visualise simulated LQ uncertainty ----

# Pick a year and sector to inspect
plot_simulated_LQ <- function(data, sector_pattern, plot_year = NULL) {

  sector_data <- data %>%
    filter(grepl(sector_pattern, SIC07_description, ignore.case = TRUE, fixed = FALSE) |
           SIC07_description == sector_pattern)

  if(is.null(plot_year)) plot_year <- max(sector_data$year)

  sector_data <- sector_data %>% filter(year == plot_year)
  sector_name <- unique(sector_data$SIC07_description)[1]

  ggplot(sector_data, aes(y = fct_reorder(Region_name, LQ_central), x = LQ_central)) +
    geom_point(size = 2) +
    geom_errorbarh(aes(xmin = LQ_p025, xmax = LQ_p975), height = 0.3) +
    geom_vline(xintercept = 1, linetype = 'dashed', colour = 'blue', alpha = 0.5) +
    labs(
      title = paste0("Location Quotient with simulated 95% CI: ", sector_name),
      subtitle = paste0("Year: ", plot_year, " | ", n_sims, " Monte Carlo draws using log-normal on GVA"),
      x = "Location Quotient",
      y = "",
      caption = "Error bars: 2.5th-97.5th percentile from simulation. Dashed line = LQ of 1 (national average)."
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 11, face = "bold"),
      plot.subtitle = element_text(size = 9, colour = "grey40")
    )
}

# Example plots
plot_simulated_LQ(LQ_with_sim_CIs, "fabricated metal")
plot_simulated_LQ(LQ_with_sim_CIs, "computer programming")
plot_simulated_LQ(LQ_with_sim_CIs, "construction of buildings")
plot_simulated_LQ(LQ_with_sim_CIs, "pharmaceutical")

# Save version for use in output
# ggsave(
#   filename = "~/Code/Regecon_modular_writeup/chunks/uncertainty_in_regionalGVA/images/fabmetals_LQs.png", 
#   plot = plot_simulated_LQ(
#     LQ_with_sim_CIs %>% mutate(Region_name = ifelse(qg('yorkshire',Region_name),'Yorks & Humber',Region_name)), 
#     "fabricated metal"),
#   width = 8,height = 8)



# Sector names can contain regex special chars like () so the plot function
# now also does exact match (SIC07_description == sector_pattern) as fallback.
# tryCatch so one failed sector doesn't stop the whole batch.
# map(unique(LQ_with_sim_CIs$SIC07_description), ~{
#   tryCatch({
#     safe_name <- gsub('[[:punct:]]| ', '', .)
#     p <- plot_simulated_LQ(LQ_with_sim_CIs, .)
#     ggsave(
#       filename = paste0('local/outputs/LQ_errorbars_SIC2s/', safe_name, '.png'),
#       plot = p, width = 10, height = 10
#     )
#   }, error = function(e) cat("Failed for:", ., "\n", e$message, "\n"))
# })





# Time series version: LQ over time for a single region/sector with simulated CIs
plot_simulated_LQ_timeseries <- function(data, sector_pattern, region_pattern) {

  plot_data <- data %>%
    filter(
      grepl(sector_pattern, SIC07_description, ignore.case = TRUE),
      Region_name == region_pattern
    )

  sector_name <- unique(plot_data$SIC07_description)[1]
  region_name <- unique(plot_data$Region_name)[1]

  ggplot(plot_data, aes(x = year, y = LQ_central)) +
    geom_ribbon(aes(ymin = LQ_p025, ymax = LQ_p975), alpha = 0.3, fill = "steelblue") +
    geom_line(colour = "steelblue", linewidth = 0.8) +
    geom_point(colour = "steelblue", size = 1.5) +
    geom_hline(yintercept = 1, linetype = 'dashed', colour = 'blue', alpha = 0.5) +
    labs(
      title = paste0("LQ over time: ", sector_name),
      subtitle = paste0(region_name, " | Shaded = simulated 95% CI from ", n_sims, " MC draws"),
      x = "Year",
      y = "Location Quotient",
      caption = "Dashed line = LQ of 1 (national average). Log-normal draws on GVA with ABS standard errors."
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 11, face = "bold"),
      plot.subtitle = element_text(size = 9, colour = "grey40")
    )
}

# Example time series
plot_simulated_LQ_timeseries(LQ_with_sim_CIs, "fabricated metal", "Yorkshire and The Humber")
plot_simulated_LQ_timeseries(LQ_with_sim_CIs, "pharmaceutical", "North East")
plot_simulated_LQ_timeseries(LQ_with_sim_CIs, "computer programming", "West Midlands")


# Faceted version: all regions for one sector over time
plot_simulated_LQ_allregions <- function(data, sector_pattern) {

  plot_data <- data %>%
    filter(grepl(sector_pattern, SIC07_description, ignore.case = TRUE))

  sector_name <- unique(plot_data$SIC07_description)[1]

  ggplot(plot_data, aes(x = year, y = LQ_central)) +
    geom_ribbon(aes(ymin = LQ_p025, ymax = LQ_p975), alpha = 0.3, fill = "steelblue") +
    geom_line(colour = "steelblue", linewidth = 0.8) +
    geom_point(colour = "steelblue", size = 1) +
    geom_hline(yintercept = 1, linetype = 'dashed', colour = 'blue', alpha = 0.5) +
    facet_wrap(~Region_name, ncol = 3) +
    labs(
      title = paste0("LQ over time with simulated 95% CI: ", sector_name),
      subtitle = paste0(n_sims, " Monte Carlo draws using log-normal on GVA with ABS standard errors"),
      x = "Year",
      y = "Location Quotient"
    ) +
    theme_minimal() +
    theme(
      strip.text = element_text(face = "bold", size = 9),
      plot.title = element_text(size = 11, face = "bold"),
      plot.subtitle = element_text(size = 9, colour = "grey40"),
      axis.text.x = element_text(angle = 45, hjust = 1, size = 7)
    )
}

plot_simulated_LQ_allregions(LQ_with_sim_CIs, "fabricated metal")
plot_simulated_LQ_allregions(LQ_with_sim_CIs, "computer programming")
plot_simulated_LQ_allregions(LQ_with_sim_CIs, "pharmaceutical")


# Multi-year comparison: dodged error bars for selected years, all regions
# Dan note: I think this might mislead - different years are maybe not comparable
# The error bars are based on simulating for one year, so separating places in that year
# Not separating years...
plot_simulated_LQ_multiyear <- function(data, sector_pattern) {

  plot_data <- data %>%
    filter(grepl(sector_pattern, SIC07_description, ignore.case = TRUE) |
           SIC07_description == sector_pattern)

  sector_name <- unique(plot_data$SIC07_description)[1]

  ggplot(plot_data, aes(y = fct_reorder(Region_name, LQ_central),
                        x = LQ_central, colour = factor(year))) +
    geom_point(position = position_dodge(width = 0.4), size = 2) +
    geom_errorbarh(aes(xmin = LQ_p025, xmax = LQ_p975),
                   position = position_dodge(width = 0.4), height = 0.3) +
    geom_vline(xintercept = 1, linetype = 'dashed', colour = 'grey50', alpha = 0.5) +
    scale_colour_brewer(palette = "Set1", name = "Year") +
    labs(
      title = paste0("Location Quotient with simulated 95% CI: ", sector_name),
      subtitle = paste0("Years: ", paste(sort(unique(plot_data$year)), collapse = ", "),
                        " | ", n_sims, " MC draws"),
      x = "Location Quotient",
      y = "",
      caption = "Error bars: 2.5th-97.5th percentile from simulation. Dashed line = LQ of 1."
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 11, face = "bold"),
      plot.subtitle = element_text(size = 9, colour = "grey40"),
      legend.position = "bottom"
    )
}

# Plot multi-year comparison using the selected years simulation
plot_simulated_LQ_multiyear(LQ_selected_years, "fabricated metal")
plot_simulated_LQ_multiyear(LQ_selected_years, "computer programming")
plot_simulated_LQ_multiyear(LQ_selected_years, "telecom")
plot_simulated_LQ_multiyear(LQ_selected_years, "pharmaceutical")
plot_simulated_LQ_multiyear(LQ_selected_years, "manufacture of furniture")

# Save each sector's multi-year LQ plot
# map(unique(LQ_selected_years$SIC07_description), ~{
#   tryCatch({
#     safe_name <- gsub('[[:punct:]]| ', '', .)
#     p <- plot_simulated_LQ_multiyear(LQ_selected_years, .)
#     ggsave(
#       filename = paste0('docs/miscimages/LQ_errorbars_SIC2s_twoyear/', safe_name, '.png'),
#       plot = p, width = 10, height = 10
#     )
#   }, error = function(e) cat("Failed for:", ., "\n", e$message, "\n"))
# })




# DAN CHECKS ON THAT CLAUDE OUTPUT----

## Checking the central LQ values look correct----

# Already calculated that
# And yes, they're all looking fine
itl1.cp.centralestLQ %>% 
  # filter(qg('computer prog',SIC07_description), year == max(year)) %>% 
  filter(qg('pharmaceutical',SIC07_description), year == max(year)) %>% 
  # filter(qg('fabricated',SIC07_description), year == max(year)) %>% 
  arrange(-LQ) %>% 
  select(Region_name,LQ)




# INCLUDING THE EXTRA UNCERTAINTY IN LINEAR SLOPES----

# Plan: test ways to add in the extra uncertainty to see how it changes 
# Which sector/place combos still stand out
# First easy option: using the new CIs as draws to simulate again
# Get many slopes
# Get range of new CIs from all those slopes

# Brief bit of dan code
write_csv(
  data.frame(
    SIC07_description = unique(LQ_selected_years$SIC07_description),
    SIC07_description_shortened = NA
  ),
  'data/regxind_siclookup.csv'
  )

# After CC has added some abbreviations:
# read_csv('data/regxind_siclookup.csv') %>% View


## Focal LQ comparison grid with diagonal split: 90% and 95% CIs ----
# For a focal ITL1, compare its LQ to every other ITL1 for each sector in a
# given year, using the z-test on the LQ difference with MC-derived SDs.
# Diagonal split: bottom-left = 90%, top-right = 95%.
# Y-axis coloured by whether focal region's LQ CI crosses 1 (national average).

# Load sector name lookup
sic_lookup <- read_csv('data/regxind_siclookup.csv')

plot_focal_LQ_split <- function(lq_data, focal_region, plot_year = NULL,
                                ci_levels = c(90, 95),
                                top_bottom_n = NULL) {

  # Default to latest year
  if (is.null(plot_year)) plot_year <- max(lq_data$year)

  # Filter to chosen year and join shortened names
  yr_data <- lq_data %>%
    filter(year == plot_year) %>%
    left_join(sic_lookup, by = 'SIC07_description')

  # Compute significance for a given CI level
  compute_sig <- function(data, focal_reg, ci_level) {
    ci_z <- qnorm(1 - (1 - ci_level / 100) / 2)

    focal <- data %>% filter(Region_name == focal_reg)
    others <- data %>% filter(Region_name != focal_reg)

    others %>%
      inner_join(
        focal %>% select(SIC07_description, SIC07_description_shortened,
                         focal_LQ = LQ_central, focal_sd = LQ_sd),
        by = c('SIC07_description', 'SIC07_description_shortened')
      ) %>%
      mutate(
        z = (focal_LQ - LQ_central) / sqrt(focal_sd^2 + LQ_sd^2),
        sig = case_when(
          z >  ci_z ~  1L,
          z < -ci_z ~ -1L,
          TRUE ~ 0L
        )
      ) %>%
      select(SIC07_description, SIC07_description_shortened, Region_name, sig)
  }

  # Build cell data for a given subset of the year data
  build_cells <- function(data) {
    sig_lo <- compute_sig(data, focal_region, ci_levels[1]) %>% rename(sig_lo = sig)
    sig_hi <- compute_sig(data, focal_region, ci_levels[2]) %>% rename(sig_hi = sig)
    sig_lo %>%
      inner_join(sig_hi, by = c('SIC07_description', 'SIC07_description_shortened', 'Region_name'))
  }

  # Build y-axis labels: LQ value and CI, coloured by whether CI crosses 1
  build_y_labels <- function(data) {
    data %>%
      filter(Region_name == focal_region) %>%
      mutate(
        label = paste0(SIC07_description_shortened, " (LQ: ",
                       round(LQ_central, 2), " [",
                       round(LQ_p025, 2), ", ", round(LQ_p975, 2), "])"),
        crosses_one = LQ_p025 <= 1 & LQ_p975 >= 1,
        colour = case_when(
          !crosses_one & LQ_central > 1 ~ "#28da28",
          crosses_one  & LQ_central > 1 ~ "#96c493",
          !crosses_one & LQ_central < 1 ~ "red",
          crosses_one  & LQ_central < 1 ~ "#ffcccc"
        )
      ) %>%
      arrange(SIC07_description_shortened) %>%
      select(SIC07_description_shortened, label, colour)
  }

  # Build one triangle panel
  build_panel <- function(cell_data, y_labels, regions, sectors,
                          panel_title = "", show_x_axis = TRUE) {

    cell_data <- cell_data %>%
      mutate(
        x = match(Region_name, regions),
        y = match(SIC07_description_shortened, sectors)
      )

    tri_lo <- cell_data %>%
      mutate(tri_id = paste(SIC07_description_shortened, Region_name, "lo", sep = "::")) %>%
      reframe(
        tri_id = rep(tri_id, each = 3),
        sig = rep(sig_lo, each = 3),
        px = c(rbind(x - 0.5, x + 0.5, x - 0.5)),
        py = c(rbind(y - 0.5, y - 0.5, y + 0.5))
      )

    tri_hi <- cell_data %>%
      mutate(tri_id = paste(SIC07_description_shortened, Region_name, "hi", sep = "::")) %>%
      reframe(
        tri_id = rep(tri_id, each = 3),
        sig = rep(sig_hi, each = 3),
        px = c(rbind(x + 0.5, x - 0.5, x + 0.5)),
        py = c(rbind(y + 0.5, y + 0.5, y - 0.5))
      )

    plot_polys <- bind_rows(tri_lo, tri_hi) %>%
      mutate(
        sig_label = factor(sig, levels = c(-1, 0, 1),
                           labels = c("Lower", "Not separable", "Higher"))
      )

    label_text <- y_labels$label
    label_colours <- y_labels$colour

    p <- ggplot(plot_polys, aes(x = px, y = py, group = tri_id, fill = sig_label)) +
      geom_polygon(colour = "white", linewidth = 0.2) +
      scale_fill_manual(
        values = c("Lower" = "#d73027", "Not separable" = "grey90", "Higher" = "#1a9850"),
        name = "",
        drop = FALSE
      ) +
      scale_x_continuous(breaks = seq_along(regions), labels = regions, expand = c(0, 0)) +
      scale_y_continuous(breaks = seq_along(sectors), labels = label_text, expand = c(0, 0)) +
      labs(title = panel_title, x = "", y = "") +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1, size = 7),
        axis.text.y = element_text(size = 5.5, colour = label_colours),
        plot.title = element_text(size = 10, face = "bold"),
        legend.position = "bottom"
      ) +
      coord_fixed()

    if (!show_x_axis) {
      p <- p + theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())
    }

    p
  }

  # --- Assemble ---
  regions <- sort(unique(yr_data %>%
                           filter(Region_name != focal_region) %>%
                           pull(Region_name)))

  if (!is.null(top_bottom_n)) {

    # Rank sectors by count of 95% significant positive/negative differences
    sig_95 <- compute_sig(yr_data, focal_region, 95)

    sig_counts <- sig_95 %>%
      group_by(SIC07_description_shortened) %>%
      summarise(
        n_higher = sum(sig == 1L, na.rm = TRUE),
        n_lower  = sum(sig == -1L, na.rm = TRUE),
        .groups = 'drop'
      )

    top_higher <- sig_counts %>%
      slice_max(n_higher, n = top_bottom_n, with_ties = FALSE) %>%
      pull(SIC07_description_shortened) %>%
      sort()

    top_lower <- sig_counts %>%
      slice_max(n_lower, n = top_bottom_n, with_ties = FALSE) %>%
      pull(SIC07_description_shortened) %>%
      sort()

    # Build each subset
    data_higher <- yr_data %>% filter(SIC07_description_shortened %in% top_higher)
    data_lower  <- yr_data %>% filter(SIC07_description_shortened %in% top_lower)

    cells_higher <- build_cells(data_higher)
    cells_lower  <- build_cells(data_lower)

    y_higher <- build_y_labels(data_higher)
    y_lower  <- build_y_labels(data_lower)

    p_top <- build_panel(cells_higher, y_higher, regions, top_higher,
                         paste0("Most often higher (top ", top_bottom_n, ")"),
                         show_x_axis = FALSE)
    p_bot <- build_panel(cells_lower, y_lower, regions, top_lower,
                         paste0("Most often lower (top ", top_bottom_n, ")"),
                         show_x_axis = TRUE) +
      guides(fill = "none")

    p_top / p_bot +
      plot_layout(guides = "collect", heights = c(1, 1)) &
      theme(legend.position = "bottom") &
      plot_annotation(
        title = paste0("LQ comparisons: ", focal_region, " (", plot_year, ")"),
        subtitle = paste0("Sectors ranked by count of 95%-significant differences.\n",
                          "Bottom-left = ", ci_levels[1], "% CI, top-right = ", ci_levels[2],
                          "% CI. Y-axis coloured by whether LQ CI crosses 1."),
        theme = theme(
          plot.title = element_text(size = 12, face = "bold"),
          plot.subtitle = element_text(size = 9, colour = "grey40")
        )
      )

  } else {
    # All sectors in one panel
    cell_data <- build_cells(yr_data)
    focal_info <- build_y_labels(yr_data)
    sectors <- sort(unique(cell_data$SIC07_description_shortened))

    build_panel(cell_data, focal_info, regions, sectors) +
      labs(
        title = paste0("LQ comparisons: ", focal_region, " (", plot_year, ")"),
        subtitle = paste0("Bottom-left = ", ci_levels[1], "% CI, top-right = ", ci_levels[2],
                          "% CI. Z-test on LQ difference using MC-derived SDs.\n",
                          "Y-axis: focal LQ [95% CI], coloured by whether CI crosses 1.")
      ) +
      theme(
        plot.title = element_text(size = 11, face = "bold"),
        plot.subtitle = element_text(size = 9, colour = "grey40")
      )
  }
}

# Examples — all sectors
plot_focal_LQ_split(LQ_with_sim_CIs, "Yorkshire and The Humber")
plot_focal_LQ_split(LQ_with_sim_CIs, "London")
plot_focal_LQ_split(LQ_with_sim_CIs, "South West")

# Examples — top/bottom by significant difference count
plot_focal_LQ_split(LQ_with_sim_CIs, "Yorkshire and The Humber", top_bottom_n = 15)
plot_focal_LQ_split(LQ_with_sim_CIs, "Yorkshire and The Humber", top_bottom_n = 15, plot_year = 2023)
plot_focal_LQ_split(LQ_with_sim_CIs, "London", top_bottom_n = 15)
plot_focal_LQ_split(LQ_with_sim_CIs, "South East", top_bottom_n = 15)
plot_focal_LQ_split(LQ_with_sim_CIs, "North West", top_bottom_n = 15)


## CLAUDE OUTPUT:

## Monte Carlo simulation of slopes with measurement uncertainty ----

# APPROACH:
# For each MC iteration, draw plausible GVA values from log-normal distributions
# parameterised by the observed value and SE (same approach as LQ simulation).
# Then fit log(sim_value) ~ year for each sector/region group and collect slopes.
# The distribution of slopes across iterations captures the additional uncertainty
# from measurement error on top of the OLS trend-fitting uncertainty.
#
# Output: a summary dataframe with median slope and simulated CIs,
# plus the raw draws for flexible quantile computation (adjustable CI levels).

# Reload data (in case running from here)
itl1.cv.linked = read_csv('data/itl1_cv_withestimatederrorratefromABS.csv')

# Also get the vanilla OLS slopes for comparison
slopes_ols <- get_slope_and_se_safely(
  itl1.cv.linked,
  Region_name, SIC07_description,
  y = log(value),
  x = year
)

# MC simulation function for slopes (parallelised via furrr)
# rho: AR(1) correlation for measurement errors across years (0 = independent draws, default)
#   Higher rho means errors are more correlated year-to-year (e.g. same firms in ABS sample),
#   which narrows the slope envelope because correlated errors shift the series up/down
#   rather than tilting it. Uses Gaussian copula so marginals stay log-normal per year.
simulate_slopes <- function(data, n_sims = 500, seed = 42, rho = 0) {

  # Pre-compute log-normal parameters (same as LQ simulation)
  sim_params <- data %>%
    mutate(
      has_se = !is.na(SE) & SE > 0 & value > 0,
      lnorm_sigma2 = ifelse(has_se, log(1 + (SE / value)^2), NA),
      lnorm_sigma  = ifelse(has_se, sqrt(lnorm_sigma2), NA),
      lnorm_mu     = ifelse(has_se, log(value) - lnorm_sigma2 / 2, NA)
    )

  # Pre-split by group so each worker can draw correlated sequences per group
  # Must be sorted by year within each group for AR(1) to correlate consecutive years
  groups <- sim_params %>%
    arrange(Region_name, SIC07_description, year) %>%
    group_by(Region_name, SIC07_description) %>%
    group_split()

  group_keys <- sim_params %>%
    group_by(Region_name, SIC07_description) %>%
    group_keys()

  # Run simulations in parallel — furrr handles reproducible RNG via L'Ecuyer-CMRG streams
  if (rho == 0) {
    # Fast vectorised path: independent draws across entire dataset
    future_map_dfr(1:n_sims, function(i) {
      sim_data <- sim_params %>%
        mutate(
          sim_value = ifelse(
            has_se,
            rlnorm(n(), meanlog = lnorm_mu, sdlog = lnorm_sigma),
            value
          )
        )

      get_slope_and_se_safely(
        sim_data,
        Region_name, SIC07_description,
        y = log(sim_value),
        x = year
      ) %>%
        mutate(sim_id = i)
    }, .options = furrr_options(seed = seed), .progress = TRUE)

  } else {
    # Correlated draws: need per-group AR(1) sequences
    future_map_dfr(1:n_sims, function(i) {

      # Generate correlated z-values per group, then reassemble
      sim_data <- map_dfr(groups, function(grp) {
        n_years <- nrow(grp)

        if (any(grp$has_se)) {
          z <- numeric(n_years)
          z[1] <- rnorm(1)
          for (t in 2:n_years) {
            z[t] <- rho * z[t - 1] + sqrt(1 - rho^2) * rnorm(1)
          }
          grp %>%
            mutate(
              sim_value = ifelse(
                has_se,
                qlnorm(pnorm(z), meanlog = lnorm_mu, sdlog = lnorm_sigma),
                value
              )
            )
        } else {
          grp %>% mutate(sim_value = value)
        }
      })

      get_slope_and_se_safely(
        sim_data,
        Region_name, SIC07_description,
        y = log(sim_value),
        x = year
      ) %>%
        mutate(sim_id = i)
    }, .options = furrr_options(seed = seed), .progress = TRUE)
  }
}

# Run the simulation
n_sims_slopes <- 500
slopes_mc_raw <- simulate_slopes(itl1.cv.linked, n_sims = n_sims_slopes)

# AR(1) version correlating timepoints from the draws
slopes_mc_raw <- simulate_slopes(itl1.cv.linked, n_sims = n_sims_slopes, rho = 0.7)

# Summarise: SD of slopes across MC draws captures measurement uncertainty
slopes_mc_summary <- slopes_mc_raw %>%
  group_by(Region_name, SIC07_description) %>%
  summarise(
    slope_median = median(slope, na.rm = TRUE),
    slope_sd     = sd(slope, na.rm = TRUE),
    .groups = 'drop'
  )

# Merge OLS and MC results, then combine uncertainties in quadrature:
# se_combined = sqrt(se_ols^2 + slope_sd^2)
# OLS regression uncertainty + MC measurement uncertainty (independent sources)
slopes_combined <- slopes_ols %>%
  rename(slope_ols = slope, se_ols = se) %>%
  left_join(slopes_mc_summary, by = c('Region_name', 'SIC07_description')) %>%
  mutate(
    se_combined = sqrt(se_ols^2 + slope_sd^2)
  )

# Save raw draws for flexible quantile computation in viewers
write_csv(slopes_mc_raw, 'data/slopes_mc_raw_draws.csv')
write_csv(slopes_combined, 'data/slopes_ols_vs_mc_combined.csv')


## Compare OLS vs MC slope CIs ----

# Create a slope+se dataframe from the MC results that plugs into slopeDiffGrid.
# Uses the combined SE (OLS + measurement uncertainty in quadrature).
slopes_mc_for_grid <- slopes_combined %>%
  transmute(
    Region_name,
    SIC07_description,
    slope = slope_ols,
    se = se_combined
  )

# Quick comparison: how much wider are combined CIs vs OLS-only CIs?
ci_comparison <- slopes_combined %>%
  mutate(
    ols_ci_width = se_ols * 2 * 1.96,
    mc_ci_width  = se_combined * 2 * 1.96,
    ci_ratio = mc_ci_width / ols_ci_width
  )

cat("Median CI width ratio (MC / OLS):", median(ci_comparison$ci_ratio, na.rm = TRUE), "\n")
cat("Mean CI width ratio (MC / OLS):", mean(ci_comparison$ci_ratio, na.rm = TRUE), "\n")


## Forest plot: OLS vs MC CIs for a sector across regions ----

plot_slope_forest <- function(combined_data, sector_pattern) {

  plot_data <- combined_data %>%
    filter(grepl(sector_pattern, SIC07_description, ignore.case = TRUE))

  sector_name <- unique(plot_data$SIC07_description)[1]

  # Convert everything to annualised % change: (exp(slope) - 1) * 100
  to_pct <- function(x) (exp(x) - 1) * 100

  plot_data <- plot_data %>%
    mutate(
      slope_pct      = to_pct(slope_ols),
      ols_min95      = to_pct(slope_ols - se_ols * 1.96),
      ols_max95      = to_pct(slope_ols + se_ols * 1.96),
      combined_min95 = to_pct(slope_ols - se_combined * 1.96),
      combined_max95 = to_pct(slope_ols + se_combined * 1.96)
    )

  ggplot(plot_data, aes(y = fct_reorder(Region_name, slope_pct))) +
    geom_vline(xintercept = 0, linetype = 'dashed', colour = 'grey50') +
    # Combined CI (wider, lighter)
    geom_errorbarh(aes(xmin = combined_min95, xmax = combined_max95),
                   height = 0.3, colour = 'steelblue', alpha = 0.4, linewidth = 2) +
    # OLS CI (narrower, darker)
    geom_errorbarh(aes(xmin = ols_min95, xmax = ols_max95),
                   height = 0.3, colour = 'steelblue', linewidth = 0.7) +
    geom_point(aes(x = slope_pct), size = 2) +
    labs(
      title = paste0("Growth rate slopes: ", sector_name),
      subtitle = "Thin bars = OLS 95% CI. Wide bars = combined (OLS + measurement uncertainty in quadrature)",
      x = "Annualised growth rate (%)",
      y = "",
      caption = paste0(n_sims_slopes, " MC draws using log-normal on GVA with ABS standard errors")
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 11, face = "bold"),
      plot.subtitle = element_text(size = 9, colour = "grey40")
    )
}

# Example plots
plot_slope_forest(slopes_combined, "fabricated metal")
plot_slope_forest(slopes_combined, "computer programming")
plot_slope_forest(slopes_combined, "construction of buildings")
plot_slope_forest(slopes_combined, "pharmaceutical")
# Interesting one for how much difference it makes for London
plot_slope_forest(slopes_combined, "scientific research")





## Headline summary: % of significant pairwise differences, OLS vs MC ----

# Count how many pairwise slope comparisons are significant (z-test on slope difference)
# under OLS vs MC, for each sector (comparing across regions)
count_sig_pairs <- function(slope_df, ci_level = 95) {

  ci_z <- qnorm(1 - (1 - ci_level/100) / 2)

  # All pairwise region comparisons per sector
  sectors <- unique(slope_df$SIC07_description)

  map_dfr(sectors, function(sec) {
    sec_data <- slope_df %>% filter(SIC07_description == sec)

    combos <- expand.grid(
      r1 = seq_len(nrow(sec_data)),
      r2 = seq_len(nrow(sec_data))
    ) %>% filter(r1 < r2)

    if(nrow(combos) == 0) return(tibble())

    n_pairs <- nrow(combos)
    z_scores <- abs(
      (sec_data$slope[combos$r1] - sec_data$slope[combos$r2]) /
      sqrt(sec_data$se[combos$r1]^2 + sec_data$se[combos$r2]^2)
    )
    n_sig <- sum(z_scores > ci_z, na.rm = TRUE)

    tibble(
      SIC07_description = sec,
      n_pairs = n_pairs,
      n_sig = n_sig,
      pct_sig = (n_sig / n_pairs) * 100
    )
  })
}

sig_counts_ols <- count_sig_pairs(slopes_ols %>% rename(SIC07_description = SIC07_description)) %>%
  rename(n_sig_ols = n_sig, pct_sig_ols = pct_sig)

sig_counts_mc <- count_sig_pairs(slopes_mc_for_grid) %>%
  rename(n_sig_mc = n_sig, pct_sig_mc = pct_sig)

sig_comparison <- sig_counts_ols %>%
  left_join(sig_counts_mc %>% select(SIC07_description, n_sig_mc, pct_sig_mc),
            by = 'SIC07_description') %>%
  mutate(
    pct_lost = pct_sig_ols - pct_sig_mc,
    ratio = pct_sig_mc / pct_sig_ols
  ) %>%
  arrange(-pct_lost)

cat("\nOverall: OLS sig pairs =", sum(sig_comparison$n_sig_ols, na.rm = TRUE),
    "/ MC sig pairs =", sum(sig_comparison$n_sig_mc, na.rm = TRUE), "\n")
cat("Reduction:", round((1 - sum(sig_comparison$n_sig_mc, na.rm = TRUE) /
                           sum(sig_comparison$n_sig_ols, na.rm = TRUE)) * 100, 1), "%\n")

# Plot: sectors ranked by how much significance they lose
ggplot(
  sig_comparison %>% filter(!is.na(pct_lost)),
  aes(y = fct_reorder(SIC07_description, pct_lost), x = pct_lost)
) +
  geom_col(fill = 'steelblue', alpha = 0.7) +
  geom_vline(xintercept = 0, linetype = 'dashed') +
  labs(
    title = "Loss of significant pairwise slope differences after adding measurement uncertainty",
    subtitle = "Percentage point drop in 'significant at 95%' cross-region comparisons per sector",
    x = "Percentage point reduction in significant comparisons",
    y = ""
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 11, face = "bold"),
    plot.subtitle = element_text(size = 9, colour = "grey40"),
    axis.text.y = element_text(size = 6)
  )


## Focal ITL1 comparison grid: OLS vs combined CIs ----

# For a focal ITL1, compare its growth slope to every other ITL1 for each sector.
# Returns a heatmap: rows = sectors, columns = other ITL1s.
# Cells show whether the focal place's slope is significantly higher (+1),
# lower (-1), or not distinguishable (0) from each comparator.
# Side-by-side panels: left = vanilla OLS, right = combined (OLS + measurement uncertainty).

# Add in shortened sector names for slopes_combined
slopes_combined = slopes_combined %>% 
  left_join(
    read_csv('data/regxind_siclookup.csv'),
    by = 'SIC07_description'
  )


plot_focal_comparison <- function(combined_data, focal_region, ci_level = 95) {

  ci_z <- qnorm(1 - (1 - ci_level / 100) / 2)

  ci_data <- combined_data %>% ungroup()

  focal <- ci_data %>% filter(Region_name == focal_region)
  others <- ci_data %>% filter(Region_name != focal_region)

  # For each sector, compare focal to every other region using z-test on slope difference
  comparisons <- others %>%
    inner_join(
      focal %>% select(SIC07_description,
                       focal_slope = slope_ols,
                       focal_se_ols = se_ols,
                       focal_se_combined = se_combined),
      by = 'SIC07_description'
    ) %>%
    mutate(
      # Proper z-test: z = (slope_A - slope_B) / sqrt(se_A^2 + se_B^2)
      z_ols = (focal_slope - slope_ols) / sqrt(focal_se_ols^2 + se_ols^2),
      ols_sig = case_when(
        z_ols >  ci_z ~  1L,
        z_ols < -ci_z ~ -1L,
        TRUE ~ 0L
      ),
      z_combined = (focal_slope - slope_ols) / sqrt(focal_se_combined^2 + se_combined^2),
      combined_sig = case_when(
        z_combined >  ci_z ~  1L,
        z_combined < -ci_z ~ -1L,
        TRUE ~ 0L
      )
    )

  # Reshape for faceted plot
  plot_data <- bind_rows(
    comparisons %>%
      select(SIC07_description, SIC07_description_shortened, Region_name, sig = ols_sig) %>%
      mutate(method = "OLS only"),
    comparisons %>%
      select(SIC07_description, SIC07_description_shortened, Region_name, sig = combined_sig) %>%
      mutate(method = "OLS + measurement uncertainty")
  ) %>%
    mutate(
      method = factor(method, levels = c("OLS only", "OLS + measurement uncertainty")),
      sig_label = factor(sig, levels = c(-1, 0, 1),
                         labels = c("Focal lower", "Not distinguishable", "Focal higher"))
    )

  ggplot(plot_data, aes(x = Region_name, y = SIC07_description_shortened, fill = sig_label)) +
    geom_tile(colour = "white", linewidth = 0.3) +
    facet_wrap(~method) +
    scale_fill_manual(
      values = c("Focal lower" = "#d73027", "Not distinguishable" = "grey90", "Focal higher" = "#1a9850"),
      name = ""
    ) +
    labs(
      title = paste0("Growth slope comparisons from ", focal_region, "'s perspective"),
      subtitle = paste0("Each cell: is ", focal_region, "'s sector slope significantly different from comparator? (", ci_level, "% CI)"),
      x = "", y = ""
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 7),
      axis.text.y = element_text(size = 6),
      plot.title = element_text(size = 11, face = "bold"),
      plot.subtitle = element_text(size = 9, colour = "grey40"),
      strip.text = element_text(size = 10, face = "bold"),
      legend.position = "bottom"
    )
}

# Example: South West's perspective
plot_focal_comparison(slopes_combined, "South West")
plot_focal_comparison(slopes_combined, "Yorkshire and The Humber")
plot_focal_comparison(slopes_combined, "London")


## Focal comparison grid with diagonal split: 90% and 95% CIs ----

# Each cell is split diagonally: bottom-left triangle = 90% CI result,
# top-right triangle = 95% CI result. Lets you see both CI levels at once.
# Takes two combined_data frames (one run at each CI level) or a single one
# and computes both internally.

plot_focal_comparison_split <- function(combined_data, focal_region,
                                        ci_levels = c(90, 95)) {

  # Helper: compute significance for a given CI level and SE column using z-test
  compute_sig <- function(cdata, focal_reg, ci_level, se_col) {
    ci_z <- qnorm(1 - (1 - ci_level / 100) / 2)

    ci_data <- cdata %>% ungroup()

    focal <- ci_data %>% filter(Region_name == focal_reg)
    others <- ci_data %>% filter(Region_name != focal_reg)

    others %>%
      inner_join(
        focal %>% select(SIC07_description,
                         focal_slope = slope_ols,
                         focal_se = !!sym(se_col)),
        by = 'SIC07_description'
      ) %>%
      mutate(
        z = (focal_slope - slope_ols) / sqrt(focal_se^2 + .data[[se_col]]^2),
        sig = case_when(
          z >  ci_z ~  1L,
          z < -ci_z ~ -1L,
          TRUE ~ 0L
        )
      ) %>%
      select(SIC07_description, SIC07_description_shortened, Region_name, sig)
  }

  # Compute significance for both methods at both CI levels
  build_cell_data <- function(se_col) {
    sig_lo <- compute_sig(combined_data, focal_region, ci_levels[1], se_col) %>%
      rename(sig_lo = sig)
    sig_hi <- compute_sig(combined_data, focal_region, ci_levels[2], se_col) %>%
      rename(sig_hi = sig)
    sig_lo %>%
      inner_join(sig_hi, by = c('SIC07_description', 'SIC07_description_shortened', 'Region_name'))
  }

  cell_ols <- build_cell_data("se_ols") %>% mutate(method = "OLS only")
  cell_combined <- build_cell_data("se_combined") %>% mutate(method = "OLS + extra")

  cell_data <- bind_rows(cell_ols, cell_combined) %>%
    mutate(method = factor(method, levels = c("OLS only", "OLS + extra")))

  # Convert axes to numeric positions for polygon coordinates
  regions <- sort(unique(cell_data$Region_name))
  sectors <- sort(unique(cell_data$SIC07_description_shortened))

  cell_data <- cell_data %>%
    mutate(
      x = match(Region_name, regions),
      y = match(SIC07_description_shortened, sectors)
    )

  # Build triangle polygons for each cell
  # Bottom-left triangle: (x-0.5, y-0.5), (x+0.5, y-0.5), (x-0.5, y+0.5)
  # Top-right triangle:   (x+0.5, y+0.5), (x-0.5, y+0.5), (x+0.5, y-0.5)
  # Each triangle needs a unique group ID (method + cell + lo/hi)
  tri_lo <- cell_data %>%
    mutate(
      tri_id = paste(method, SIC07_description_shortened, Region_name, "lo", sep = "::")
    ) %>%
    reframe(
      tri_id = rep(tri_id, each = 3),
      method = rep(method, each = 3),
      sig = rep(sig_lo, each = 3),
      px = c(rbind(x - 0.5, x + 0.5, x - 0.5)),
      py = c(rbind(y - 0.5, y - 0.5, y + 0.5))
    )

  tri_hi <- cell_data %>%
    mutate(
      tri_id = paste(method, SIC07_description_shortened, Region_name, "hi", sep = "::")
    ) %>%
    reframe(
      tri_id = rep(tri_id, each = 3),
      method = rep(method, each = 3),
      sig = rep(sig_hi, each = 3),
      px = c(rbind(x + 0.5, x - 0.5, x + 0.5)),
      py = c(rbind(y + 0.5, y + 0.5, y - 0.5))
    )

  plot_polys <- bind_rows(tri_lo, tri_hi) %>%
    mutate(
      sig_label = factor(sig, levels = c(-1, 0, 1),
                         labels = c("Lower", "Not separable", "Higher"))
    )

  ggplot(plot_polys, aes(x = px, y = py, group = tri_id, fill = sig_label)) +
    geom_polygon(colour = "white", linewidth = 0.2) +
    facet_wrap(~method) +
    scale_fill_manual(
      values = c("Lower" = "#d73027", "Not separable" = "grey90", "Higher" = "#1a9850"),
      name = ""
    ) +
    scale_x_continuous(breaks = seq_along(regions), labels = regions, expand = c(0, 0)) +
    scale_y_continuous(breaks = seq_along(sectors), labels = sectors, expand = c(0, 0)) +
    labs(
      title = paste0("Growth slope comparisons:\n", focal_region),
      subtitle = paste0("Bottom-left triangle = ", ci_levels[1],
                        "% CI, top-right triangle = ", ci_levels[2], "% CI"),
      x = "", y = ""
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 7),
      axis.text.y = element_text(size = 6),
      plot.title = element_text(size = 11, face = "bold"),
      plot.subtitle = element_text(size = 9, colour = "grey40"),
      strip.text = element_text(size = 10, face = "bold"),
      legend.position = "bottom"
    ) +
    coord_fixed()
}

# Example
plot_focal_comparison_split(slopes_combined, "South West")
plot_focal_comparison_split(slopes_combined %>% filter(!qg('membership|other personal',SIC07_description)), "Yorkshire and The Humber")
plot_focal_comparison_split(slopes_combined %>% filter(!qg('membership|other personal',SIC07_description)), "North West")
plot_focal_comparison_split(slopes_combined %>% filter(!qg('membership|other personal',SIC07_description)), "London")


## Focal comparison split with coloured y-axis (patchwork) ----
# Like plot_focal_comparison_split but with y-axis labels showing the focal
# region's annualised growth rate and CI, coloured by whether the CI crosses zero.
# Uses patchwork instead of faceting so each panel can have its own axis colours.
# Colours: dark green/red = CI doesn't cross zero, light green/red = CI crosses zero.

# Dan: This is below too, but we'll use here to get top bottom 10
se_inflation <- slopes_combined %>%
  filter(!qg('membership|other personal',SIC07_description)) %>% 
  ungroup() %>%
  filter(!is.na(se_ols) & se_ols > 0 & !is.na(se_combined)) %>%
  mutate(
    se_ratio = se_combined / se_ols,
    slope_pct = round((exp(slope_ols) - 1) * 100, 1)
  )


plot_focal_split_coloured <- function(combined_data, focal_region,
                                      ci_levels = c(90, 95),
                                      top_bottom_n = NULL,
                                      se_inflation_data = NULL) {

  to_pct <- function(x) round((exp(x) - 1) * 100, 1)

  # Helper: compute significance for a given CI level and SE column using z-test
  compute_sig <- function(cdata, focal_reg, ci_level, se_col) {
    ci_z <- qnorm(1 - (1 - ci_level / 100) / 2)
    ci_data <- cdata %>% ungroup()
    focal <- ci_data %>% filter(Region_name == focal_reg)
    others <- ci_data %>% filter(Region_name != focal_reg)

    others %>%
      inner_join(
        focal %>% select(SIC07_description,
                         focal_slope = slope_ols,
                         focal_se = !!sym(se_col)),
        by = 'SIC07_description'
      ) %>%
      mutate(
        z = (focal_slope - slope_ols) / sqrt(focal_se^2 + .data[[se_col]]^2),
        sig = case_when(
          z >  ci_z ~  1L,
          z < -ci_z ~ -1L,
          TRUE ~ 0L
        )
      ) %>%
      select(SIC07_description, SIC07_description_shortened, Region_name, sig)
  }

  # Build cell data for one method
  build_cell_data <- function(se_col) {
    sig_lo <- compute_sig(combined_data, focal_region, ci_levels[1], se_col) %>%
      rename(sig_lo = sig)
    sig_hi <- compute_sig(combined_data, focal_region, ci_levels[2], se_col) %>%
      rename(sig_hi = sig)
    sig_lo %>%
      inner_join(sig_hi, by = c('SIC07_description', 'SIC07_description_shortened', 'Region_name'))
  }

  # Build the focal region's slope info for y-axis labels
  build_y_labels <- function(se_col, ci_level = 95) {
    ci_z <- qnorm(1 - (1 - ci_level / 100) / 2)
    focal_data <- combined_data %>%
      ungroup() %>%
      filter(Region_name == focal_region) %>%
      mutate(
        slope_pct = to_pct(slope_ols),
        ci_lo_pct = to_pct(slope_ols - .data[[se_col]] * ci_z),
        ci_hi_pct = to_pct(slope_ols + .data[[se_col]] * ci_z),
        crosses_zero = ci_lo_pct * ci_hi_pct < 0,
        label = paste0(SIC07_description_shortened, " (",
                       slope_pct, "% CI: ", ci_lo_pct, "%, ", ci_hi_pct, "%)"),
        colour = case_when(
          !crosses_zero & slope_ols > 0 ~ "#28da28",
          crosses_zero  & slope_ols > 0 ~ "#96c493",
          !crosses_zero & slope_ols < 0 ~ "red",
          crosses_zero  & slope_ols < 0 ~ "#ffcccc"
        )
      ) %>%
      arrange(SIC07_description_shortened) %>%
      select(SIC07_description_shortened, label, colour)

    focal_data
  }

  # Build one panel's triangle plot
  # y_side: "left" or "right" controls which side the y-axis labels appear
  # show_x_axis: FALSE to hide x-axis labels (for stacked panels)
  build_panel <- function(cell_data, y_labels, regions, sectors,
                          panel_title, show_y_axis = TRUE, y_side = "left",
                          show_x_axis = TRUE) {

    cell_data <- cell_data %>%
      mutate(
        x = match(Region_name, regions),
        y = match(SIC07_description_shortened, sectors)
      )

    tri_lo <- cell_data %>%
      mutate(tri_id = paste(SIC07_description_shortened, Region_name, "lo", sep = "::")) %>%
      reframe(
        tri_id = rep(tri_id, each = 3),
        sig = rep(sig_lo, each = 3),
        px = c(rbind(x - 0.5, x + 0.5, x - 0.5)),
        py = c(rbind(y - 0.5, y - 0.5, y + 0.5))
      )

    tri_hi <- cell_data %>%
      mutate(tri_id = paste(SIC07_description_shortened, Region_name, "hi", sep = "::")) %>%
      reframe(
        tri_id = rep(tri_id, each = 3),
        sig = rep(sig_hi, each = 3),
        px = c(rbind(x + 0.5, x - 0.5, x + 0.5)),
        py = c(rbind(y + 0.5, y + 0.5, y - 0.5))
      )

    plot_polys <- bind_rows(tri_lo, tri_hi) %>%
      mutate(
        sig_label = factor(sig, levels = c(-1, 0, 1),
                           labels = c("Lower", "Not separable", "Higher"))
      )

    # Map sector positions to coloured labels
    label_text <- y_labels$label
    label_colours <- y_labels$colour

    p <- ggplot(plot_polys, aes(x = px, y = py, group = tri_id, fill = sig_label)) +
      geom_polygon(colour = "white", linewidth = 0.2) +
      scale_fill_manual(
        values = c("Lower" = "#d73027", "Not separable" = "grey90", "Higher" = "#1a9850"),
        name = "",
        drop = FALSE
      ) +
      scale_x_continuous(breaks = seq_along(regions), labels = regions, expand = c(0, 0)) +
      scale_y_continuous(breaks = seq_along(sectors), labels = label_text,
                         expand = c(0, 0), position = y_side) +
      labs(title = panel_title, x = "", y = "") +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1, size = 7),
        axis.text.y = element_text(size = 8.5, colour = label_colours,# Sector y axis text size
                                   hjust = if (y_side == "right") 0 else 1),
        plot.title = element_text(size = 10, face = "bold"),
        legend.position = "bottom"
      ) +
      coord_fixed()

    if (!show_y_axis) {
      p <- p + theme(axis.text.y = element_blank(), axis.ticks.y = element_blank())
    }
    if (!show_x_axis) {
      p <- p + theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())
    }

    p
  }

  # --- Helper to build a pair of panels for a given sector subset ---
  build_pair <- function(sector_subset, regions, panel_title_left, panel_title_right,
                         show_x_axis = TRUE) {
    # Filter combined_data to just these sectors
    sub_data <- combined_data %>%
      filter(SIC07_description_shortened %in% sector_subset)

    # Temporarily override combined_data for nested helpers
    sub_cell_ols      <- build_cell_data_from("se_ols", sub_data)
    sub_cell_combined <- build_cell_data_from("se_combined", sub_data)

    sub_y_ols      <- build_y_labels_from("se_ols", sub_data)
    sub_y_combined <- build_y_labels_from("se_combined", sub_data)

    p_left  <- build_panel(sub_cell_ols, sub_y_ols, regions, sector_subset,
                           panel_title_left, show_y_axis = TRUE, y_side = "left",
                           show_x_axis = show_x_axis)
    p_right <- build_panel(sub_cell_combined, sub_y_combined, regions, sector_subset,
                           panel_title_right, show_y_axis = TRUE, y_side = "right",
                           show_x_axis = show_x_axis)
    list(left = p_left, right = p_right + guides(fill = "none"))
  }

  # Variants of helpers that accept a data argument (for subsetting)
  build_cell_data_from <- function(se_col, cdata) {
    compute_sig_from <- function(cdata2, ci_level, se_col2) {
      ci_z <- qnorm(1 - (1 - ci_level / 100) / 2)
      ci_data2 <- cdata2 %>% ungroup()
      focal2 <- ci_data2 %>% filter(Region_name == focal_region)
      others2 <- ci_data2 %>% filter(Region_name != focal_region)
      others2 %>%
        inner_join(
          focal2 %>% select(SIC07_description,
                            focal_slope = slope_ols,
                            focal_se = !!sym(se_col2)),
          by = 'SIC07_description'
        ) %>%
        mutate(
          z = (focal_slope - slope_ols) / sqrt(focal_se^2 + .data[[se_col2]]^2),
          sig = case_when(z > qnorm(1 - (1 - ci_level / 100) / 2) ~ 1L,
                          z < -qnorm(1 - (1 - ci_level / 100) / 2) ~ -1L,
                          TRUE ~ 0L)
        ) %>%
        select(SIC07_description, SIC07_description_shortened, Region_name, sig)
    }
    sig_lo <- compute_sig_from(cdata, ci_levels[1], se_col) %>% rename(sig_lo = sig)
    sig_hi <- compute_sig_from(cdata, ci_levels[2], se_col) %>% rename(sig_hi = sig)
    sig_lo %>%
      inner_join(sig_hi, by = c('SIC07_description', 'SIC07_description_shortened', 'Region_name'))
  }

  build_y_labels_from <- function(se_col, cdata) {
    ci_z <- qnorm(1 - (1 - 95 / 100) / 2)
    focal_data <- cdata %>%
      ungroup() %>%
      filter(Region_name == focal_region) %>%
      mutate(
        slope_pct = to_pct(slope_ols),
        ci_lo_pct = to_pct(slope_ols - .data[[se_col]] * ci_z),
        ci_hi_pct = to_pct(slope_ols + .data[[se_col]] * ci_z),
        crosses_zero = ci_lo_pct * ci_hi_pct < 0,
        label = paste0(SIC07_description_shortened, " (",
                       slope_pct, "% CI: ", ci_lo_pct, "%, ", ci_hi_pct, "%)"),
        colour = case_when(
          !crosses_zero & slope_ols > 0 ~ "#28da28",
          crosses_zero  & slope_ols > 0 ~ "#96c493",
          !crosses_zero & slope_ols < 0 ~ "red",
          crosses_zero  & slope_ols < 0 ~ "#ffcccc"
        )
      ) %>%
      arrange(SIC07_description_shortened) %>%
      select(SIC07_description_shortened, label, colour)
    focal_data
  }

  # --- Assemble ---
  regions <- sort(unique(combined_data %>% ungroup() %>%
                           filter(Region_name != focal_region) %>%
                           pull(Region_name)))

  # If top_bottom_n is set, split into high/low SE ratio groups
  if (!is.null(top_bottom_n) && !is.null(se_inflation_data)) {

    focal_se <- se_inflation_data %>%
      filter(Region_name == focal_region) %>%
      arrange(desc(se_ratio))

    top_sectors <- focal_se %>%
      slice_max(se_ratio, n = top_bottom_n, with_ties = FALSE) %>%
      pull(SIC07_description_shortened) %>%
      sort()

    bottom_sectors <- focal_se %>%
      slice_min(se_ratio, n = top_bottom_n, with_ties = FALSE) %>%
      pull(SIC07_description_shortened) %>%
      sort()

    top_pair <- build_pair(top_sectors, regions,
                           "OLS only", "OLS + extra",
                           show_x_axis = FALSE)
    bot_pair <- build_pair(bottom_sectors, regions,
                           "", "",
                           show_x_axis = TRUE)

    # Suppress legend on bottom row panels too — only top-left keeps it
    bot_pair$left  <- bot_pair$left  + guides(fill = "none")
    bot_pair$right <- bot_pair$right + guides(fill = "none")

    (top_pair$left + top_pair$right) / (bot_pair$left + bot_pair$right) +
      plot_layout(guides = "collect", heights = c(1, 1)) &
      theme(legend.position = "bottom") &
      plot_annotation(
        title = paste0("Growth slope comparisons: ", focal_region,
                       " (top & bottom ", top_bottom_n, " by SE inflation)"),
        subtitle = paste0("Top: highest SE ratio sectors (uncertainty matters most). ",
                          "Bottom: lowest SE ratio sectors (barely changes).\n",
                          "Bottom-left triangle = ", ci_levels[1],
                          "% CI, top-right = ", ci_levels[2], "% CI."),
        theme = theme(
          plot.title = element_text(size = 12, face = "bold"),
          plot.subtitle = element_text(size = 9, colour = "grey40")
        )
      )

  } else {
    # Original behaviour: all sectors, single pair of panels
    sectors <- sort(unique(combined_data$SIC07_description_shortened))

    cell_ols      <- build_cell_data("se_ols")
    cell_combined <- build_cell_data("se_combined")

    y_labels_ols      <- build_y_labels("se_ols")
    y_labels_combined <- build_y_labels("se_combined")

    p1 <- build_panel(cell_ols, y_labels_ols, regions, sectors,
                      "OLS only", show_y_axis = TRUE)
    p2 <- build_panel(cell_combined, y_labels_combined, regions, sectors,
                      "OLS + extra", show_y_axis = TRUE, y_side = "right")

    p1 + p2 +
      plot_layout(guides = "collect") &
      theme(legend.position = "bottom") &
      plot_annotation(
        title = paste0("Growth slope comparisons: ", focal_region),
        subtitle = paste0("Bottom-left = ", ci_levels[1],
                          "% CI, top-right = ", ci_levels[2],
                          "% CI. Y-axis text: focal slope (annualised %) coloured by whether CI crosses zero."),
        theme = theme(
          plot.title = element_text(size = 12, face = "bold"),
          plot.subtitle = element_text(size = 9, colour = "grey40")
        )
      )
  }
}

# Example
plot_focal_split_coloured(slopes_combined, "Yorkshire and The Humber")
plot_focal_split_coloured(slopes_combined, "London")
plot_focal_split_coloured(slopes_combined, "South East")

# Top/bottom SE ratio version
plot_focal_split_coloured(slopes_combined, "London",
                          top_bottom_n = 10, se_inflation_data = se_inflation)
plot_focal_split_coloured(slopes_combined, "Yorkshire and The Humber",
                          top_bottom_n = 10, se_inflation_data = se_inflation)


## Worked example: z-test on a pair of slopes ----
# Yorkshire and The Humber vs East, Telecommunications sector
# In the diagonal grid: vanilla OLS shows sig at both 90% and 95%,
# but with AR(1) measurement uncertainty it's only sig at 90%.

# Extract the two slopes
example_sector <- "Telecommunications"
region_a_name <- "Yorkshire and The Humber"
region_b_name <- "East"

region_a <- slopes_combined %>%
  filter(Region_name == region_a_name,
         grepl(example_sector, SIC07_description, ignore.case = TRUE))

region_b <- slopes_combined %>%
  filter(Region_name == region_b_name,
         grepl(example_sector, SIC07_description, ignore.case = TRUE))

sector_label <- region_a$SIC07_description[1]

cat("\n=== Worked example: z-test on slope differences ===\n")
cat("Sector:", sector_label, "\n\n")

# Convert to annualised % for readability
to_pct <- function(x) round((exp(x) - 1) * 100, 2)

cat(region_a_name, ":\n")
cat("  slope (log) =", round(region_a$slope_ols, 5), "\n")
cat("  annualised  =", to_pct(region_a$slope_ols), "%\n")
cat("  se_ols      =", round(region_a$se_ols, 5), "\n")
cat("  slope_sd    =", round(region_a$slope_sd, 5), "(MC measurement uncertainty)\n")
cat("  se_combined =", round(region_a$se_combined, 5), "\n\n")

cat(region_b_name, ":\n")
cat("  slope (log) =", round(region_b$slope_ols, 5), "\n")
cat("  annualised  =", to_pct(region_b$slope_ols), "%\n")
cat("  se_ols      =", round(region_b$se_ols, 5), "\n")
cat("  slope_sd    =", round(region_b$slope_sd, 5), "(MC measurement uncertainty)\n")
cat("  se_combined =", round(region_b$se_combined, 5), "\n\n")

# The z-test
slope_diff <- region_a$slope_ols - region_b$slope_ols
se_diff_ols <- sqrt(region_a$se_ols^2 + region_b$se_ols^2)
se_diff_combined <- sqrt(region_a$se_combined^2 + region_b$se_combined^2)

z_ols <- slope_diff / se_diff_ols
z_combined <- slope_diff / se_diff_combined

cat("--- Z-test on slope difference ---\n")
cat("Slope difference (A - B):", round(slope_diff, 5),
    "(", to_pct(region_a$slope_ols), "% -", to_pct(region_b$slope_ols), "% )\n")
cat("\nVanilla OLS:\n")
cat("  SE of difference = sqrt(", round(region_a$se_ols, 5), "^2 +",
    round(region_b$se_ols, 5), "^2 ) =", round(se_diff_ols, 5), "\n")
cat("  z =", round(slope_diff, 5), "/", round(se_diff_ols, 5), "=", round(z_ols, 3), "\n")
cat("  |z| > 1.645 (90%)?", abs(z_ols) > 1.645, "\n")
cat("  |z| > 1.960 (95%)?", abs(z_ols) > 1.960, "\n")

cat("\nWith measurement uncertainty (quadrature):\n")
cat("  SE of difference = sqrt(", round(region_a$se_combined, 5), "^2 +",
    round(region_b$se_combined, 5), "^2 ) =", round(se_diff_combined, 5), "\n")
cat("  z =", round(slope_diff, 5), "/", round(se_diff_combined, 5), "=", round(z_combined, 3), "\n")
cat("  |z| > 1.645 (90%)?", abs(z_combined) > 1.645, "\n")
cat("  |z| > 1.960 (95%)?", abs(z_combined) > 1.960, "\n")

cat("\nInterpretation: the slope difference stays the same, but the denominator grows.\n")
cat("  OLS-only SE of difference:     ", round(se_diff_ols, 5), "\n")
cat("  Combined SE of difference:     ", round(se_diff_combined, 5), "\n")
cat("  Ratio (combined / OLS):        ", round(se_diff_combined / se_diff_ols, 3), "\n")
cat("  The measurement uncertainty inflated the SE by",
    round((se_diff_combined / se_diff_ols - 1) * 100, 1), "%\n")

# Panel 1: Individual slopes with their CIs (for context)
p1_data <- tibble(
  region = factor(c(region_a_name, region_a_name, region_b_name, region_b_name),
                  levels = c(region_a_name, region_b_name)),
  method = factor(rep(c("OLS only", "OLS + measurement\nuncertainty"), 2),
                  levels = c("OLS only", "OLS + measurement\nuncertainty")),
  slope = c(region_a$slope_ols, region_a$slope_ols,
            region_b$slope_ols, region_b$slope_ols),
  se = c(region_a$se_ols, region_a$se_combined,
         region_b$se_ols, region_b$se_combined)
) %>%
  mutate(
    slope_pct = to_pct(slope),
    lo_90_pct = to_pct(slope - 1.645 * se),
    hi_90_pct = to_pct(slope + 1.645 * se),
    lo_95_pct = to_pct(slope - 1.960 * se),
    hi_95_pct = to_pct(slope + 1.960 * se)
  )

p1 <- ggplot(p1_data, aes(x = method, y = slope_pct, colour = region)) +
  geom_errorbar(aes(ymin = lo_95_pct, ymax = hi_95_pct),
                width = 0.2, linewidth = 1.5, alpha = 0.3,
                position = position_dodge(width = 0.5)) +
  geom_errorbar(aes(ymin = lo_90_pct, ymax = hi_90_pct),
                width = 0.15, linewidth = 0.8,
                position = position_dodge(width = 0.5)) +
  geom_point(size = 3, position = position_dodge(width = 0.5)) +
  scale_colour_manual(values = c("#e66101", "#5e3c99"), name = "Region") +
  labs(
    title = "Individual slopes",
    subtitle = "Thin = 90% CI, wide = 95% CI",
    x = "", y = "Annualised growth rate (%)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 11, face = "bold"),
    plot.subtitle = element_text(size = 8, colour = "grey40"),
    legend.position = "bottom"
  )

# Panel 2: The z-test visualised — slope DIFFERENCE with CI around it
# Does the CI on the difference cross zero?
diff_pct <- to_pct(slope_diff)

p2_data <- tibble(
  method = factor(c("OLS only", "OLS + measurement\nuncertainty"),
                  levels = c("OLS only", "OLS + measurement\nuncertainty")),
  diff = slope_diff,
  se_diff = c(se_diff_ols, se_diff_combined),
  z = c(z_ols, z_combined)
) %>%
  mutate(
    diff_pct = to_pct(diff),
    lo_90_pct = to_pct(diff - 1.645 * se_diff),
    hi_90_pct = to_pct(diff + 1.645 * se_diff),
    lo_95_pct = to_pct(diff - 1.960 * se_diff),
    hi_95_pct = to_pct(diff + 1.960 * se_diff),
    sig_95 = abs(z) > 1.960,
    label = paste0("z = ", round(z, 2))
  )

p2 <- ggplot(p2_data, aes(x = method, y = diff_pct)) +
  geom_hline(yintercept = 0, linetype = 'dashed', colour = 'red', linewidth = 0.8) +
  # 95% CI (wider, lighter)
  geom_errorbar(aes(ymin = lo_95_pct, ymax = hi_95_pct, colour = sig_95),
                width = 0.2, linewidth = 1.5, alpha = 0.4) +
  # 90% CI (narrower, darker)
  geom_errorbar(aes(ymin = lo_90_pct, ymax = hi_90_pct, colour = sig_95),
                width = 0.15, linewidth = 0.8) +
  geom_point(size = 3) +
  geom_text(aes(label = label), nudge_x = 0.3, size = 3.5, colour = "grey30") +
  scale_colour_manual(
    values = c("TRUE" = "#1a9850", "FALSE" = "#d73027"),
    labels = c("TRUE" = "Sig. at 95%", "FALSE" = "Not sig. at 95%"),
    name = ""
  ) +
  annotate("text", x = 0.6, y = 0, label = "zero\n(no difference)",
           size = 2.8, colour = "red", hjust = 0) +
  labs(
    title = "Z-test: slope difference",
    subtitle = paste0(region_a_name, " minus ", region_b_name,
                      "\nDoes the CI on the difference cross zero?"),
    x = "", y = "Difference in annualised growth rate (pp)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 11, face = "bold"),
    plot.subtitle = element_text(size = 8, colour = "grey40"),
    legend.position = "bottom"
  )

# Combine side by side
library(patchwork)
p1 + p2 +
  plot_annotation(
    title = paste0("Worked example: ", sector_label),
    subtitle = paste0("Left: each region's slope and CIs. Right: the actual z-test — ",
                      "is the difference significantly different from zero?"),
    theme = theme(
      plot.title = element_text(size = 13, face = "bold"),
      plot.subtitle = element_text(size = 9, colour = "grey40")
    )
  )


## SE inflation ratio: where does measurement uncertainty matter most? ----
# se_combined / se_ols tells us how much the total SE inflates when adding
# ABS measurement uncertainty. Ratio of 1 = no change, >1 = measurement
# uncertainty adds meaningful noise on top of regression uncertainty.

se_inflation <- slopes_combined %>%
  filter(!qg('membership|other personal',SIC07_description)) %>% 
  ungroup() %>%
  filter(!is.na(se_ols) & se_ols > 0 & !is.na(se_combined)) %>%
  mutate(
    se_ratio = se_combined / se_ols,
    slope_pct = round((exp(slope_ols) - 1) * 100, 1)
  )

# Top 20 most inflated
se_inflation %>%
  arrange(desc(se_ratio)) %>%
  select(Region_name, SIC07_description_shortened, slope_pct, se_ols, se_combined, se_ratio) %>%
  head(20)

# Summary by region: which places are most affected?
se_inflation_by_region <- se_inflation %>%
  group_by(Region_name) %>%
  summarise(
    median_ratio = median(se_ratio, na.rm = TRUE),
    mean_ratio   = mean(se_ratio, na.rm = TRUE),
    max_ratio    = max(se_ratio, na.rm = TRUE),
    n_above_1.5  = sum(se_ratio > 1.5, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  arrange(desc(median_ratio))

# Summary by sector: which sectors are most affected?
se_inflation_by_sector <- se_inflation %>%
  group_by(SIC07_description_shortened) %>%
  summarise(
    median_ratio = median(se_ratio, na.rm = TRUE),
    mean_ratio   = mean(se_ratio, na.rm = TRUE),
    max_ratio    = max(se_ratio, na.rm = TRUE),
    n_above_1.5  = sum(se_ratio > 1.5, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  arrange(desc(median_ratio))


# --- Visualisation: heatmap of SE inflation ratio by region x sector ---

plot_se_inflation_heatmap <- function(data, cap_ratio = 3) {

  plot_data <- data %>%
    mutate(se_ratio_capped = pmin(se_ratio, cap_ratio))

  ggplot(plot_data, aes(x = Region_name,
                        y = fct_reorder(SIC07_description_shortened, se_ratio, .fun = median),
                        fill = se_ratio_capped)) +
    geom_tile(colour = "white", linewidth = 0.3) +
    scale_fill_gradientn(
      colours = c("grey95", "#fee08b", "#fdae61", "#d73027"),
      values  = scales::rescale(c(1, 1.2, 1.5, cap_ratio)),
      limits  = c(1, cap_ratio),
      name = paste0("SE ratio\n(capped at ", cap_ratio, ")"),
      breaks = c(1, 1.5, 2, 2.5, cap_ratio)
    ) +
    labs(
      title = "SE inflation ratio: se_combined / se_ols",
      subtitle = "How much does ABS measurement uncertainty inflate the total SE?\nSectors ordered by median ratio across regions.",
      x = "", y = ""
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 7),
      axis.text.y = element_text(size = 5.5),
      plot.title = element_text(size = 12, face = "bold"),
      plot.subtitle = element_text(size = 9, colour = "grey40"),
      legend.position = "right"
    )
}

plot_se_inflation_heatmap(se_inflation)


# --- Visualisation: heatmap of SE inflation, region perspective ---
# Regions on the y-axis ordered by mean ratio, sectors on x-axis.

plot_se_inflation_heatmap_byregion <- function(data, cap_ratio = 3) {

  plot_data <- data %>%
    mutate(se_ratio_capped = pmin(se_ratio, cap_ratio))

  ggplot(plot_data, aes(x = fct_reorder(SIC07_description_shortened, se_ratio, .fun = median),
                        y = fct_reorder(Region_name, se_ratio, .fun = mean),
                        fill = se_ratio_capped)) +
    geom_tile(colour = "white", linewidth = 0.3) +
    scale_fill_gradientn(
      colours = c("grey95", "#fee08b", "#fdae61", "#d73027"),
      values  = scales::rescale(c(1, 1.2, 1.5, cap_ratio)),
      limits  = c(1, cap_ratio),
      name = paste0("SE ratio\n(capped at ", cap_ratio, ")"),
      breaks = c(1, 1.5, 2, 2.5, cap_ratio)
    ) +
    labs(
      title = "SE inflation ratio by region",
      subtitle = "Regions ordered by mean ratio across sectors.\nHigher = ABS measurement uncertainty inflates SE more.",
      x = "", y = ""
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 5.5),
      axis.text.y = element_text(size = 8),
      plot.title = element_text(size = 12, face = "bold"),
      plot.subtitle = element_text(size = 9, colour = "grey40"),
      legend.position = "right"
    )
}

plot_se_inflation_heatmap_byregion(se_inflation)



# --- Visualisation: dot plot ranked by SE ratio, faceted by region ---

plot_se_inflation_dotplot <- function(data, top_n = 15) {

  # For each region, pick the top_n most inflated sectors
  plot_data <- data %>%
    group_by(Region_name) %>%
    slice_max(se_ratio, n = top_n) %>%
    ungroup()

  ggplot(plot_data, aes(x = se_ratio,
                        y = fct_reorder2(SIC07_description_shortened, Region_name, se_ratio))) +
    geom_point(aes(colour = se_ratio), size = 2) +
    geom_vline(xintercept = 1, linetype = "dashed", colour = "grey50") +
    scale_colour_gradient2(
      low = "grey70", mid = "#fdae61", high = "#d73027",
      midpoint = 1.5, guide = "none"
    ) +
    facet_wrap(~Region_name, scales = "free_y", ncol = 3) +
    labs(
      title = "Top sectors by SE inflation ratio per region",
      subtitle = paste0("Top ", top_n, " sectors shown. Dashed line = ratio of 1 (no inflation)."),
      x = "SE ratio (se_combined / se_ols)", y = ""
    ) +
    theme_minimal() +
    theme(
      axis.text.y = element_text(size = 5),
      strip.text = element_text(face = "bold", size = 9),
      plot.title = element_text(size = 12, face = "bold"),
      plot.subtitle = element_text(size = 9, colour = "grey40")
    )
}

plot_se_inflation_dotplot(se_inflation)


## Z-score erosion: which pairwise comparisons lose significance? ----
# For every focal region × sector × comparator, compute z-scores under both
# OLS-only and combined SEs. The drop (z_ols - z_combined) shows how much
# "significance" is eroded by adding measurement uncertainty.
# Large positive erosion = comparison that looked significant under OLS but
# is weakened or lost when accounting for ABS uncertainty.

compute_z_erosion <- function(combined_data, ci_level = 95) {

  ci_z <- qnorm(1 - (1 - ci_level / 100) / 2)
  cdata <- combined_data %>% ungroup()

  # All pairwise comparisons: every region vs every other region, per sector
  pairs <- cdata %>%
    inner_join(cdata, by = "SIC07_description", suffix = c("_a", "_b"),
               relationship = "many-to-many") %>%
    filter(Region_name_a < Region_name_b)  # avoid duplicates and self-comparisons

  pairs %>%
    mutate(
      z_ols = abs(slope_ols_a - slope_ols_b) / sqrt(se_ols_a^2 + se_ols_b^2),
      z_combined = abs(slope_ols_a - slope_ols_b) / sqrt(se_combined_a^2 + se_combined_b^2),
      z_erosion = z_ols - z_combined,
      sig_ols      = z_ols > ci_z,
      sig_combined = z_combined > ci_z,
      flipped = sig_ols & !sig_combined
    ) %>%
    select(
      Region_a = Region_name_a, Region_b = Region_name_b,
      SIC07_description,
      SIC07_short = SIC07_description_shortened_a,
      slope_pct_a = slope_ols_a, slope_pct_b = slope_ols_b,
      se_ols_a, se_ols_b, se_combined_a, se_combined_b,
      z_ols, z_combined, z_erosion,
      sig_ols, sig_combined, flipped
    )
}

z_erosion <- compute_z_erosion(slopes_combined %>% filter(!qg('membership|other personal',SIC07_description)))

# Top 30 biggest erosions (comparisons most weakened by measurement uncertainty)
z_erosion %>%
  filter(flipped) %>%
  arrange(desc(z_erosion)) %>%
  select(Region_a, Region_b, SIC07_short, z_ols, z_combined, z_erosion) %>%
  head(30)

# Summary: how many comparisons flip per sector?
z_erosion_by_sector <- z_erosion %>%
  group_by(SIC07_short) %>%
  summarise(
    n_pairs = n(),
    n_sig_ols = sum(sig_ols, na.rm = TRUE),
    n_sig_combined = sum(sig_combined, na.rm = TRUE),
    n_flipped = sum(flipped, na.rm = TRUE),
    median_erosion = median(z_erosion, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  arrange(desc(n_flipped))

# Summary: how many comparisons flip per region (as either side of the pair)?
z_erosion_by_region <- z_erosion %>%
  pivot_longer(cols = c(Region_a, Region_b), values_to = "Region_name") %>%
  group_by(Region_name) %>%
  summarise(
    n_pairs = n(),
    n_sig_ols = sum(sig_ols, na.rm = TRUE),
    n_sig_combined = sum(sig_combined, na.rm = TRUE),
    n_flipped = sum(flipped, na.rm = TRUE),
    median_erosion = median(z_erosion, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  arrange(desc(n_flipped))


# --- Visualisation: heatmap of flipped comparisons by region x sector ---

plot_z_erosion_heatmap <- function(erosion_data) {

  # Count flips per region x sector (region appears on either side of pair)
  flip_counts <- erosion_data %>%
    filter(flipped) %>%
    pivot_longer(cols = c(Region_a, Region_b), values_to = "Region_name") %>%
    count(Region_name, SIC07_short, name = "n_flipped")

  # Complete grid so all cells appear
  all_regions <- sort(unique(erosion_data$Region_a, erosion_data$Region_b))
  all_sectors <- sort(unique(erosion_data$SIC07_short))
  full_grid <- expand.grid(Region_name = all_regions,
                           SIC07_short = all_sectors,
                           stringsAsFactors = FALSE) %>%
    left_join(flip_counts, by = c("Region_name", "SIC07_short")) %>%
    mutate(n_flipped = replace_na(n_flipped, 0))

  ggplot(full_grid, aes(x = Region_name,
                        y = fct_reorder(SIC07_short, n_flipped, .fun = sum),
                        fill = n_flipped)) +
    geom_tile(colour = "white", linewidth = 0.3) +
    scale_fill_gradient(
      low = "grey95", high = "#d73027",
      name = "Flipped\ncomparisons"
    ) +
    labs(
      title = "Z-score erosion: comparisons that lose significance",
      subtitle = "Number of pairwise comparisons that flip from significant (OLS) to\nnot significant (OLS + measurement uncertainty). Sectors ordered by total flips.",
      x = "", y = ""
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 7),
      axis.text.y = element_text(size = 5.5),
      plot.title = element_text(size = 12, face = "bold"),
      plot.subtitle = element_text(size = 9, colour = "grey40"),
      legend.position = "right"
    )
}

plot_z_erosion_heatmap(z_erosion)


# --- Visualisation: paired dot plot showing z_ols vs z_combined for flipped pairs ---
# Shows the top N most eroded comparisons as connected dots

plot_z_erosion_pairs <- function(erosion_data, top_n = 30) {

  plot_data <- erosion_data %>%
    filter(flipped) %>%
    slice_max(z_erosion, n = top_n) %>%
    mutate(
      pair_label = paste0(Region_a, " vs ", Region_b, "\n", SIC07_short)
    )

  # Reshape for connected dot plot
  plot_long <- plot_data %>%
    select(pair_label, z_erosion, z_ols, z_combined) %>%
    pivot_longer(cols = c(z_ols, z_combined),
                 names_to = "method", values_to = "z_score") %>%
    mutate(method = ifelse(method == "z_ols", "OLS only", "OLS + measurement uncertainty"))

  ggplot(plot_long, aes(x = z_score, y = fct_reorder(pair_label, z_erosion))) +
    geom_line(aes(group = pair_label), colour = "grey60", linewidth = 0.5) +
    geom_point(aes(colour = method), size = 2.5) +
    geom_vline(xintercept = qnorm(0.975), linetype = "dashed", colour = "grey40") +
    scale_colour_manual(
      values = c("OLS only" = "#1a9850", "OLS + measurement uncertainty" = "#d73027"),
      name = ""
    ) +
    annotate("text", x = qnorm(0.975), y = 0.5, label = "z = 1.96",
             hjust = -0.1, size = 3, colour = "grey40") +
    labs(
      title = paste0("Top ", top_n, " comparisons most eroded by measurement uncertainty"),
      subtitle = "Green dot = OLS z-score, red dot = combined z-score.\nDashed line = 95% significance threshold. All shown pairs cross the threshold under OLS but not combined.",
      x = "Absolute z-score", y = ""
    ) +
    theme_minimal() +
    theme(
      axis.text.y = element_text(size = 5.5),
      plot.title = element_text(size = 12, face = "bold"),
      plot.subtitle = element_text(size = 9, colour = "grey40"),
      legend.position = "bottom"
    )
}

plot_z_erosion_pairs(z_erosion)


# --- Visualisation: diverging bar chart of significance counts lost per sector ---

plot_z_erosion_bars <- function(erosion_by_sector) {

  plot_data <- erosion_by_sector %>%
    mutate(
      n_retained = n_sig_combined,
      n_lost = n_flipped,
      pct_lost = round(n_lost / n_sig_ols * 100, 1)
    ) %>%
    filter(n_sig_ols > 0)

  ggplot(plot_data, aes(x = fct_reorder(SIC07_short, pct_lost),
                        y = pct_lost)) +
    geom_col(fill = "#d73027", alpha = 0.8) +
    geom_text(aes(label = paste0(n_lost, "/", n_sig_ols)),
              hjust = -0.1, size = 2.5) +
    coord_flip() +
    labs(
      title = "Percentage of significant comparisons lost per sector",
      subtitle = "Labels: flipped / total significant under OLS.\nHigher = measurement uncertainty has more impact on this sector's comparisons.",
      x = "", y = "% of OLS-significant comparisons lost"
    ) +
    theme_minimal() +
    theme(
      axis.text.y = element_text(size = 5.5),
      plot.title = element_text(size = 12, face = "bold"),
      plot.subtitle = element_text(size = 9, colour = "grey40")
    )
}

plot_z_erosion_bars(z_erosion_by_sector)


# PASTE FROM CLAUDE CODE: AVERAGES ON LQS VS ON UNDERLYING NUMBERS----

# Method 1: Moving average of LQ directly
# Method 2: Moving average of GVA, then compute LQ from that

# Pick a 3-year window, e.g. 2019-2021
window_years <- 2019:2021

# Method 2: average GVA first, then compute LQ
gva_averaged <- itl1.cp.linked %>%
  filter(year %in% window_years) %>%
  group_by(ITL_code, Region_name, SIC07_description) %>%
  summarise(value = mean(value, na.rm = TRUE), .groups = 'drop')

# Add LQ to the averaged GVA
gva_averaged_lq <- gva_averaged %>%
  add_location_quotient_and_proportions(
    regionvar = Region_name,
    lq_var = SIC07_description,
    valuevar = value
  ) %>%
  select(Region_name, SIC07_description, LQ_from_avg_gva = LQ)

# Method 1: average the LQs directly
lq_averaged <- LQ_with_sim_CIs %>%
  filter(year %in% window_years) %>%
  group_by(Region_name, SIC07_description) %>%
  summarise(LQ_avg_direct = mean(LQ_central, na.rm = TRUE), .groups = 'drop')

# Compare
comparison <- lq_averaged %>%
  inner_join(gva_averaged_lq, by = c('Region_name', 'SIC07_description')) %>%
  mutate(
    diff = LQ_avg_direct - LQ_from_avg_gva,
    pct_diff = diff / LQ_from_avg_gva * 100
  )

summary(comparison$pct_diff)
# Also check the worst cases
comparison %>% arrange(desc(abs(pct_diff))) %>% head(20)


























