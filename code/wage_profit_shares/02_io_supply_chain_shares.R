# Labour shares by product, own stage versus whole domestic supply chain
# Source: ONS UK input-output analytical tables 2023 (product by product, consistent with Blue Book 2025)
# Used in llm_output/wage_profit_shares_gva.md, sections 1, 3.2, 5.2 and 5.3,
# and in docs/chunks/wage_profit_shares/wage_profit_shares.qmd (which sources this script)
#
# Labour share here = compensation of employees / (compensation + operating surplus and mixed income).
# The IO tables don't separate mixed income, so it all counts as capital: this understates labour
# shares where self-employment is common (agriculture, construction, personal services, the arts)
source('code/wage_profit_shares/functions.R')

iot_path <- get_file(
  'https://www.ons.gov.uk/file?uri=/economy/nationalaccounts/supplyandusetables/datasets/ukinputoutputanalyticaltablesdetailed/2023/iot2023product.xlsx',
  'iot2023product.xlsx'
)


# READ THE IO TABLE----

# Sheet 'IOT': domestic use at basic prices, product by product, pounds million.
# Row 4 holds product codes across the columns, column 1 holds codes down the rows,
# and the primary input rows (imports, taxes, D1, GOS & MI ...) sit below the product rows
iot <- suppressMessages(read_excel(iot_path, sheet = 'IOT', col_names = FALSE, col_types = 'text'))

col_codes <- unlist(iot[4, ])
col_names <- unlist(iot[5, ])
row_codes <- iot[[1]]
row_names <- iot[[2]]

product_cols <- which(str_detect(col_codes, '^CPA'))
product_rows <- which(str_detect(row_codes, '^CPA'))

# Blank cells come through as text, so coercion warnings here are expected
primary_input <- function(label) {
  suppressWarnings(as.numeric(unlist(iot[which(row_names == label)[1], product_cols]))) %>% replace_na(0)
}

products <- tibble(
  code = col_codes[product_cols],
  product = col_names[product_cols],
  D1 = primary_input('Compensation of employees'),
  GOS = primary_input('Gross operating surplus and mixed income'),
  TaxP = primary_input('Taxes less subsidies on production'),
  GVA = primary_input('Gross value added'),
  imports = primary_input('Use of imported products, cif'),
  output = primary_input('Total output at basic prices')
)

Z <- iot[product_rows, product_cols] %>% mutate(across(everything(), ~ suppressWarnings(as.numeric(.x)))) %>% as.matrix()
Z[is.na(Z)] <- 0


# UK TOTALS----

io_totals <- products %>%
  summarise(across(D1:GVA, sum)) %>%
  mutate(across(D1:TaxP, ~ .x / GVA, .names = '{.col}_share'), pay_per_pound_surplus = D1 / GOS)
io_totals

# Owner-occupiers' imputed rent is almost all surplus, with no workers attached
owner_occ <- products %>% filter(code == 'CPA_L68A')
owner_occ$GVA / io_totals$GVA
io_totals$D1 / (io_totals$GOS - owner_occ$GOS)


# WHOLE-CHAIN LABOUR SHARES----

# Leontief: output needed per pound of final demand = (I - A)^-1, with A = Z / output.
# Pay and surplus content of a pound of each product's final demand = coefficient row vector x L.
# Imported inputs are left out because their pay and profit are earned abroad
A <- sweep(Z, 2, products$output, '/')
A[!is.finite(A)] <- 0
L <- solve(diag(nrow(A)) - A)

per_pound <- function(x) replace(x / products$output, !is.finite(x / products$output), 0)
d <- per_pound(products$D1)
g <- per_pound(products$GOS)

products <- products %>%
  mutate(
    own_ls = D1 / (D1 + GOS),
    chain_pay = as.vector(d %*% L),
    chain_surplus = as.vector(g %*% L),
    chain_ls = chain_pay / (chain_pay + chain_surplus)
  )

# Exclude owner-occupiers' housing (no labour by construction) and households as employers (no capital)
io_compare <- products %>% filter(GVA > 0, !code %in% c('CPA_L68A', 'CPA_T97'))

io_spread <- io_compare %>%
  pivot_longer(c(own_ls, chain_ls), names_to = 'measure', values_to = 'ls') %>%
  group_by(measure) %>%
  summarise(
    mean = weighted.mean(ls, GVA),
    sd = weighted_sd(ls, GVA),
    p10 = weighted_quantile(ls, GVA, 0.1),
    p50 = weighted_quantile(ls, GVA, 0.5),
    p90 = weighted_quantile(ls, GVA, 0.9)
  )
io_spread

cor(io_compare$own_ls, io_compare$chain_ls)
sum(io_compare$chain_ls < io_compare$own_ls)
nrow(io_compare)

# Lowest and highest own-stage labour shares, with the whole-chain equivalent
io_compare %>% arrange(own_ls) %>% select(code, product, GVA, own_ls, chain_ls) %>% print(n = 15)
io_compare %>% arrange(desc(own_ls)) %>% select(code, product, GVA, own_ls, chain_ls) %>% print(n = 12)


# WHERE A CHAIN'S SURPLUS ARISES----

# Supplier i's contribution to product j's chain surplus = g_i x L_ij
chain_surplus_sources <- function(product_code, top = 5) {
  j <- which(products$code == product_code)
  tibble(supplier = products$product, code = products$code, surplus = g * L[, j]) %>%
    mutate(
      share_of_chain = surplus / sum(surplus),
      share_of_supplier_surplus = if_else(code == product_code, NA_real_, surplus / sum(surplus[code != product_code]))
    ) %>%
    arrange(desc(code == product_code), desc(surplus)) %>%
    slice_head(n = top + 1)
}

chain_sources <- c('CPA_I56', 'CPA_H51', 'CPA_G47', 'CPA_C105', 'CPA_C107', 'CPA_Q86') %>%
  set_names(products$product[match(., products$code)]) %>%
  map(chain_surplus_sources)
chain_sources


# BY TYPE OF FINAL DEMAND----

# ONS's own table: primary input content per pound of each final use
final_use <- suppressMessages(read_excel(iot_path, sheet = 'Primary input from final use', col_names = FALSE, col_types = 'text'))

# The first block holds coefficients: final use names in row 5, input labels in column 2, values in rows 7-12
final_use_coef <- final_use[7:12, -1] %>%
  set_names(c('input', unlist(final_use[5, -(1:2)]))) %>%
  pivot_longer(-input, names_to = 'final_use', values_to = 'per_pound') %>%
  mutate(per_pound = as.numeric(per_pound)) %>%
  pivot_wider(names_from = input, values_from = per_pound)

final_use_shares <- final_use_coef %>%
  transmute(final_use, labour_share = D1 / (D1 + `GOS & MI`), import_content = `Use of imported products, cif`) %>%
  arrange(desc(labour_share))
final_use_shares
