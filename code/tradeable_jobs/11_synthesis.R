# Step 10 of the plan: put the results together. For every claim, say where it holds:
#   narrow benchmark (R0-R2: Ricardian, labour immobile between trading units, trade costs allowed)
#   broad benchmark (adds R3: Ricardo within a country, mobile labour and land)
#   and whether it needs increasing returns (localisation economies with coordination failure).
# Then a verdict for each version of the argument (V2020, RV2023, the policy shorthand) under each
# benchmark. The numbers quoted come from the outputs of scripts 01-10, read back here so the text and
# the tables can't drift apart. The classifications are judgements, made from those numbers.

source('code/tradeable_jobs/functions_common.R')
rd <- function(f) read_csv(file.path(tj_output_dir, f), show_col_types = FALSE)

pc   <- rd('v2020_parameter_check.csv')
abl  <- rd('v2020_ablations.csv')
imp  <- rd('v2020_import_competition.csv')
fis  <- rd('v2020_fiscal.csv')
boom <- rd('v2020_export_boom.csv')
dfs  <- rd('benchmark_dfs.csv')
bm   <- rd('benchmark_rv_engine.csv')
hys  <- rd('benchmark_agglomeration_hysteresis.csv')
t1   <- rd('rv2023_table1.csv')
t2   <- rd('rv2023_table2a.csv')
uk_r <- rd('uk_regressions.csv')
uk_c <- rd('uk_correlations.csv')
uk_h <- rd('uk_horse_race.csv')
lev_c <- rd('leverage_cost_saving.csv')
lev_p <- rd('leverage_cluster_premium.csv')
mbc  <- rd('v2018s3_compare.csv')

f1 <- function(x) formatC(x, format = 'f', digits = 1); f2 <- function(x) formatC(x, format = 'f', digits = 2)
abl_row <- function(pattern) abl[grepl(pattern, abl$variant, fixed = TRUE), ][1, ]
bm_row <- function(pattern) bm[grepl(pattern, bm$variant, fixed = TRUE), ][1, ]
base <- abl_row('Base case'); noagg <- abl_row('No agglomeration'); immob <- abl_row('Immobile labour'); sat <- abl_row('used up')
r3 <- bm_row('RV2023 as published'); nar <- bm_row('Immobile labour, no land'); notr <- bm_row('No variation in tradability')
dfs_base <- dfs[dfs$case == 'Baseline', ]; dfs_imp <- dfs[grepl('^Import', dfs$case), ]; dfs_tr <- dfs[grepl('^Transfer', dfs$case), ]
uk_main <- uk_r %>% filter(measure == 'Sparsity bias (skewness, as paper)', sample == 'All')
uk_tb <- uk_r %>% filter(measure == 'Export-share bias (input-output tables)', sample == 'All', model == 'Mean hourly earnings')
uk_exl <- uk_r %>% filter(measure == 'Sparsity bias, sector skewness computed without London', sample == 'All', model == 'Mean hourly earnings')
cor_sk_es <- uk_c$rebuild[grepl('export share\\)$', uk_c$statistic)][1]
horse_tb <- uk_h %>% filter(outcome == 'w_i', term == 'TB_exports')
exp_ext <- fis %>% filter(direction == 'expansion', financing == 'external')
con_ext <- fis %>% filter(direction == 'contraction', financing == 'external')
con_bal <- fis %>% filter(direction == 'contraction', financing == 'balanced')
boom_new <- boom %>% filter(boom == 'new sector only')

# CLAIMS ----
claims <- tribble(
  ~id, ~claim, ~versions, ~narrow, ~broad, ~needs_IRS, ~category, ~evidence,
  'C1', 'Each place specialises in tradables or non-tradables', 'V2020', 'no', 'no', 'yes',
  'c: needs increasing returns (the split itself is Ricardian)',
  sprintf('In DFS the tradable/non-tradable split is endogenous (%s%% of goods non-traded) but every country makes both. In Model A without agglomeration cities are indifferent about what they make.', f1(100 * dfs_base$nontraded_share)),
  'C2', 'A range of equilibria; history decides how many places are tradable', 'V2020', 'no', 'no', 'yes',
  'c: increasing returns with coordination failure (Graham 1923, Ethier 1982)',
  sprintf('Model A: the set runs from %s%% to %s%% of cities; with no agglomeration it collapses to one point. DFS and the RV2023 engine (agglomeration up to 0.025) have one equilibrium.', f1(base$E), f1(base$X)),
  'C3', 'Places that lose tradables get non-tradable jobs, not new tradables, and stay that way', 'V2020, policy', 'partly', 'partly', 'yes',
  'a for the shift to non-tradables; c for its persistence',
  sprintf('In DFS an import shock also raises the non-traded share (%s%% to %s%%) but through a %s%% fall in the relative wage, and it reverses exactly. In Model A no lost tradable city is replaced while the economy stays in the set (shocks up to %s points); without agglomeration all 5 of 5 are replaced. In the RV2023 engine a shocked sector returns in full when the shock is reversed.', f1(100 * dfs_base$nontraded_share), f1(100 * dfs_imp$nontraded_share), f1(100 * (1 - dfs_imp$omega)), f1(base$width)),
  'C4', 'The loss hurts every non-tradable place and booms the remaining tradable ones; the rent share rises', 'V2020', 'n/a', 'partly', 'for persistence',
  'b: dependent-economy price channel plus Rosen-Roback; c for persistence',
  sprintf('Model A, X to 45%%: wage in type-N cities %s%%, their population %s%%, their rents %s%%, type-T wage +%s%%, rent share +%s points. The channel (a national price for non-tradables) is the Salter-Swan one.', f1(base$wN_change_pct), f1(base$LN_change_pct), f1(base$RN_change_pct), f1(base$wT_change_pct), f2(base$rent_share_change_pts)),
  'C5', 'A boom in some tradables knocks out other tradable places (Dutch disease)', 'V2020', 'yes', 'yes', 'for persistence',
  'b: Dutch disease (Corden and Neary 1982); c for the lock-in',
  sprintf('Model A with two tradable sectors: old-sector cities start dropping into non-tradables when the new sector\'s price is %s%% higher; beyond about +12%% the rest convert to the new sector instead. If both sectors boom no city switches.', f1(100 * (min(boom_new$pW[boom_new$count_O < 20 - 1e-6], na.rm = TRUE) - 1))),
  'C6', 'Too few tradable places lowers aggregate real income', 'V2020', 'no', 'no', 'yes, and more',
  'c, and only if agglomeration runs out at the margin',
  sprintf('With the papers\' own linear agglomeration, real income is %s%% HIGHER at the low edge of the set. It is %s%% lower only when agglomeration is used up beyond the size at X.', f2(base$U_E_vs_X_pct), f2(-sat$U_E_vs_X_pct)),
  'C7', 'Fiscal contraction shrinks non-tradable places and booms tradable ones, in two regimes', 'V2020', 'partly', 'partly', 'for the regimes',
  'b: real depreciation (Salter-Swan; DFS transfer problem); c for the two regimes',
  sprintf('Model A, paper\'s financing: type-N cities start switching to tradables at G = %s; with a balanced budget none switch by G = -25. DFS: a transfer abroad lowers the relative wage %s%%, with no regimes.', f1(con_ext$G[which(con_ext$MT > 40 + 1e-6)[1]]), f1(100 * (1 - dfs_tr$omega))),
  'C8', 'Inside a country, absolute advantage rules; immobile factors are too small a cost share to restore competitiveness', 'V2020, RV2023', 'premise', 'premise', 'no',
  'a: Ricardo, "On Foreign Trade" (capital moves between provinces); the size claim is conditional',
  sprintf('UK bottom-quartile areas pay %s%% less for the same jobs; with property costs, unit costs are %s-%s%% lower. Cluster premiums: %s-%s%% (elasticity 0.02-0.04, size ratio 10-100). Model A\'s own gap at E is %s%%.', f1(mean(lev_c$wage_saving_pct)), f1(min(lev_c$unit_cost_saving_pct)), f1(max(lev_c$unit_cost_saving_pct)), f1(min(lev_p$cluster_premium_pct[lev_p$elasticity %in% c(0.02, 0.04) & lev_p$cluster_size_ratio %in% c(10, 100)])), f1(max(lev_p$cluster_premium_pct[lev_p$elasticity %in% c(0.02, 0.04) & lev_p$cluster_size_ratio %in% c(10, 100)])), f1(pc$q_gap_at_Tmin_pct[2])),
  'C9', 'An advantage in tradables raises local nominal wages; one in non-tradables can lower them', 'RV2023, policy', 'half', 'yes', 'no',
  'b: Balassa-Samuelson inside a Rosen-Roback spatial equilibrium',
  sprintf('RV2023 engine (R3): log wage on tradable advantage %s, on non-tradable advantage %s. Narrow benchmark (immobile labour): %s and %s, so no sign reversal. Equal trade costs: %s and %s.', f2(r3$wage_on_tradable_advantage), f2(r3$wage_on_nontradable_advantage), f2(nar$wage_on_tradable_advantage), f2(nar$wage_on_nontradable_advantage), f2(notr$wage_on_tradable_advantage), f2(notr$wage_on_nontradable_advantage)),
  'C9r', 'Places with tradable jobs are better off in real terms', 'policy', 'no', 'no', 'yes (or immobile people)',
  'false in both benchmarks; needs increasing returns or immobile people',
  sprintf('Narrow benchmark: real income responds about equally to advantage in tradables (%s) and non-tradables (%s). Broad benchmark: utility barely moves with either (%s, %s) because mobility equalises it.', f2(nar$utility_on_tradable_advantage), f2(nar$utility_on_nontradable_advantage), f2(r3$utility_on_tradable_advantage), f2(r3$utility_on_nontradable_advantage)),
  'C10', 'Measured (revenue) productivity can diverge from physical productivity', 'RV2023', 'no', 'yes', 'no',
  'b: revenue versus physical productivity (Hsieh and Klenow 2009) in spatial equilibrium',
  sprintf('Correlation of place wage (revenue productivity) with physical productivity: %s in the narrow benchmark, %s in R3, %s in R3 without land.', f2(nar$cor_wage_physical_productivity), f2(r3$cor_wage_physical_productivity), f2(bm_row('No land')$cor_wage_physical_productivity)),
  'C11', 'Sparsity bias accounts for about 75% of ITL3 earnings variation, two-thirds through the area effect', 'RV2023, policy', 'n/a', 'n/a', 'n/a',
  'replicated, but it does not identify tradability',
  sprintf('Rebuilt: adjusted R2 %s, area differential %s%% of the effect. But sector sparsity correlates only %s with export shares, and export-share bias adds nothing beside sparsity (t = %s). Computing sparsity without London lowers R2 to %s.', f2(uk_main$adj_r2[uk_main$model == 'Mean hourly earnings']), f1(100 * uk_main$coef[uk_main$model == 'Area differential'] / uk_main$coef[uk_main$model == 'Mean hourly earnings']), f2(cor_sk_es), f1(horse_tb$t), f2(uk_exl$adj_r2)),
  'C12', 'Places that lost sparsity bias in 1971-91 lost relative earnings', 'RV2023', 'n/a', 'n/a', 'n/a',
  'not tested here', 'Needs the Census of Employment 1971-91 and New Earnings Survey county tables: not rebuilt in this round.',
  'C13', 'Attracting non-tradable jobs crowds out tradables and locks places in', 'V2020, RV2023, policy', 'partly', 'partly', 'for the lock-in',
  'b: Dutch disease from public spending; c for the lock-in',
  sprintf('Model A: raising public spending on non-tradables (paper\'s financing) starts pushing tradable cities into non-tradables at G = +%s; by G = +25 the tradable share falls from 40%% to %s%%.', f1(exp_ext$G[which(exp_ext$MT < 40 - 1e-6)[1]]), f1(last(exp_ext$MT))),
  'C14', 'The gains go to landowners in booming places', 'V2020', 'n/a', 'yes', 'no',
  'a/b: Ricardo\'s own theory of rent; Rosen-Roback',
  sprintf('Model A import shock: rent share +%s percentage points; rents in type-N cities %s%%. Workers\' utility changes by %+.2f%%.', f2(base$rent_share_change_pts), f1(base$RN_change_pct), base$worker_u_change_pct)
)

# VERDICTS: each version of the argument against each benchmark ----
verdicts <- tribble(
  ~version, ~benchmark, ~verdict, ~why,
  'V2020: tradable = internationally traded and clustered', 'Narrow (R0-R2)', 'Adds something',
  'Its distinctive results (C1-C3 persistence, C6, the two fiscal regimes) need increasing returns with coordination failure, which R0-R2 lack. But its premise (C8) is Ricardo\'s own, and the increasing-returns machinery is Graham-Ethier-Krugman (1987) applied inside a country.',
  'V2020: tradable = internationally traded and clustered', 'Broad (with R3)', 'Adds something, narrowly',
  'R3 already gives the price channel (C4), Dutch disease (C5) and the landowners\' gains (C14). What is left is lock-in from increasing returns, which works through city size and the national price of non-tradables. Its welfare claim (C6) fails at the papers\' own parameters.',
  'RV2023: tradable = low trade costs within GB', 'Narrow (R0-R2)', 'Adds something',
  'With immobile labour there is no sign reversal (C9) and revenue tracks physical productivity (C10). Both need mobile labour, which is R3.',
  'RV2023: tradable = low trade costs within GB', 'Broad (with R3)', 'Mostly a restatement',
  'RV2023 is an R3 model by construction (Ricardian a_is, no increasing returns). What it adds is a mapping from comparative advantage to nominal wages and measured productivity, plus a measurement method (sparsity). The UK test replicates, but sparsity does not line up with measured tradability.',
  'Policy shorthand: places prosper by having tradable jobs', 'Narrow (R0-R2)', 'Nominal yes, real no',
  'Tradable advantage raises nominal wages and measured productivity, but real income responds about equally to advantage in non-tradables.',
  'Policy shorthand: places prosper by having tradable jobs', 'Broad (with R3)', 'Nominal yes, real no',
  'Mobility equalises utility, so "prosperity" can only mean nominal wages, GVA per head or landowners\' wealth. A real-income version needs increasing returns or immobile people, which are claims about agglomeration and labour markets, not about tradability.'
)

tj_write(claims, 'synthesis_claims.csv')
tj_write(verdicts, 'synthesis_verdicts.csv')
print(as.data.frame(claims %>% select(id, narrow, broad, needs_IRS, category)))
cat('\n'); for (k in seq_len(nrow(claims))) cat(claims$id[k], ':', claims$evidence[k], '\n\n')
print(as.data.frame(verdicts %>% select(version, benchmark, verdict)))
