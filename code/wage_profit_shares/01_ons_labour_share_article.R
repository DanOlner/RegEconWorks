# UK labour share over time, by method, by industry group and against the G7
# Source: chart data behind ONS 'Trends in the UK labour share: 1997 to 2023' (25 November 2024)
# Used in llm_output/wage_profit_shares_gva.md, sections 1 to 3.1
source('code/wage_profit_shares/functions.R')


# DOWNLOAD CHART DATA----

chart_base <- 'https://www.ons.gov.uk/generator?uri=/economy/economicoutputandproductivity/output/articles/trendsintheuklabourshare1997to2023/2024-11-25/'

charts <- tribble(
  ~name,        ~id,        ~what,
  'methods',    '18efee48', 'Figure 1: labour share by method 1-5, % of GVA at factor cost, 1948-2023',
  'corp_net',   '01fc2494', 'Figure 3: total and corporate, gross and net labour shares, 1987-2023',
  'g7',         'd3075a34', 'Figure 4: G7 labour share index (method 4), 1995 = 100',
  'industry',   '0b1e8041', 'Figure 5: industry labour shares, 1997 and 2022',
  'shiftshare', '0171bf57', 'Figure 6: shift-share contributions to the 1997-2022 rise'
)

# Each CSV has a few title, note and unit lines (the notes can run over several lines inside quotes).
# The title lines have only two columns, so fix a generous column count rather than let it be guessed.
# The column header row is the first with an empty first cell and a non-empty second cell
read_ons_chart <- function(path) {
  raw <- read.csv(path, header = FALSE, col.names = paste0('X', 1:12), fill = TRUE,
                  colClasses = 'character', na.strings = '') %>%
    select(where(~ !all(is.na(.x))))
  header_row <- which(is.na(raw$X1) & !is.na(raw$X2))[1]
  raw %>%
    slice((header_row + 1):n()) %>%
    set_names(c('label', unlist(raw[header_row, -1]))) %>%
    mutate(across(-label, as.numeric)) %>%
    as_tibble()
}

ons <- map2(charts$id, charts$name, ~ get_file(paste0(chart_base, .x, '&format=csv'), paste0('ons_labour_share_', .y, '.csv'))) %>%
  map(read_ons_chart) %>%
  set_names(charts$name)


# RESULTS----

# Method 5 is ONS's preferred measure
ons$methods %>% filter(label %in% c('1948', '1960', '1970', '1975', '1996', '2001', '2023'))

# Range of method 5 since 2001
ons$methods %>% filter(as.integer(label) >= 2001) %>% summarise(min = min(`Method 5`), max = max(`Method 5`))

# 2023: lowest (method 1, no mixed income counted as pay) to highest (method 4) estimate
ons$methods %>% filter(label == '2023')

ons$corp_net %>% filter(label == '2023')
ons$g7 %>% filter(label %in% c('2022', '2023'))
ons$industry
ons$shiftshare
