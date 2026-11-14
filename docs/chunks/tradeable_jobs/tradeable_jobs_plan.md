# Tradeable jobs: reading and modelling plan

Started 13 November 2026 by Claude Code (Opus 5.5), at Dan's request. **Status (14 November 2026): carried out.** The results are in [tradeable_jobs_firstlook.qmd](tradeable_jobs_firstlook.qmd) and its HTML. The plan below is kept as written; a summary of results follows, and the script table (4.1), the list of things to check (2.4) and the log are updated.

**The question.** Does the tradeable jobs argument really add anything to plain Ricardian trade theory, or is it just a restatement of comparative advantage?

The file has five parts:

1. The papers, and where the readable copies are.
2. What each paper argues, the claims to test, and things to check that turned up while reading.
3. The question broken into steps.
4. A plan to rebuild the models in R.
5. Order of work and decisions for Dan.

This picks up the roadmap item in the repo README, "Tradeable vs foundational, how to think about difference".

## Results in brief

All of this was tested against both definitions of "plain Ricardian" and all three versions of the argument (decisions in part 5). The details are in the report.

- **V2020's version adds something, but less than it seems.**
    - Its premise (C8, absolute advantage inside a country) is Ricardo's own.
    - Its distinctive results need increasing returns with coordination failure. With agglomeration switched off, the range of equilibria collapses and lost tradable cities are replaced at once.
    - Its welfare claim (C6, too few tradable places) fails at the papers' own parameters: fewer tradable cities *raise* aggregate real income by 1.45%. It holds only if agglomeration runs out at the margin.
- **RV2023 is the broad Ricardian benchmark.** It is Ricardian productivity plus trade costs, land and mobile labour.
    - Against the narrow benchmark, it adds the sign reversal (a non-tradable advantage lowers nominal wages) and the gap between revenue and physical productivity. Both need mobile labour.
    - Against the broad benchmark, it is mostly a restatement plus a measurement method.
- **The policy shorthand is right in nominal terms and wrong in real terms in both benchmarks.**
    - With immobile labour, real income responds about equally to productivity in tradables (0.32) and non-tradables (0.29).
    - With mobile labour, utility is equalised.
- **The UK replication matches the paper.** R² 0.735 against 0.74, and 65% of the effect through the area differential against 65%.
    - But sparsity correlates only 0.33 with exports as a share of output, and an export-based measure adds nothing beside it (t = −0.3).
    - The 1971–91 test (C12) is not rebuilt.
- **Leverage (C8).** Lagging UK areas are 5–9% cheaper in unit costs for the same jobs. That is enough against modest clusters, but not against strong ones or Venables's calibrated 23% gap.

## 1. The papers

| Short name | Paper | Version we have | Pages | What it does |
|---|---|---|---|---|
| V2020 | Venables, A.J. (2020), "Why some places are left behind: urban adjustment to trade and policy shocks", *Oxford Review of Economic Policy* 36(3), 604–620 | Oxford Economics Discussion Paper 903, February 2020 | 21 | The paper usually cited for the idea. A one-factor model of cities that make either tradables or non-tradables; import competition, export booms and fiscal policy. |
| V2018 | Venables, A.J. (2018), "Globalisation and urban polarisation", *Review of International Economics* 26(5), 981–996 | CEP Discussion Paper 1707 (dated July 2020) | 24 | The same core model (section 2), with figures for rents and real incomes. Section 3 adds two tradable sectors and two skill types. |
| RV2023 | Rice, P.G. and A.J. Venables (2023), "Tradability, productivity, and regional disparities: theory and UK evidence" | Oxford Economics Discussion Paper 996, January 2023. Also CEPR DP17806; an earlier version is The Productivity Institute WP 021 (2022). | 57 | A many-place, many-sector model with Ricardian productivity differences, trade costs and land, tested on UK data: BRES employment and ASHE earnings for 163 ITL3 areas and 259 SIC 3-digit sectors. |

**Where the copies are.** Everything is in the gitignored `local/` folder:

- PDFs: `local/tradeable_jobs/papers_raw/<short name>/`.
- Readable markdown: `local/tradeable_jobs/papers_md/venables2020_left_behind.md`, `venables2018_urban_polarisation.md` and `rice_venables2023_tradability.md`. Pages with figures are in `papers_md/img/`.
- Plain text: `local/tradeable_jobs/text/`.

They stay out of git because the papers are copyright and this repo is public. The Oxford archive copies come under its terms of use, and the CEP paper says "all rights reserved". To rebuild all of it, run `python3 -I code/tradeable_jobs/get_papers.py` from the repo root.

**What "readable" means here.**

- The script reflows the prose and keeps footnotes as quoted blocks after the paragraph they interrupt.
- It replaces each figure's axis-label text with an image of the page.
- It maps the Symbol-font characters that `pdftotext` leaves as blanks in the 2018 paper back to θ, −, =, ≥ and the rest. Without this, its equations lose their operators.
- Equations and tables stay in fixed-width blocks. Subscripts and superscripts are flattened onto the line, so "bPL2i" means $bPL_i^2$. For the maths, read the PDF or section 2.2 below, where the equations are written out by hand.

**Versions.** These are working-paper versions. The CEPR copies are behind a Cloudflare check, so I used the Oxford and CEP ones instead.

If you have library access to the published ORE and RIE versions, check the typos in 2.4 against them before quoting parameter values.

**To get next.** I haven't downloaded these:

- Rice, P.G. and A.J. Venables (2021), "The persistent consequences of adverse shocks: how the 1970s shaped UK regional inequality", *Oxford Review of Economic Policy* 37(1), 132–151. This is the history behind RV2023 section 5.
- Venables, A.J. (2017), "Breaking into tradables: urban form and urban function in a developing city", *Journal of Urban Economics* 98, 88–97. It covers the first-mover problem for a single city.
- Ricardo, D. (1817), *On the Principles of Political Economy and Taxation*, chapter "On Foreign Trade". That's chapter 6 in the 1817 first edition and chapter 7 in the 1821 third edition. It's public domain (Project Gutenberg ebook 33310), and the passage quoted in part 3 was checked against it.
- The benchmark and precursor papers listed under step 1 in part 3.

## 2. What the papers argue

### 2.1 Reading order

1. **V2020 first.** It's the shortest and most policy-facing version.
2. **V2018 next.**
    - Section 2 is the same model as V2020, but with clearer figures of rents and real incomes.
    - Section 3 adds a second tradable sector and a second factor, so trade shocks change relative prices and skill premia.
3. **RV2023 last.** It drops agglomeration, adds Ricardian place-by-sector productivity, trade costs and land, and takes the theory to UK data.

The papers use "tradable" in two different senses. The difference matters for the question.

- **V2018 and V2020: tradable means traded internationally.**
    - Tradables sell at world prices. "Non-tradables" are traded freely *within* the country at a national price, so non-tradable cities export to the rest of the country.
    - The tradable sectors are also, by assumption, the only ones with agglomeration economies.
    - Venables flags this bundling in V2020's conclusion: the results come over starkly "because of the assumption that tradability and agglomeration go together".
- **RV2023: tradability is a continuum of trade costs between places within Great Britain.** Shipping abroad costs the same as shipping to another place. There are no agglomeration economies.

The policy shorthand "tradeable jobs" mixes the two senses.

### 2.2 The models

#### V2020 and V2018 section 2: tradable and non-tradable cities

**Set-up.**

- A small open economy has $M$ cities and $L$ workers.
- Each city makes either tradables (type-T, $M_T$ of them) or non-tradables (type-N, $M - M_T$).
- Tradables sell at a fixed world price $p_T$, and productivity rises with the city's tradable employment, $q(L_T)$, with $q(0) = 1$.
- Non-tradables have constant returns, one unit of output per worker, and a national price $p_N = w_N$.
- Workers move freely between cities and live and work in the same city. Urban costs (commuting plus rent) rise linearly with city size at rate $b$.

**Equations.** For a given $M_T$, numbered as in V2020:

$$w_T = p_T\, q(L_T) \qquad (1)$$

$$L = M_T L_T + (M - M_T) L_N \qquad (2)$$

$$(M - M_T) L_N w_N = \theta\,[M_T L_T w_T + (M - M_T) L_N w_N] + G \qquad (3)$$

$$P = p_T^{1-\theta} w_N^{\theta} \qquad (4)$$

$$w_T - bPL_T = w_N - bPL_N \qquad (5)$$

What each one means:

- **(3)** clears the national market for non-tradables. $\theta$ is the expenditure share and $G$ is net government spending on non-tradables.
- **(5)** is the mobility condition: utility $u_i = (w_i - bPL_i)/P$ is equal across city types.
- **Rents.** In a linear city the real rent per city is $R_i = bL_i^2/2$.

**Equilibrium set.** Any $M_T$ between two edges is an equilibrium:

- **E (V2018's Tmin):** $w_N = p_T q(0)$. Below this, a lone tradable firm can break even in a type-N city.
- **X (Tmax):** $w_T = w_N$. Above this, type-T cities would switch to non-tradables.

The gap exists because of agglomeration plus the first-mover problem. With $G = 0$, X sits at $M_T/M = 1 - \theta$.

**Shocks.** Import competition moves the economy left within the set. Fiscal policy shifts the set itself.

**Parameters** (both appendices): $L = M = 100$, $\theta = 0.5$, $b = 0.3$, $q(L_T) = 1 + 0.15 L_T$. V2020's appendix says 0.015; see 2.4.

#### V2018 section 3: two tradable sectors, two factors

**Set-up.**

- Cities are type A, B or N.
- There are two factors, $L$ and $K$. $K$ is the skilled one: sector A, with the lowest $L$ share, is called the most skill intensive.
- Production functions are $x_N = X_N(L_N, K_N)$ and $x_T = q(x_T)\,X_T(L_T, K_T)$ for $T = A, B$. Firms treat $q$ as given.

**Equations.**

- **Factor prices** equal marginal value products. For example, $w_T = p_T q(x_T)\,\partial X_T/\partial L_T$.
- **Non-tradables market:** $(M - M_A - M_B)p_N x_N = \theta[M_A p_A x_A + M_B p_B x_B + (M - M_A - M_B)p_N x_N]$.
- **Price index:** $P = p_N^{\theta} p_A^{\theta_A} p_B^{\theta_B}$.
- **Utilities**, equalised across city types for each factor:
    - $u^L_i = w_i/P - b(L_i + K_i)$;
    - $u^K_i = r_i/P - b(L_i + K_i)$.
- **Full employment** of each factor, and real rents $R_i = b(L_i + K_i)^2/2$.

**Equilibrium set.** This is the set of $(M_A, M_B)$ where no single small firm gains by switching sector. The conditions use unit costs $c_i(J)$ of sector $i$ at the factor prices of a city of type $J$:

$$p_N = c_N(N) \le c_N(A), c_N(B), \quad p_A = \frac{c_A(A)}{q_A(x_A)} \le \frac{c_A(B)}{q_A(0)}, \frac{c_A(N)}{q_A(0)}, \quad p_B = \frac{c_B(B)}{q_B(x_B)} \le \frac{c_B(A)}{q_B(0)}, \frac{c_B(N)}{q_B(0)}$$

In the $(M_A, M_B)$ plane this set is the "lozenge".

**Parameters.**

- $L = K = 50$, $M = 100$, $\theta = \theta_A = \theta_B = 1/3$, $b = 0.25$.
- Cobb-Douglas $L$ shares: $\lambda_A = 0.25$, $\lambda_N = 0.5$, $\lambda_B = 0.75$.
- $q(x) = 1 + 0.1x$.

**Shock.** $p_B/p_A$ falls from 1 to 0.8.

#### RV2023: Ricardian productivity, tradability and land

**Set-up.**

- There are $N$ places and $S$ sectors.
- Productivity $a_{is}$ is exogenous and specific to each place and sector. In the authors' words (footnote 3), "there are simply Ricardian productivity differences".
- Places have identical land supply curves.
- Goods are differentiated by place of origin (Armington), with elasticity $\sigma$.
- Trade costs $t_s$ are the same between any two places and to the rest of the world, and vary by sector. Tradability is $\tau_s \equiv t_s^{1-\sigma}$: 1 means freely traded, 0 means not traded at all.

**Equations**, numbered as in the paper:

$$p_{is} = w_{is}^{\gamma} r_i^{1-\gamma} / a_{is} \qquad (1)$$

$$P_{js} = \Big[p_{js}^{1-\sigma} + \textstyle\sum_{i \ne j} \tau_s\, p_{is}^{1-\sigma}\Big]^{1/(1-\sigma)} \qquad (2)$$

$$u_{js} = y_{js} \Big/ \Big[r_j^{\alpha} p_0^{\beta_0} \textstyle\prod_s P_{js}^{\beta_s}\Big] \qquad (3)$$

$$\beta_0 \textstyle\sum_i M_i = \sum_s \sum_i \tau_s (q\, p_{is})^{1-\sigma} \qquad (4)$$

$$x_{is} = p_{is}^{-\sigma} \beta_s \textstyle\sum_j M_j \tau_{ijs} P_{js}^{\sigma - 1} + (q\, p_{is})^{-\sigma} \tau_s \qquad (5)$$

$$L_{is} = \gamma\, p_{is} x_{is} / w_{is} \qquad (6)$$

$$r_i = \big[\alpha M_i + (1-\gamma) \textstyle\sum_s p_{is} x_{is}\big]^{1/(1+\eta)} \qquad (7)$$

$$y_{is} = w_{is} + \textstyle\sum_i r_i^{1+\eta} / L \qquad (8)$$

$$\pi_{is} = F(u_{is}) \Big/ \textstyle\sum_i \sum_s F(u_{is}), \qquad L_{is} = \pi_{is} L \qquad (9)\text{–}(10)$$

What each one means:

- **(1)** is the producer price, from Cobb-Douglas costs with labour share $\gamma$.
- **(2)** is the price index of sector $s$ goods in place $j$.
- **(3)** is utility: income divided by the cost of living.
- **(4)** sets the real exchange rate $q$ so that exports pay for imports. Imports have price $p_0$ and spending share $\beta_0$.
- **(5)** is total demand for place $i$'s sector $s$ good, domestic plus export.
- **(6)** is labour demand.
- **(7)** is the land rent, from a supply curve with elasticity $\eta$.
- **(8)** is income: the wage plus an equal share of all rents.
- **(9)–(10)** allocate workers across places and sectors. $F(u) = u^{\vartheta}$ comes from Fréchet preference draws with shape $\vartheta$; $\vartheta \to \infty$ is perfect mobility.

**Two results drive everything.**

The first is that the price elasticity of demand rises with tradability:

$$E_s = \sigma - (\sigma - 1)\mu_s[\mu_s + (1 - \mu_s)\tau_s], \qquad \mu_s = 1/\{1 + (N-1)\tau_s\} \qquad (11)$$

Here $\mu_s$ is the home market share. $E_s$ goes from 1 (not traded) to about $\sigma$ (freely traded).

The second is that, for a small productivity change $\hat a_s$ in one place, the local nominal wage moves by

$$\hat w = \frac{\hat u + \sum_s \beta_s \hat a_s \psi_s}{1 + \sum_s \beta_s \psi_s}, \qquad \psi_s \equiv \frac{\alpha}{1+\eta}\,\frac{E_s - 1}{\sum_s \beta_s(1 - \mu_s)} - \mu_s \qquad (13)$$

**What follows from (13).**

- An advantage in a tradable sector ($E_s$ large) raises the nominal wage, as long as land supply isn't perfectly elastic.
- An advantage in a non-traded sector ($\psi_s = -1$) lowers it.
- Utility moves by about zero, because labour is mobile.

**The empirical measures.**

- **Sector sparsity $SK_s$** is the skewness, across places, of $s_{is} - x_i$: the place's share of the sector's employment minus its share of all employment.
- **Place sparsity bias** is $SB_i = \sum_s SK_s \lambda_{is}$, where $\lambda_{is}$ is the sector's share of the place's employment.
- **Earnings** split as $w_i = (w_i - \tilde w_i) + (\tilde w_i - \bar w) + \bar w$, where $\tilde w_i = \sum_s w_s \lambda_{is}$ uses national sector wages.
    - $(\tilde w_i - \bar w)$ is the "sector differential": what sector mix alone predicts.
    - $(w_i - \tilde w_i)$ is the "area differential": the rest.

**Simulation parameters** (section 3.3 and appendix 1):

- $N = 300$ places and $S = 50$ sectors.
- $\sigma = 10$, $\eta = 1$, $\alpha = 0.25$, $\beta_0 = 0.1875$, $\beta_s = 0.011$, $\gamma = 0.9$.
- $t_s \in [1, 4]$, $a_{is} = 1 + N(0, 0.2)$ truncated at ±0.5, and Fréchet shape 50.
- **Two-skill version:** $a_A/a_B = 3$, CES between skills with $\rho = 0.5$, skill intensity $v_s \in [0.25, 0.75]$, and endowments of 30% skilled and 70% unskilled.

### 2.3 The claims to test

| # | Claim | Paper | Kind | What drives it |
|---|---|---|---|---|
| C1 | Each city specialises in tradables or non-tradables, never both | V2018 §2, V2020 §2 | positive | localisation economies in tradables only |
| C2 | The split between tradable and non-tradable cities isn't unique: any point in a range [E, X] is an equilibrium, and history picks it | V2018, V2020 | positive | increasing returns plus coordination failure (the first-mover problem) |
| C3 | A city that loses its tradable sector gains non-tradable jobs, not a new tradable sector, and full employment holds | V2018, V2020 | positive | as C2, with non-tradables as a constant-returns fallback |
| C4 | That loss hurts every non-tradable city (lower price of non-tradables, wages, population and rents) and makes the remaining tradable cities boom; the rent share of income rises | V2018, V2020 | positive and distributional | a national market for non-tradables; urban costs convex in city size |
| C5 | A boom in some tradable sectors can knock out other tradable cities (Dutch disease) | V2018 §3, V2020 §4 | positive | competition for mobile labour, then C3 |
| C6 | The economy can end up with too few tradable cities and lower aggregate real income | V2020 abstract and §3; V2018's example goes the other way (see 2.4) | welfare | whether agglomeration economies are used up at the margin |
| C7 | Fiscal contraction shrinks non-tradable cities and makes tradable ones boom (regime 1), until wages in type-N cities fall far enough for tradables to start there (regime 2) | V2020 §5 | positive | dependent-economy structure (tradables at world prices, non-tradables at a national price), plus C2 |
| C8 | Within a country a city's performance depends on absolute, not comparative, advantage, because labour mobility stops wages adjusting and immobile factors (land, housing) are too small a share of costs to make up the gap | V2018 introduction and conclusion, V2020 footnote 12 | positive | labour mobility |
| C9 | A productivity advantage in a highly tradable sector raises local nominal wages, rents and employment; the same advantage in a non-tradable sector can lower nominal wages | RV2023 §3 | positive (nominal) | demand elasticity rising with tradability; land supply less than perfectly elastic |
| C10 | Revenue productivity (what GVA per worker measures) can diverge from physical productivity, so high physical productivity in non-tradables shows up as *low* measured productivity | RV2023 §3 and §7 | measurement | as C9 |
| C11 | An area's sparsity bias accounts for about 75% of the spread in ITL3 earnings: roughly a third through sector mix and two-thirds through the area differential | RV2023 §4 | empirical | sparsity standing in for tradability |
| C12 | Areas that lost sparsity bias between 1971 and 1991 saw their relative earnings fall | RV2023 §5 | empirical | as C11 |
| C13 | Place policy that attracts non-tradable jobs (public sector, warehousing, call centres) speeds up decline elsewhere and locks places into low-value work | V2018 §4, V2020 §7, RV2023 §7 | policy | C3 and C4 |
| C14 | The gains from polarisation go to landowners in booming cities, and could be taxed | V2020 §7 | policy and distributional | C4 |

One assumption runs through all three papers: full employment, with perfect or near-perfect labour mobility. So a mobile worker ends up with the same utility wherever they live. "Left behind" in these models means landowners in type-N cities, and (outside the models) people who can't or won't move.

### 2.4 Things to check, found while reading

1. **The agglomeration slope.** V2020's appendix gives $q(L_T) = 1 + 0.015 L_T$; V2018 gives $1 + 0.15 L_T$, with all other parameters the same. I solved the model at both (4.2).
    - **0.15 reproduces V2018's reported numbers.** E comes out at 28.9% of cities, the productivity gap at E is 23% (reported 25%), and the population and rent ratios are 2.00 and 4.0 (reported 2.03 and 4.1). Total real income is 1.45% higher at E than at X (reported 1.4%).
    - **0.015 doesn't fit.** It shrinks the equilibrium set to 48–50% of cities. So 0.015 looks like a typo.
    - **The remaining small gaps** probably come from reading values off a grid near E. At E itself, $w_N = 1$ and $P = 1$, so (5) gives $0.15L_T = 0.3(L_T - L_N)$, which makes the population ratio exactly 2.
2. **Fewer tradable cities raise total real income in V2018's own example.** Its section 2.3 says total utility is 1.4% higher at Tmin than at Tmax, because the remaining tradable cities are bigger and get more scale economies; the check reproduces this. V2020 says there "may be aggregate loss". That needs agglomeration to be used up at the margin, which the linear $q$ never is. This matters for C6.
3. **V2020 rent formulas.** The text has real rent $bPL_i^2/2$, while the appendix writes total rent without the 1/2. It's a constant factor, but check it against the levels in Figure 3.
4. **V2020's two-skill mobility condition** (appendix) repeats $L_{TS} + L_{TU}$ on both sides of the second equation. Presumably the right-hand side should be $L_{NS} + L_{NU}$.
5. **V2020's appendix expression for $dM_T/dG$** has an unclosed bracket. Presumably it's $-\theta/((1-\theta)w_N L_N)$.
6. **How V2020's fiscal policy is financed.** $G$ is "net government expenditure on non-tradables", and fiscal contraction is $G < 0$, but the paper shows no budget constraint. Whether households pay for $G$ through taxes changes income in (3). Rebuild it both ways and see whether the two regimes survive.
7. **A subscript typo in V2018 (12).** The last condition divides $c_B(N)$ by $q_A(0)$; it should be $q_B(0)$.
8. **V2018 section 3 factor naming.** $L$ is the *less* skilled factor, because sector A has the lowest $L$ share and is called the most skill intensive. The naming is easy to misread when rebuilding.
9. **RV2023's productivity draws** are described three ways:
    - the text says unity plus a normal with mean 0 and *variance* 0.2, truncated at ±0.5;
    - the notes to Tables 2a and 2b say $1 + N(1, 0.2)$ and $N(1, 0.2)$, truncated at 0.5 and 1.5.

    With variance 0.2 (sd 0.45) the truncation cuts about a quarter of the draws. Try the readings against Table 2a.
10. **RV2023 Table 1's spending shares don't add up.** Its footnote gives $\alpha = \beta_s = 0.25$, but with nine sectors and no imports the shares then can't sum to one. Probably $\beta_s = 0.75/9$; check by rebuilding Table 1.
11. **RV2023 treats rent two ways.** Equation (8) shares all rent equally across the country, but the comparative statics in (12)–(13) assume rent is spent where it's earned. Check how much this matters.
12. **RV2023 (4) mixes currencies.** It equates imports in domestic currency with exports written as $\tau_s(q p_{is})^{1-\sigma}$, which is a foreign-currency value. Check the units when coding.
13. **An RV2023 Table 6 typo.** The 1982/83 confidence interval (0.224, 0.552) doesn't contain the estimate 0.12.
14. **RV2023's sparsity measure includes London.** $SK_s$ is computed across all 163 areas, so sectors concentrated in London (finance, broadcasting) get high sparsity and lift London's sparsity bias. The robustness check drops London *areas* but keeps London in $SK_s$. Recompute without London.

**What the rebuild found on these** (14 November 2026):

- **Item 1:** confirmed. 0.15 reproduces V2018; 0.015 shrinks the set to 48–50%.
- **Item 6:** the financing matters. With a balanced budget, no city switches by G = −25.
- **Item 9:** sd 0.2 reproduces the paper's correlations and wage range; variance 0.2 doesn't.
- **Item 10:** Table 1 is only partly reproduced. Wages match under every reading, but place 1's population and rent don't.
- **Item 12:** the rebuild uses the domestic-currency value of exports.
- **Item 14:** R² falls from 0.73 to 0.53 when London is left out of sector sparsity.

New items, found while rebuilding:

15. **V2018 section 3's agglomeration slope.** The stated 0.1 gives an equilibrium set far smaller than Figures 4 and 5; 0.3 reproduces them.
16. **V2018 Figure 6's rents for B and N cities.** These differ in the figure, but conditions (9) make B and N cities identical on the exit-B boundary. Unexplained.
17. **RV2023 Table 1's coefficient of variation (0.39).** This can't be right if half of place 1's workers are in sector 1 (footnote 13). Any standard coefficient of variation across nine sectors is then above 1.2.
18. **V2018 section 2's "throughout the equilibrium range".** Workers' utility relative to rents rises only up to about 48% of cities, then dips slightly before X.

## 3. The question, step by step

**What counts as an answer.** For each claim in 2.3, say where it first appears:

- (a) already in plain Ricardian theory;
- (b) in a standard extension of it;
- (c) only with increasing returns;
- (d) new.

The tradeable jobs argument "adds something" if claims in (c) or (d) matter for policy and the evidence supports them.

**Two things from the reading shape the steps.**

**First, the papers' target is not Ricardo.** V2018 and V2020 argue against "naive faith in adjustment occurring because 'everywhere has a comparative advantage'". The 2018 version puts it as "true, but irrelevant in an integrated economy".

Ricardo himself said comparative advantage governs trade *between* countries, not within them, because capital and labour move inside a country. In chapter "On Foreign Trade" of the 1817 first edition, which was checked against the Project Gutenberg text:

> "In one and the same country, profits are, generally speaking, always on the same level ... If the profits of capital employed in Yorkshire, should exceed those of capital employed in London, capital would speedily move from London to Yorkshire."

And:

> "The difference in this respect, between a single country and many, is easily accounted for, by considering the difficulty with which capital moves from one country to another, to seek a more profitable employment, and the activity with which it invariably passes from one province to another in the same country."

So C8's premise is Ricardo's own. The question becomes whether the tradeable jobs argument is Ricardo's logic applied correctly to regions with mobile labour (plus increasing returns), or something more than that.

**Second, "tradable" means different things in V2020 and RV2023** (see 2.1). The steps keep the two apart.

### Step 1. Fix the benchmarks

Define what "plain Ricardian trade theory" means here, from narrowest to broadest:

- **R0. Ricardo (1817).** Two countries, with labour immobile between them and constant returns. Comparative advantage decides who makes what, absolute advantage decides relative wages, and both countries gain from trade.
- **R1. Dornbusch, Fischer and Samuelson (1977, *AER* 67(5)).** A continuum of goods with transport costs.
    - A band of goods becomes non-traded endogenously, so the split between tradable and non-tradable is itself Ricardian.
    - Shocks move the relative wage and the margin of specialisation.
- **R2. Eaton and Kortum (2002, *Econometrica* 70(5)); Costinot, Donaldson and Komunjer (2012, *REStud* 79(2)).** Many places, giving gravity trade. RV2023's Armington set-up gives the same gravity structure.
- **R3. "Spatial Ricardo".** R1 or R2 between regions of one country, with mobile labour and immobile land.
    - Sources: Rosen (1979), Roback (1982, *JPE* 90(6)), Allen and Arkolakis (2014, *QJE* 129(3)), and the survey by Redding and Rossi-Hansberg (2017, *Annual Review of Economics* 9).
    - RV2023 is an R3 model.

**Proposal.** Treat R0–R2 as "plain Ricardian". R3 is the fair benchmark for an argument about regions inside one country, because R3 is what Ricardo's own reasoning says happens there.

**Extensions to place each claim against** (category b or c):

- **Increasing returns in Ricardian models.**
    - Graham (1923, *QJE* 37(2)) and Ethier (1982, *Econometrica* 50(5)).
    - Krugman (1987), "The narrow moving band, the Dutch disease, and the competitive consequences of Mrs. Thatcher" (*Journal of Development Economics* 27). With dynamic scale economies, a temporary shock (a resource boom or an overvalued exchange rate) can remove sectors for good. That's V2020's story, between countries and applied to the UK.
- **Multiple equilibria, and history versus expectations:** Krugman (1991, *QJE* 106(2)) and Matsuyama (1991, *QJE* 106(2)).
- **The dependent economy.** In V2020's set-up tradables have world prices, non-tradables have a national price, and the real exchange rate links them, as in Salter (1959) and Swan (1960). The Balassa (1964) and Samuelson (1964) effect, where productivity growth in tradables raises the price of non-tradables, is the national version of RV2023's mechanism.
- **Economic geography:** Krugman (1991, *JPE* 99(3)).
- **Export base, multipliers and the big push:** North (1955) and Tiebout (1956), Moretti (2010), and Kline and Moretti (2014, *QJE*, the Tennessee Valley Authority).
- **Regions compete on absolute advantage:** Camagni (2002, *Urban Studies* 39(13)), the regional-science version of C8, and Krugman (1994, *Foreign Affairs*) on competitiveness.
- **Geographic concentration as a measure of tradability:** Jensen and Kletzer (2005, Brookings Trade Forum). This is the same idea as RV2023's sparsity.

**Output:** a short note giving each benchmark's prediction for V2020's experiments: a negative shock to one sector, a boom in one sector, and a fiscal contraction. R1 and R3 also get built in code (Model D in part 4).

### Step 2. Agree the claims

- **Dan:** mark which claims in 2.3 count as "the tradeable jobs argument" as it's used in UK policy debate, so the test is of the argument people actually make.
- **Separate the claim types:** nominal claims (wages, GVA per head), real ones (utility), welfare ones (aggregate real income, distribution) and policy ones. Many disagreements dissolve once that's done.

**Output:** the agreed claim list.

### Step 3. Comparative and absolute advantage within a country (C8)

1. **Spell out Ricardo's position** (quoted above) and what it implies: inside a country with mobile factors, the relevant comparison is absolute advantage.
2. **Show it in R3.**
    - With no immobile factor, a region that's worse at everything makes nothing and empties.
    - Add land and the region survives, with lower rents. Comparative advantage then works only through the immobile factor. How much it can do depends on that factor's share of costs: as an input (RV2023's $1-\gamma$), in living costs ($\alpha$) and through the supply elasticity ($\eta$).
3. **Derive V2020's re-entry condition.** A type-N city gets tradables back only when $w_N \le p_T q(0)$, and $w_N$ is set nationally. So in V2020 the escape route is the national price of non-tradables, not local land prices; local land only makes cities shrink.
4. **Put UK magnitudes on it.**
    - On the cost side: the housing share of household spending, the land and property share of business costs, and the observed spread of nominal wages and rents across ITL3 areas.
    - On the productivity side: plausible first-mover productivity gaps, from agglomeration elasticities such as those reviewed by Combes and Gobillon (2015).
    - The question: is "too small a share of costs to have leverage" true at UK magnitudes?

**Output:** C8 stated as an explicit condition, and whether UK magnitudes meet it.

### Step 4. Separate tradability from increasing returns (C1–C7)

In V2020, tradables are by assumption the only sector with agglomeration economies. Run ablations on Model A to see which claims survive:

1. **Agglomeration off** ($q' = 0$). The equilibrium set should collapse to X, and a city that's hit should switch costlessly. Check whether C2–C6 disappear.
2. **Agglomeration in non-tradables too.** For example, business services that cluster but sell nationally.
3. **Tradables without agglomeration but with Ricardian city differences.** This is back to R3.
4. **No non-tradable fallback** ($\theta \to 0$).
5. **Immobile labour** (fixed city populations).
    - Wages in a hit city can then fall until tradables return: the international adjustment story.
    - Compare real incomes with the mobile case. This shows what mobility gives and what it takes away.
6. **Agglomeration that runs out** ($q$ flat above some city size), for C6.

**Output:** a table of which ingredient each claim needs.

### Step 5. RV2023 as a Ricardian model (C9, C10)

RV2023 is Ricardian by construction. What it adds is the link from *where* comparative advantage lies to nominal wages and measured productivity.

1. **Show that (13) is a regional Balassa–Samuelson effect inside a Rosen–Roback spatial equilibrium.**
    - Productivity in tradables bids up the local price of what isn't traded (land), and mobility turns that into higher nominal wages, not higher utility.
    - Write out the mapping term by term.
2. **Run ablations on Model C.**
    - Equal $t_s$, so tradability doesn't vary. The paper reports that the effect becomes insignificant once the range of $t_s$ is cut to a third.
    - $\eta \to \infty$, $\alpha \to 0$, immobile labour, and all $a_{is} = 1$.
3. **Check Armington's role.**
    - Place-specific varieties mean every place sells something, so the preferences build in "everywhere has a comparative advantage".
    - Push $\sigma$ up towards homogeneous goods, where specialisation is all-or-nothing as in Ricardo, and see what changes.

**Output:** a statement of what tradability adds to a Ricardian model with land. The expected answer is the *sign* of the nominal wage response, and the gap between revenue and physical productivity.

### Step 6. Lock-in and multiple equilibria (C2, C3, C5) against trade theory with increasing returns

- **Read Graham, Ethier and Krugman (1987) alongside V2018 section 3.**
- **Compare where the lock-in comes from.**
    - In Krugman (1987), specialisation is locked in by learning and shifted by temporary shocks.
    - In V2020, lock-in comes from city-level localisation economies, and labour mobility removes the wage fall that could otherwise bring tradables back.
- **Ask what the within-country setting adds** that two-country Ricardian models with increasing returns don't have. Candidates:
    - the national non-tradables channel that spreads a shock to every type-N city (C4);
    - who captures the rents (C14);
    - the two fiscal regimes (C7).

**Output:** a comparison table.

### Step 7. Who is better off (C6, C9, C14)

1. **Tabulate, for each experiment and model,** workers' utility, rents by city type, and aggregate real income.
2. **Reconcile V2018 and V2020 on welfare.** In V2018's own example, fewer tradable cities raise total real income while shifting income from workers to landowners (2.4, item 2). Find the conditions under which V2020's "aggregate loss" holds.
3. **Read RV2023 Table 1 for welfare.** Place 9 is the most productive in the least tradable sector. It has a lower nominal wage (0.98) but 26% more workers, and the same utility as everywhere else, so it isn't "left behind".
    - This bears on using GVA per head or nominal earnings as a policy target.
    - It links to the repo's regional GVA chunks and the deflator item on the README roadmap.
4. **List what the models leave out** that the policy argument leans on: people who can't move, unemployment, local public finances, skills and aspirations. V2020 section 6 lists most of these.

**Output:** what "left behind" means in each model, and what has to be added for it to mean what policy means by it.

### Step 8. Evidence (C11, C12)

Can RV2023's UK result tell the tradable story apart from the alternatives?

1. **Replicate it with open data.**
    - Employment: BRES at ITL3 by SIC 3-digit, from Nomis.
    - Earnings: ASHE by ITL3 and by SIC 3-digit, using the tables listed in RV2023 appendix 2, for 2015 to 2019.
2. **Measure tradability without using concentration.**
    - Possible sources: export shares by industry from the ONS input-output analytical tables, ONS subnational trade estimates, and the Jensen–Kletzer approach.
    - Check whether sparsity lines up with them.
3. **Generate fake data from Model D** under models with no tradability mechanism, for example skill sorting plus one large agglomeration standing in for London. Check whether a correlation of sparsity bias with earnings near 0.86 still appears.
4. **Recompute $SK_s$ without London** (2.4, item 14).
5. **Compare with worker-level decompositions** (Overman and Xu 2022, IFS Deaton Review).

**Output:** whether the evidence distinguishes the mechanisms, and how strongly.

### Step 9. Policy (C13, C14)

1. **In Model A, test C13.** Put a non-tradable employer, or government spending, into one type-N city and check whether wages fall in every type-N city.
2. **Model a "big push".** Coordinated entry of tradables into a type-N city: what does it cost and what does it gain?
3. **Compare with R3's prescription.**
4. **Connect to UK practice:**
    - civil service moves under Places for Growth;
    - investment zones and freeports;
    - the foundational economy view (Foundational Economy Collective 2018), which puts the weight the other way.

### Step 10. Synthesis

- Build the table of claims by benchmarks (R0–R3, then R plus increasing returns), marking where each claim first appears, and give a verdict on the question.
- Write it up as this chunk's Quarto document.

### Preliminary view, to test rather than to rely on

- **H1.** On C8 the argument restates Ricardo rather than departing from him. The target of the critique ("everywhere has a comparative advantage") is a misapplication of Ricardo to regions.
- **H2.** The distinctive results (C2–C7) come from increasing returns with coordination failure, which trade theory has had since Graham (1923).
    - The within-country additions are the national non-tradables channel and who captures the rents.
    - In V2020, "tradeable jobs" could fairly be read as "jobs with increasing returns".
- **H3.** RV2023 is a Ricardian model. What it adds is how comparative advantage shows up in nominal wages and measured productivity, not a new reason for places to be poorer in real terms.
- **H4.** The UK evidence fits the model, but probably can't on its own tell it apart from sorting and agglomeration.

If those hold, the answer will be roughly that the argument adds two things to Ricardo, increasing returns and spatial equilibrium, both of which matter for policy, but that its central premise is Ricardo's own.

## 4. Rebuilding the models in R

### 4.1 Approach

**Language: R.** The rest of the repo is R, renv and Quarto, and the models are small.

- RV2023's largest simulation (300 places by 50 sectors, 15,000 cells) is a fixed-point iteration over matrices, which is fine in R.
- Python would only help if we needed automatic differentiation, and we don't.
- So far base R is enough. If Model B's system needs a dedicated nonlinear solver, add `nleqslv` through renv.

**Layout.** It follows the IMD uncertainty pipeline:

- `code/tradeable_jobs/` holds `functions_*.R` files and numbered scripts;
- slow results are cached in `local/tradeable_jobs/cache/`;
- outputs go to `docs/chunks/tradeable_jobs/outputs/`;
- later there'll be a `00_run_all.R` that clears the cache, runs everything and renders the report.

| Script | Does | Status |
|---|---|---|
| `get_papers.py` | Downloads the papers and converts them to readable markdown | done |
| `functions_common.R` | Caching, downloads, outputs, skewness | done |
| `functions_v2020.R` | Model A: general solver for city types, equilibrium set, adjustment | done |
| `01_v2020_parameter_check.R` | Which agglomeration slope the papers used (4.2) | done |
| `02_v2020_curves.R` | Model A curves and the V2018 statements about them | done |
| `03_v2020_shocks.R` | Import competition, export boom, fiscal contraction and expansion | done |
| `04_v2020_ablations.R` | Step 4 | done |
| `functions_v2018s3.R`, `05_v2018_two_sector.R` | Model B: V2018 section 3 | done |
| `functions_rv2023.R`, `06_rv2023_table1.R`, `07_rv2023_simulations.R` | Model C: RV2023 | done |
| `functions_dfs.R`, `08_ricardian_benchmarks.R` | Model D: DFS and the engine with switches | done |
| `functions_uk.R`, `09_uk_sparsity.R` | Model E: the UK replication, with export shares | done |
| `10_leverage.R` | Step 3's numbers | done |
| `11_synthesis.R` | Step 10: claims against benchmarks, verdicts | done |
| `00_run_all.R` | Clears the cache, runs everything and renders | done |

### 4.2 Model A: V2020 and V2018 section 2

**Solving it.**

- For each $M_T$, (1)–(5) reduce to one equation in $w_N$, because with linear $q$, $w_T$ has a closed form once $w_N$ is known.
- The excess-demand function for non-tradables has a pole where $L_N$ reaches zero. A plain bracketing search "finds" a root there, as happened in the first scratch attempt, so the solver scans a grid restricted to positive city sizes, then refines.
- A stable city size needs $1 - p_T q'(M - M_T)/(PbM) > 0$ (V2018 footnote 10). The solver returns no solution when that fails.

**The equilibrium set:** E where $w_N = p_T q(0)$, and X where $w_T = w_N$.

**Experiments.**

- **Import competition.** Move $M_T$ left, including the case where the starting point falls past E.
- **Export boom.** This needs two tradable sectors: use Model B, or a variant of A with two tradable sectors.
- **Fiscal policy.** Lower $G$ on a grid, switching regime when $w_N$ reaches $p_T q(0)$.
    - Use both financing assumptions (2.4, item 6).
    - Hold $P = 1$, so that $p_T$ plays the role of the exchange rate, as in V2020 Figure 3.

**Targets.**

- the shapes of V2020 Figures 1–3 and A1;
- V2018 Figures 1–3 and the numbers quoted in its section 2;
- the appendix derivative $dM_T/dG$ at X.

**Done so far.** `01_v2020_parameter_check.R` writes `outputs/v2020_parameter_check.csv`:

| | Tmin (% of cities) | Tmax | Productivity gap at Tmin | Population ratio T:N at Tmin | Rent ratio at Tmin | Real income at Tmin vs Tmax |
|---|---|---|---|---|---|---|
| Solved, slope 0.015 (V2020 appendix) | 48.3 | 50 | 1.5% | 1.05 | 1.11 | +0.01% |
| Solved, slope 0.15 (V2018 appendix) | 28.9 | 50 | 23.3% | 2.00 | 4.00 | +1.45% |
| Reported in V2018 section 2 | about 28 (read off Figure 1) | 50 | 25% | 2.03 | 4.1 | +1.4% |

### 4.3 Model B: V2018 section 3

**Unknowns.** For each $(M_A, M_B)$: factor prices $w_i, r_i$ for $i = A, B, N$, factor allocations $L_i, K_i$, outputs $x_i$, $p_N$ and $P$. Production is Cobb-Douglas, $X_i = L^{\lambda_i} K^{1-\lambda_i}$.

**Steps.**

1. Solve the conditional equilibrium.
2. Map the equilibrium set using the unit-cost conditions in 2.2 on a grid of $(M_A/M, M_B/M)$, and trace its edges to rebuild Figure 4.
3. Apply the shock ($p_B/p_A$ from 1 to 0.8) and follow continuous paths from S and from Y (Figures 5–7).

**Targets.**

- From S: rents in type-A cities +126%, type-B −43%, type-N −26%, total rents +22%, and aggregate real income about +2%.
- The zones I–III behaviour.

### 4.4 Model C: RV2023

**The loop.** Start from wages $w_{is}$, rents $r_i$ and the exchange rate $q$, then:

1. compute prices (1);
2. compute price indices (2);
3. compute demand (5), including exports;
4. compute labour demand (6), rents (7) and incomes (8);
5. compute utility (3) and labour supply (9);
6. update wages to clear each place-sector labour market (damped, in logs), and update $q$ from (4);
7. repeat to tolerance, then check that the budget balances.

**Table 1 is a special case.** With perfect mobility the wage is common across sectors within a place, and utility is equal across places. Solve for $w_i$ with $u_i = \bar u$ and total labour equal to $L$.

**Targets.**

- $E_s$ and $\mu_s$ in Table 1. I checked these by hand: (11) with $\sigma = 10$ and $N = 100$ gives 9.9, 3.7 and 1.1, and 0.01, 0.84 and 0.99.
- Table 1's place outcomes: wages 1.17, 1.06 and 0.98; rents 1.40, 1.27 and 1.12; employment 1.74, 1.55 and 1.26.
- The Figure 1 histograms.
- Table 2a: coefficients 0.38 (SD measure) and 0.16 (skew measure), adjusted R² 0.45 and 0.17, and a wage range of 21.7 points, over 20 runs.
- Table 2b and Figure 3.
- Equation (13) against finite differences of the full model.

### 4.5 Model D: the benchmark engine

This is Model C with switches for:

- **labour mobility:** immobile, Fréchet, or perfect;
- **land:** $\alpha$, $\gamma$ and $\eta$;
- **trade costs:** the $t_s$ profile, including a two-value version that mimics V2020's split between tradables and non-tradables;
- **productivity:** the Ricardian $a_{is}$ draws;
- **agglomeration:** optional, as $a_{is}(1 + \kappa L_{is})$;
- **goods:** a homogeneous-goods limit (high $\sigma$).

This one engine covers R1–R3, RV2023 and something close to V2020, so steps 3, 5, 7 and 8 become runs with switches flipped.

With agglomeration switched on there are multiple equilibria. The solver will have to follow solutions from chosen starting allocations (continuation) and report which equilibrium it found.

### 4.6 Model E (optional): UK sparsity replication

This is step 8 with the open BRES and ASHE data. It ties the chunk to the repo's existing BRES and regional GVA work.

### 4.7 Checks for every model

- **Zero shock:** a symmetric base equilibrium must reproduce itself.
- **Published numbers:** reproduce them, and record mismatches in the log rather than tuning parameters to hide them.
- **Comparative statics:** check analytical results against finite differences.
- **Continuous city counts:** the models treat the number of cities as a continuous variable. Note where that matters, such as a single city switching.

## 5. Order of work and decisions for Dan

**Order of work.**

1. **Read and agree** (Dan and Claude): steps 1 and 2.
2. **Model A** rebuild and ablations: steps 3 and 4. This is quick, because the solver already works.
3. **Model C** rebuild against Tables 1 and 2: step 5.
4. **Model D**: steps 3, 6 and 7.
5. **Model B**, the two-sector lozenge. It's needed for C5 and the Dutch disease case.
6. **UK evidence** (optional): step 8.
7. **Write-up**: step 10, as a Quarto chunk document in this folder.

**Decisions** (Dan, 13 November 2026):

1. **"Plain Ricardian": test both readings.** Every claim is classified against the narrow benchmark (R0–R2, labour immobile between trading units) and the broad one (adding R3, Ricardo within a country, with mobile labour and land).
2. **Version of the argument: test all three.** These are V2020's (tradable means internationally traded and clustered), RV2023's (tradable means low trade costs within Great Britain), and the policy shorthand that mixes them.
3. **UK replication: included.**
4. **Published versions:** still open. If you have library access, check the published ORE and RIE versions against the typos in 2.4.
5. **Language: R.**

## Log

**14 November 2026.**

- **Scope.** Dan decided to test all options of decisions 1 and 2, include the UK replication, and use R. All models were built and run.
- **Solvers.** I wrote them in base R. Notes:
    - Model A's excess-demand function has poles, so the solver scans a grid, then refines.
    - City switching follows the boundary as in V2018 section 3.3.
    - Model C needed a fixed point on wages, with labour supply recomputed at current wages and damped rent and income passes. Earlier versions with lagged labour supply diverged.
    - Model B uses Newton's method from equal-sized cities in every cell. Warm starts carried across the grid found other solution branches.
- **Not converged.**
    - Model C with local rent rebates.
    - The RV2023 engine with agglomeration elasticity 0.04 or more (sectors vanish from places, which the log-based solver can't represent).
- **Data.**
    - The CEPR copies and the ONS time-series generator were blocked or rate-limited; I used the ORA, CEP and ONS `/data` endpoints instead.
    - BRES by NUTS 2016 level 3 from Nomis (TYPE437). ASHE tables 22.5a (ad hoc 12453) and 16.5a. The 2019 input-output analytical tables.
- **Bugs fixed along the way:**
    - named vectors renaming results (twice);
    - an empty index giving NA;
    - leading zeros dropped from SIC codes in ASHE table 16;
    - irregular CPA product codes;
    - figure colours and panel order.

**13 November 2026.**

- **Papers.** The CEPR copies are behind a Cloudflare check, so I used the Oxford archive versions of V2020 and RV2023 and CEP's V2018. I wrote `get_papers.py`, which downloads them and converts them to markdown, restoring the 2018 paper's Symbol-font characters.
- **Reading.** I read all three papers, wrote out the model equations by hand (2.2) and listed 14 things to check (2.4).
- **Ricardo.** I checked the passage quoted in part 3 against the Project Gutenberg text (1817 first edition, chapter "On Foreign Trade").
- **First script.** I started Model A in `functions_v2020.R` and ran `01_v2020_parameter_check.R`. It shows the 2018 slope (0.15) reproduces the reported numbers, and the 2020 appendix's 0.015 doesn't.
- **Bugs fixed along the way:**
    - spurious roots where $L_N$ reaches zero;
    - exact zeros on the grid;
    - a named input that renamed the size vector and broke look-ups.
