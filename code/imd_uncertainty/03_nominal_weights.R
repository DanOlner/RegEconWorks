# Nominal share of the IMD carried by each indicator, and how open the data behind it are
# Domain weight x sub-domain weight x indicator weight, from technical report Table 3.1 (domains),
# Tables 4.1 and 4.4 to 4.6 (factor-analysis weights) and sections 4.5, 4.8 and 4.9 (sub-domain weights).
# Nominal only: ranking and the exponential transforms change each indicator's real influence on a rank.
# Assumes each composite item in the wider barriers sub-domain (housing affordability, overcrowding,
# homelessness) counts as one of five equal items, split equally between its two components.
# The report doesn't say whether composites are re-standardised (research note section 3.7)
# Used in llm_output/imd_rank_uncertainty_research.md, section 3.8,
# and docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd
source('code/imd_uncertainty/functions.R')

# What the open data allow for each indicator's error. Grouped by what a public user can do, using File 8
# and the open sources behind some indicators (11 and 12 rebuild road casualties and overcrowding):
access_levels <- c(
  'Counts published or open at source',               # counts and denominators known: error estimated directly
  'Shrunk rate published, count recoverable',         # rate after shrinkage; count via a denominator and inversion
  'Ratio, composite or score with no count',          # standardised ratios, composites of normal scores, property scores
  'Modelled or unshrunk, no error published',         # model outputs and indicators with no sampling model
  'Not published (secure data)'                       # pupil-level indicators: DfE doesn't allow LSOA release
)

# One row per indicator. sub_w = sub-domain weight within the domain; ind_w = indicator weight within the sub-domain
indicator_weights <- tribble(
  ~domain,      ~subdomain,                  ~indicator,                                 ~sub_w, ~ind_w,         ~supplier,                                   ~access,
  'income',     NA,                          'Income domain (9 benefit counts)',         1,      1,              'DWP (and Home Office for asylum support)',  1,
  'employment', NA,                          'Employment domain (12 benefit counts)',    1,      1,              'DWP',                                       1,
  'education',  'children and young people', 'Key Stage 2 attainment',                   0.5,    0.169,          'DfE',                                       5,
  'education',  'children and young people', 'Key Stage 4 attainment',                   0.5,    0.192,          'DfE',                                       5,
  'education',  'children and young people', 'Pupil absence',                            0.5,    0.247,          'DfE',                                       5,
  'education',  'children and young people', 'Persistent pupil absence',                 0.5,    0.246,          'DfE',                                       5,
  'education',  'children and young people', 'Entry to higher education',                0.5,    0.146,          'JISC',                                      2,
  'education',  'adult skills',              'Adult skills and English proficiency',     0.5,    1,              'ONS Census 2021',                           2,
  'health',     NA,                          'Comparative Illness and Disability Ratio', 1,      0.294,          'DWP',                                       3,
  'health',     NA,                          'Years of potential life lost',             1,      0.240,          'ONS',                                       3,
  'health',     NA,                          'Acute morbidity',                          1,      0.222,          'NHS',                                       3,
  'health',     'mental health composite',   'Mental health: suicide',                   1,      0.244 * 0.105,  'ONS',                                       3,
  'health',     'mental health composite',   'Mental health: hospital admissions',       1,      0.244 * 0.186,  'NHS',                                       3,
  'health',     'mental health composite',   'Mental health: prescribing',               1,      0.244 * 0.211,  'NHS',                                       3,
  'health',     'mental health composite',   'Mental health: health benefits',           1,      0.244 * 0.498,  'DWP',                                       3,
  'crime',      NA,                          'Violence with injury',                     1,      0.151,          'Police',                                    2,
  'crime',      NA,                          'Violence without injury',                  1,      0.154,          'Police',                                    2,
  'crime',      NA,                          'Stalking and harassment',                  1,      0.132,          'Police',                                    2,
  'crime',      NA,                          'Burglary',                                 1,      0.074,          'Police',                                    2,
  'crime',      NA,                          'Theft',                                    1,      0.097,          'Police',                                    2,
  'crime',      NA,                          'Criminal damage',                          1,      0.144,          'Police',                                    2,
  'crime',      NA,                          'Public order and possession of weapons',   1,      0.145,          'Police',                                    2,
  'crime',      NA,                          'Anti-social behaviour',                    1,      0.103,          'Police',                                    2,
  'barriers',   'geographical',              'Connectivity score',                       0.5,    1,              'DfT',                                       4,
  'barriers',   'wider',                     'Housing affordability: owner-occupation',  0.5,    1 / 5 / 2,      'Modelled (Heriot-Watt)',                    4,
  'barriers',   'wider',                     'Housing affordability: private rental',    0.5,    1 / 5 / 2,      'Modelled (Heriot-Watt)',                    4,
  'barriers',   'wider',                     'Overcrowding: rooms',                      0.5,    1 / 5 / 2,      'ONS Census 2021',                           1,
  'barriers',   'wider',                     'Overcrowding: bedrooms',                   0.5,    1 / 5 / 2,      'ONS Census 2021',                           1,
  'barriers',   'wider',                     'Statutory homelessness (LAD level)',       0.5,    1 / 5 / 2,      'MHCLG',                                     4,
  'barriers',   'wider',                     'Core homelessness (LAD level)',            0.5,    1 / 5 / 2,      'Modelled (Heriot-Watt)',                    4,
  'barriers',   'wider',                     'Broadband speed',                          0.5,    1 / 5,          'Ofcom',                                     4,
  'barriers',   'wider',                     'Patient-to-GP ratio',                      0.5,    1 / 5,          'NHS',                                       4,
  'living',     'indoors',                   'Housing in poor condition',                0.7,    1 / 3,          'Modelled (BRE)',                            4,
  'living',     'indoors',                   'Housing energy performance (EPC)',         0.7,    1 / 3,          'MHCLG',                                     3,
  'living',     'indoors',                   'Housing lacking private outdoor space',    0.7,    1 / 3,          'OS and ONS',                                3,
  'living',     'outdoors',                  'Air quality',                              0.3,    1 / 3,          'Modelled (Defra)',                          4,
  'living',     'outdoors',                  'Road casualties, pedestrians and cyclists', 0.3,   1 / 3,          'DfT',                                       1,
  'living',     'outdoors',                  'Noise',                                    0.3,    1 / 3,          'Modelled (Defra)',                          4
) %>%
  mutate(access = factor(access_levels[access], levels = access_levels))

nominal <- indicator_weights %>%
  left_join(select(domains, domain, weight), by = 'domain') %>%
  mutate(share = weight * sub_w * ind_w)

# Weights within each domain should add to 1
nominal %>% group_by(domain) %>% summarise(total_within_domain = sum(sub_w * ind_w))

# Total is 0.999 because the published domain weights add to 99.9%
sum(nominal$share)


# RESULTS----

nominal %>%
  arrange(desc(share)) %>%
  transmute(indicator, supplier, access, share_pct = round(100 * share, 2)) %>%
  print(n = Inf)

# Share resting on DWP benefit records: Income, Employment, CIDR and the mental health benefits component
dwp_share <- nominal %>%
  filter(str_detect(supplier, 'DWP')) %>%
  summarise(dwp_share_pct = 100 * sum(share))
dwp_share

# Share of the IMD by what is published
access_share <- nominal %>%
  group_by(access) %>%
  summarise(indicators = n(), share_pct = 100 * sum(share), .groups = 'drop')
access_share

# And by domain, for a stacked chart
access_by_domain <- nominal %>%
  group_by(domain, access) %>%
  summarise(share_pct = 100 * sum(share), .groups = 'drop')
