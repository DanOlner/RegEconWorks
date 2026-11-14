# Round 2 helpers: the UK input-output analytical tables (IOATs, 2019, product by product), the link
# from their CPA products to SIC 2007 groups, and employment by product from BRES.
# Needs functions_common.R and functions_uk.R (for the downloads and BRES).

suppressPackageStartupMessages(suppressWarnings(library(readxl)))

io_file <- function() tj_get_file(
  'https://www.ons.gov.uk/file?uri=/economy/nationalaccounts/supplyandusetables/datasets/ukinputoutputanalyticaltablesdetailed/2019/nasu1719pr.xlsx',
  'ioat_2019_nasu1719pr.xlsx', expect = 'xls')

io_num <- function(v) suppressWarnings(as.numeric(v))

# A product-by-product sheet ("IOT", "A", "Leontief", "Imports use pxp") as a list with the product
# block (matrix, products in rows and columns) and any extra columns to the right, named by header
io_sheet <- function(sheet) {
  d <- suppressMessages(read_excel(io_file(), sheet = sheet, col_names = FALSE, col_types = 'text'))
  codes_row <- which(apply(d, 1, function(r) sum(grepl('^CPA_', r))) > 50)[1]   # the row of column codes
  col_codes <- unlist(d[codes_row, ])
  pcols <- which(grepl('^CPA_', col_codes))
  prows <- which(grepl('^CPA_', d[[1]]))
  hdr <- unlist(d[codes_row + 1, ])                                              # the row of column names
  extra <- setdiff(seq_len(ncol(d)), c(1, 2, pcols))
  list(products = d[[1]][prows], names = d[[2]][prows],
       block = matrix(io_num(as.matrix(d[prows, pcols])), length(prows), length(pcols),
                      dimnames = list(d[[1]][prows], col_codes[pcols])),
       extra = setNames(lapply(extra, function(j) io_num(d[[j]][prows])), hdr[extra]),
       rows_below = d[-(1:max(prows)), ], pcols = pcols)
}

# The CPA products' links to SIC 2007 groups (3-digit) or divisions (2-digit). Shared with round 1's
# export shares (uk_export_share in functions_uk.R uses the same rules).
io_cpa_links <- function(cpa) {
  irregular <- list(
    'CPA_B06 & B07' = c('06', '07'), 'CPA_C11.01-6 & C12' = c('110', '12'),
    'CPA_C20A' = '20', 'CPA_C20B' = '20', 'CPA_C20C' = '20', 'CPA_C23OTHER' = '23', 'CPA_C25OTHER' = '25',
    'CPA_C30OTHER' = '30', 'CPA_C33OTHER' = '33', 'CPA_F41, F42 & F43' = c('41', '42', '43'),
    'CPA_J59 & J60' = c('59', '60'), 'CPA_K65.1-2 & K65.3' = c('651', '652', '653'),
    'CPA_L68A' = character(0), 'CPA_L68BXL683' = c('681', '682'), 'CPA_Q87 & Q88' = c('87', '88'))
  map_one <- function(x) {
    if (x %in% names(irregular)) return(irregular[[x]])
    s <- sub('^CPA_[A-Z]', '', x)
    if (grepl('T', s)) { r <- as.integer(strsplit(s, 'T')[[1]]); return(sprintf('%02d', seq(r[1], r[2]))) }
    s <- gsub('\\.', '', s); s <- gsub('[A-Z]+$', '', s)
    if (grepl('_', s)) {
      parts <- strsplit(s, '_')[[1]]; base <- parts[1]
      first <- as.integer(substr(base, nchar(base), nchar(base)))
      last <- as.integer(substr(parts[2], nchar(parts[2]), nchar(parts[2])))
      codes <- paste0(substr(base, 1, nchar(base) - 1), seq(first, last))
    } else codes <- s
    unique(ifelse(nchar(codes) >= 3, substr(codes, 1, 3), codes))
  }
  bind_rows(lapply(cpa, function(x) { cd <- map_one(x); if (!length(cd)) NULL else tibble(cpa = x, code = cd) }))
}

# GB employees in 2019 by product: BRES employees by SIC 3-digit group, each group shared across the
# products it links to (directly, or through its division) in proportion to the products' GVA.
# io_allocation() keeps the SIC group by product shares, so other SIC-level measures can follow them.
io_employment <- function(products, gva, year = 2019) {
  io_allocation(products, gva, year) %>% group_by(cpa) %>% summarise(employees = sum(emp_alloc), .groups = 'drop')
}

io_allocation <- function(products, gva, year = 2019) {
  bres <- uk_bres() %>% filter(year == !!year) %>% group_by(sic3) %>% summarise(emp = sum(employees), .groups = 'drop')
  links <- io_cpa_links(products)
  # expand division links to every SIC group in that division
  expanded <- bind_rows(
    links %>% filter(nchar(code) == 3) %>% rename(sic3 = code),
    links %>% filter(nchar(code) == 2) %>% inner_join(bres %>% transmute(sic3, code = substr(sic3, 1, 2)), by = 'code',
                                                        relationship = 'many-to-many') %>%
      select(cpa, sic3)) %>% distinct()
  # a group linked both directly and via a division keeps only its direct links
  direct <- links %>% filter(nchar(code) == 3) %>% pull(code)
  expanded <- expanded %>% group_by(sic3) %>%
    filter(!(sic3 %in% direct) | cpa %in% links$cpa[links$code == first(sic3)]) %>% ungroup()
  expanded %>% left_join(tibble(cpa = products, gva = gva), by = 'cpa') %>%
    inner_join(bres, by = 'sic3') %>%
    group_by(sic3) %>% mutate(weight = pmax(gva, 0) / sum(pmax(gva, 0))) %>% ungroup() %>%
    mutate(emp_alloc = emp * ifelse(is.finite(weight), weight, 0)) %>%
    select(cpa, sic3, emp, weight, emp_alloc)
}

# The 2019 tables as one row per product plus the matrices, all in £ million at basic prices.
#   Z: domestic products used by each product (rows: supplying product, columns: using product)
#   M: imported products used by each product, same layout
#   A = Z / output (by column), L = (I - A)^-1 (Leontief), G = (I - B)^-1 with B = Z / output by row (Ghosh)
io_tables <- function() {
  iot <- io_sheet('IOT'); imp <- io_sheet('Imports use pxp'); lt <- io_sheet('Leontief')
  same <- function(a, b) length(a) == length(b) && all(unname(a) == unname(b))
  stopifnot(same(iot$products, imp$products), same(iot$products, lt$products),
            same(iot$products, colnames(iot$block)), same(iot$products, colnames(imp$block)))
  below <- function(s, pattern) {                     # a row below the product block, by its label
    lab <- paste(s$rows_below[[1]], s$rows_below[[2]])
    i <- grep(pattern, lab)[1]
    if (is.na(i)) stop('No row matching "', pattern, '" in the input-output sheet')
    v <- io_num(unlist(s$rows_below[i, s$pcols])); ifelse(is.na(v), 0, v)
  }
  z0 <- function(v) ifelse(is.na(v), 0, v)
  ex <- lapply(iot$extra, z0); ei <- lapply(imp$extra, z0)
  Z <- iot$block; Z[is.na(Z)] <- 0
  M <- imp$block; M[is.na(M)] <- 0
  products <- tibble(
    cpa = iot$products, name = iot$names,
    output = below(iot, 'Total output at basic prices'),
    gva = below(iot, 'Gross value added'),
    coe = below(iot, 'Compensation of employees'),
    gos = below(iot, 'Gross operating surplus'),
    inputs_domestic = colSums(Z), inputs_imported = colSums(M),
    sales_intermediate = ex[['Total']],
    fd_households = ex[['Final consumption expenditure by households']],
    fd_government = ex[['Final consumption expenditure']] - ex[['Final consumption expenditure by households']],
    fd_investment = ex[['Gross fixed capital formation']] + ex[['Changes in inventories']] +
      ex[['Acquisitions less disposals of valuables']],
    fd_exports = ex[['Exports of goods to EU']] + ex[['Exports of goods to rest of the world']] + ex[['Exports of services']],
    total_use = ex[['Total Use at basic prices']],
    imports = ei[['Total Use at basic prices']])
  x <- products$output
  A <- sweep(Z, 2, ifelse(x > 0, x, 1), '/')
  B <- sweep(Z, 1, ifelse(x > 0, x, 1), '/')
  n <- length(x)
  L <- solve(diag(n) - A); dimnames(L) <- dimnames(Z)
  G <- solve(diag(n) - B); dimnames(G) <- dimnames(Z)
  LO <- lt$block; LO[is.na(LO)] <- 0
  list(products = products, Z = Z, M = M, A = A, L = L, G = G, L_ons = LO)
}

# Sector groups for Model F (19 groups, plus two left out), with two hand-made labels per group:
#   foundational: the typology in modelling_demand's foundational-economy note (tradable or basic;
#     material foundational; everyday services; housing; providential), with business services split out
#   limit: what limits productivity growth (round 2 plan, T1): tradable frontier, catch-up, squeezed
#     supplier, limited by local demand, land rent, or held fixed (providential, W5)
io_groups <- function(cpa) {
  s <- sub('^CPA_', '', cpa)
  sec <- substr(s, 1, 1); div <- suppressWarnings(as.integer(substr(s, 2, 3)))
  g <- case_when(
    s %in% c('L68A', 'T97') ~ 'excluded',
    sec == 'A' ~ 'agri_fish', sec == 'B' ~ 'mining',
    sec == 'C' & div %in% 10:12 ~ 'food_drink',
    sec == 'C' & div %in% c(13:18, 31, 32) ~ 'light_mfg',
    sec == 'C' & div %in% 19:21 ~ 'chem_pharma',
    sec == 'C' & div %in% 22:25 ~ 'metals_minerals',
    sec == 'C' & div %in% c(26:30, 33) ~ 'machinery_vehicles',
    sec %in% c('D', 'E') ~ 'utilities', sec == 'F' ~ 'construction',
    sec == 'G' & div %in% 45:46 ~ 'wholesale_motor', sec == 'G' ~ 'retail',
    sec == 'H' ~ 'transport', sec == 'I' ~ 'hospitality', sec == 'J' ~ 'info_comms',
    sec == 'K' ~ 'finance', sec == 'L' ~ 'real_estate', sec == 'M' ~ 'professional',
    sec == 'N' ~ 'admin_support', sec %in% c('O', 'P', 'Q') ~ 'public_providential',
    sec %in% c('R', 'S') ~ 'arts_personal')
  if (anyNA(g)) stop('Unassigned products: ', paste(cpa[is.na(g)], collapse = ', '))
  g
}

io_group_labels <- tribble(
  ~group, ~group_name, ~foundational, ~limit,
  'agri_fish', 'Agriculture, forestry and fishing', 'Material foundational', 'Squeezed supplier',
  'mining', 'Mining, oil and gas', 'Tradable or basic', 'Tradable frontier',
  'food_drink', 'Food, drink and tobacco', 'Material foundational', 'Squeezed supplier',
  'light_mfg', 'Textiles, wood, paper, printing, furniture', 'Tradable or basic', 'Catch-up',
  'chem_pharma', 'Fuels, chemicals and pharmaceuticals', 'Tradable or basic', 'Tradable frontier',
  'metals_minerals', 'Plastics, minerals and metal products', 'Tradable or basic', 'Catch-up',
  'machinery_vehicles', 'Electronics, machinery, vehicles and repair', 'Tradable or basic', 'Tradable frontier',
  'utilities', 'Energy, water and waste', 'Material foundational', 'Catch-up',
  'construction', 'Construction', 'Material foundational', 'Catch-up',
  'wholesale_motor', 'Wholesale and motor trades', 'Material foundational', 'Catch-up',
  'retail', 'Retail', 'Everyday services', 'Limited by local demand',
  'transport', 'Transport, storage and post', 'Material foundational', 'Catch-up',
  'hospitality', 'Accommodation and food service', 'Everyday services', 'Limited by local demand',
  'info_comms', 'Information and communication', 'Tradable or basic', 'Tradable frontier',
  'finance', 'Finance and insurance', 'Tradable or basic', 'Tradable frontier',
  'real_estate', 'Real estate (actual rents and fees)', 'Housing', 'Land rent',
  'professional', 'Professional, scientific and technical', 'Business services', 'Tradable frontier',
  'admin_support', 'Administrative and support services', 'Business services', 'Catch-up',
  'public_providential', 'Public administration, education, health, care', 'Providential (held fixed)', 'Held fixed',
  'arts_personal', 'Arts, recreation and personal services', 'Everyday services', 'Limited by local demand',
  'excluded', 'Left out: imputed rent, households as employers', 'Left out', 'Left out')
