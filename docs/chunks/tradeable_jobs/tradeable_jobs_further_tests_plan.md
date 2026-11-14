# Tradeable jobs, round 2: sector linkages, production chains and payment flows

Written 14 November 2026 by Claude Code (Opus 5.5), at Dan's request. Status: plan, nothing run yet.

It builds on round 1:

- the plan, [tradeable_jobs_plan.md](tradeable_jobs_plan.md);
- the results, [tradeable_jobs_firstlook.qmd](tradeable_jobs_firstlook.qmd).

## What this plan is for

**Dan's hypothesis, as given:** the focus on "tradeables, then hope for trickle-down to non-tradables" doesn't fully stack up, given what productivity shifts could do for the much broader set of other sectors.

**The brief:**

1. Plan further tests of the hypotheses from the round 1 models.
2. Bring in sector connectivity and production chains, drawing on the "where GVA is booked" flow model and its research notes, and on the payment-flows work between ITL1 regions and sectors as empirical grounding.
3. Set out options for a policy proxy: "improving productivity" at different sector levels and levels of tradability.
4. Push back on any wrong trees.

**My short answer.** The hypothesis is worth testing. But in its current form it will fail for reasons that have nothing to do with whether it's true. Three changes would make it testable:

- **Reframe the target** (section 2, W1). The tradeables argument doesn't actually rely on productivity "trickling down". Its links to non-tradables are local spending and local prices. So the comparison to make is between policy effort spent on productivity in tradables and the same effort spent on productivity elsewhere, judged by who ends up better off, and where.
- **Measure the outcome in real terms, not GVA per head** (W2). A productivity gain in a non-tradable sector shows up as lower local prices and fewer jobs in that sector, not as higher local GVA per worker. Judged on GVA per head, the hypothesis looks false by construction.
- **Replace the tradable/non-tradable split with position in the supply chain** (W4). The big "non-tradable" sectors that matter for productivity (wholesale, logistics, construction, business services, utilities) mostly sell to other businesses, including tradables. Productivity there helps tradables too. It complements them rather than competing with them.

Section 3 asks when a place's strategy and the national one point the same way. Section 4 summarises the sources, section 5 sets out the tests, section 6 the policy proxy options, section 7 the evidence on what a point of productivity costs, section 8 the order of work and section 9 the decisions so far.

## 1. Where round 1 leaves this

The round 1 models already say four things relevant to the hypothesis:

- **A non-tradable advantage lowers nominal wages but not welfare.** In Rice and Venables's Table 1, place 9 has its productivity advantage in the least tradable sector. In the rebuild its nominal wage is 0.98 of the rest's and its population 1.28 of it, with the same utility as everywhere else. The gain goes into lower local prices and more people, not higher measured wages.
- **With immobile labour, real income responds about equally to both kinds of advantage.** Productivity in tradables gives 0.32, in non-tradables 0.29; only nominal wages differ (0.55 against 0.04). This is the narrow Ricardian benchmark, and it supports the hypothesis in real terms already.
- **With mobile labour, utility is equalised whichever sector improves.** The gains go to landowners and into city size. So any "benefit to places" claim, for tradables or non-tradables alike, is a claim about immobile people or land.
- **Extra non-tradable demand crowds out tradables** in Venables's model (C13). Raising public spending on non-tradables pushed the tradable share of cities from 40% down to 26.7%.

**What round 1 can't say.** Neither Rice and Venables nor Venables has intermediate inputs:

- Rice and Venables use only labour and land;
- Venables uses only labour.

So neither model can represent what the hypothesis turns on: productivity in one sector changing costs, prices and demand in others through supply chains. That's the main gap this plan fills.

## 2. Wrong trees: push-back

**W1. "Trickle-down" isn't the mechanism the tradeables argument uses.**

- **What the models actually say.** In Rice and Venables, Venables and Moretti's local multipliers, tradables reach the rest of the local economy through two channels:
  - demand: more income spent locally;
  - prices: higher nominal wages and rents.

  None of them claims that tradable productivity diffuses into non-tradable productivity. Moretti's multiplier creates non-tradable *jobs* (about 1.6 per manufacturing job, about 2.5 per skilled job), not more productive ones.
- **Why that matters.** An attack on "trickle-down" misses the mechanism.
- **The sharper targets:**
  - the multiplier creates mostly low-productivity, low-wage jobs (a Baumol point);
  - the price channel hands much of the gain to landowners (round 1, C14);
  - tradables can't be grown at will where agglomeration locks them out (round 1, C2–C3);
  - all of this has an opportunity cost: what the same effort would buy if spent on productivity elsewhere.
- **The hypothesis to test is that last one,** stated in section 5.

**W2. Productivity gains in non-tradables don't show up where UK targets look.**

- **Nominal wages fall.** A physical productivity gain in a sector sold only locally lowers its price. Local nominal wages and measured GVA per worker fall, not rise. Rice and Venables's equation (13) and the round 1 benchmarks (coefficient −0.11) both show this.
- **Jobs in the improving sector may fall too.** If demand is inelastic, the sector needs fewer workers. The techimpact Bessen note gives the condition: an industry's own employment falls when its effective elasticity, E_j = Σ_k ω_jk θ_jk ε_k, is below 1. Autor and Salomons find exactly this across countries: the improving industry loses jobs, and customer industries and aggregate demand make them up.
- **So the official lens shows the opposite of the gain.** Judged by workplace GVA per head (the usual place target), the outcome looks like nothing, or like a loss. The "where GVA is booked" model has a ready example: in its experiment E5, a 30% rise in city rents raises city GVA per job by 5.6% while residents' residual income falls 11%.
- **What to do instead.** Every test reports at least three lenses:
  - measured GVA per worker;
  - real income, including local prices and residual income;
  - employment by sector.

  It should also say which lens a policy target uses. UK regional price data is thin, and that is itself a finding to make explicit.

**W3. Payments across regional borders don't make non-tradables tradable.**

- **What the data shows.** The payment-flows work does show that "non-tradables" buy a lot across regional borders. In Yorkshire and the Humber:
  - retail sources only 16.6% of its business inputs inside the region (18.6% mean across regions);
  - health and social work sources 12.9% (UK regional mean 30.8%).
- **That's leakage, not tradability.** It is evidence about where these sectors *buy*, not where their *output* is sold. Tradability is about the second.
- **The dataset can't see most of the sales side.** For consumer-facing sectors:
  - it covers business-to-business payments only, so household spending is missing;
  - payments are placed at the registered entity, so card acquirers and booking platforms in London make hospitality's income look "77% from London".
- **Trends are unreliable too.** The 2019–2025 rise in local shares (Wales 15.0% to 22.0%) may be a capture artefact. Internal transaction counts grew 2.8 times against 1.4 times for external ones.
- **What the data can support:**
  - own-region shares (the trustworthy half), after stripping intermediary SICs (64, 66, 63, 82) and card-settlement flows;
  - business-to-business tradability for sectors that mainly sell to businesses: wholesale, logistics, business services, construction.
- **This cuts two ways for the hypothesis.**
  - Against it: spending on everyday services may support local *jobs* without strengthening local supply chains, which your own Yorkshire note already said. That weakens "invest in foundational sectors and the money recirculates".
  - For it: productivity gains in nationally integrated business-to-business services travel to every region through lower prices. That's good for the country, but it can't be captured locally (W6).

**W4. Tradable versus non-tradable is the wrong axis for spillovers.**

- **What matters instead** is position in the production network, which input–output theory gives directly:
  - **Hulten's theorem:** to first order, the national gain from a 1% productivity gain in a sector is proportional to its *Domar weight*, its gross sales (to final users and other firms) as a share of GDP.
  - **Corrected after T2:** the Domar weight exceeds the value-added share because the sector *buys* a lot of inputs, not because it sells to other firms. Two sectors with the same output and value added have the same weight whoever their buyers are. So upstream position doesn't add to the national gain, to first order. It decides where the gain lands: which buyers, which places, and how much reaches exporters through the supply chain.
  - **The direction of travel:** price falls pass down the chain to customers, and the extra orders pass back up to suppliers (Acemoglu, Akcigit and Kerr; McNerney and others; summarised in the techimpact note).
  - **Upstream sectors** gain little *employment* from their own productivity growth, but their customers gain a lot.
- **Many large "non-tradable" sectors are upstream suppliers to tradables.** Wholesale, transport and storage, construction, business support, utilities and real estate all sell heavily to other businesses. Productivity there lowers tradables' costs. It complements tradables rather than competing with them.
- **So the policy contrast isn't "tradables against care homes".** It is closer to "frontier tradable firms against broad improvement across the supply chain".
- **The axes the tests should use:**
  - upstream or downstream (share of sales to other businesses, Domar weight);
  - market reach (local final demand, national business-to-business, international);
  - scope for productivity growth (W5).

**W5. Baumol: not every sector can raise output per worker.**

- **The providential sectors** (care, education, health) have limited scope for labour-saving productivity without losing quality. Their measured output is largely their inputs, regionally almost entirely: the RegionalEconomicTools note "Inputs as output" covers this.
- **"What productivity shifts could do for the broader sectors"** should target:
  - the material foundational economy and everyday private services (retail, wholesale, logistics, hospitality, construction, utilities), where productivity has moved historically and gaps between firms are large;
  - business services.
- **The providential sectors belong under a quality lens**, through outcomes and access, not output per worker.
- **The flow model shows the measurement trap.** In its experiment E8, cutting public-service jobs by 10% for "efficiency" cuts measured GDP by 2.4%, because the services are valued at cost.
- **Decision (Dan, 14 November 2026): set aside for this round.** Care, education and health are excluded from round 2, which keeps to the narrow productivity lens.
    - This is a scoping choice, not a judgement that they matter less. They are very important: they hold a large share of jobs in lagging places, and how they are measured shapes every regional productivity comparison.
    - They deserve their own strand, built on outcomes, access and quality.
    - In the models they are held fixed, a constant block of local demand and employment, so they don't distort the comparisons. Results should say so.

**W6. Who gets the gain depends on mobility, for non-tradables as much as tradables.**

- **With mobile people,** lower local prices from non-tradable productivity attract people and push up rents (Rice and Venables's place 9). The gain ends up in land, just as with a tradable boom.
- **With immobile people,** it stays with residents.
- **And nationally traded business services spread their gains across every region** through prices, so a local policy can't capture its own gains.
- **So the hypothesis can be true nationally and still false for a single place's strategy.** Every test should report incidence by place and by group: residents, landowners, other regions.

**W7. Sector size measures the wrong thing.**

- **Domar weight, not employment, sets the national gain.** Care and hospitality employ many people but have low sales per worker, so a 1% gain there is worth less nationally than 1% in a high-sales sector.
- **But the cost of a percentage point differs too.** It may be much cheaper to get in laggard sectors and firms (the "long tail"; management practices) than at the frontier.
- **So the empirical crux is the policy cost of a point of productivity in each sector.** There is very little evidence on it (section 7), so a proxy has to assume it (section 6).

**W8. Revenue productivity isn't physical productivity.**

- **Measured gains can be price changes.** A measured productivity rise can come from prices and markups rather than efficiency. The `modelling_demand` notes cover this: revenue against physical productivity, and buyer power along supply chains. In its experiment E2, a supermarket squeeze moves GVA between firms and places without any change in efficiency.
- **What to do.** Any empirical test using GVA-based productivity by sector and place needs a check that changes aren't price or markup shifts. Every model proxy should be a *physical* productivity change.

## 3. Local and national strategy: when do they align?

Dan's decision: report both. This section sets out when they should agree, and test T9 checks it.

**Definitions.**

- **Local strategy** means raising the real income of a place's residents. Local landowners are reported separately.
- **National strategy** means raising UK aggregate real income.

**What every test reports.** For every proxy and setting:

- the local gain and the national gain;
- the **spillover share:** the part of the national gain that lands outside the place;
- **displacement:** losses elsewhere;
- the **land share:** the part of the local gain that goes to rents.

**When to expect alignment and misalignment:**

| Situation | Local view | National view | Aligned? | Why | Tested in |
|---|---|---|---|---|---|
| **Productivity in local final-demand services; people don't move, or land supply is elastic** | Gain: cheaper local goods and services | Gain, the sum of the local gains | Yes | Gains are consumed where they are made and not bid into rents. Hours may fall if demand is inelastic (T6) | T1, T6 |
| **The same, with mobile people and tight land** | Residents gain little; landowners gain | Gain | Partly | The gain is capitalised into land (Rice and Venables's place 9). Who wins locally depends on tenure | T1 with P9 |
| **Productivity in nationally traded business-to-business sectors** (logistics, wholesale, business services) | Small | Large, roughly in line with Domar weight | No: local less than national | The gain travels to buyers everywhere through prices. A place won't invest enough on its own, so national or pooled funding is the logical route | T1, T2, T5 |
| **Squeezed suppliers** | Small | Positive, shown as buyers' margins or lower consumer prices elsewhere | No: local less than national | Buyer power passes cost cuts down the chain to customers, often elsewhere. This is the "where GVA is booked" lens | T1 (buyer-power variant), flow model |
| **Attracting mobile tradable firms with the UK near full employment** | Gain | About zero, minus the subsidy | No: local more than national | Relocation, not creation. Evidence on displacement: Enterprise Zone evaluations; the Growth Vouchers turnover gain "potentially at the expense of non-supported firms" | T9 |
| **The same in a slack place, with people out of work who can't move** | Gain | Gain, from lower unemployment | Yes | RSA raised manufacturing employment mainly by cutting unemployment (Criscuolo et al.) | T9 (flow model, which has unemployment) |
| **Local procurement and demand diversion** (community wealth building) | Gain | About zero unless there is slack, or demand raises productivity (Kaldor–Verdoorn) | Only with slack | It takes spending from other places | T9, flow model E7 |
| **Starting a new tradable cluster where none exists** (a big push) | Gain if it works | Positive if it adds a cluster; negative if it splits one | Depends | Round 1: with the papers' own agglomeration, fewer, bigger tradable cities raise national income. Only if agglomeration runs out does adding clusters help | T7 (Model A with intermediates) |
| **Lower trade costs and better connections** | Can be negative for peripheral places | Gain | Not always | Activity can concentrate in the core: the "two-way road" | P7 in T1 |
| **Broad catch-up in lagging firms, nationally funded** | Gain in every place | Gain | Yes | It adds capacity everywhere with little relocation. Unknown: the cost per point (section 7) | T1, T10 |

**The pattern to test.** Local and national strategy agree when three conditions hold:

1. gains are consumed where they are made, and people or land don't capture them;
2. the place has slack;
3. the policy adds capacity rather than moving it.

They disagree when:

- gains travel through prices to buyers elsewhere;
- activity is moved rather than created;
- land absorbs the gain.

If this holds, much of the hypothesis is a *national* case: broad productivity in supply chains and the long tail. A single place's best strategy may still look like chasing tradables, even when that's zero-sum nationally.

## 4. What the sources offer

| Source | What it gives this plan |
|---|---|
| `modelling_demand`: the "where GVA is booked" flow model (`research/notes/model-spec-v1.md`, `build/plan_docs/build-worklog.md`) | A four-place, input–output model: fixed coefficients, markup pricing, spending-driven output, government, owners. Its seven "lenses" separate what an official observer sees from the true flows: workplace GVA, value capture along a chain, chain GVA per worker (lens 3), residual income, wealth. Switches cover how profit is booked and the public-service output convention. Its experiments include local procurement (E7: GDP +0.9%) and providential "efficiency" (E8). Static coefficients, no productivity dynamics and no regional prices, so it can't run the hypothesis as it stands, but its lens design and accounting are what the tests should report. |
| `modelling_demand/research/notes/foundational-economy-and-sector-linkages.md` | The sector typology to use: tradable or basic; material foundational; providential foundational; everyday "overlooked"; housing; unpaid work. Also economic base theory, Moretti, the Preston model and leakage, as input–output terms (backward linkages, induced effects, leakages), and the measured-GVA, liveability and multiplier lenses. |
| `modelling_demand/research/notes/flows-and-value-added.md` | Vertical integration (Pasinetti): productivity of the whole chain behind a final product. Regional flow data for the UK: Scottish and Welsh input–output tables, ONS estimates of trade between UK regions (2019, 2020), academic multi-regional tables. |
| `modelling_demand/research/notes/revenue-vs-physical-productivity.md`, `demand-led-productivity-dynamics.md` | W8, and demand-led productivity (Kaldor–Verdoorn, about 0.5): output growth raises productivity growth, so demand policy can be productivity policy. |
| `techimpact-econ-toymodels/research/notes/io-network-extension.md` | The machinery for productivity in a network: Leontief prices and quantities, the effective elasticity E_j, Hulten's theorem, labour-saving against input-saving gains, and a dynamic version where price falls move one link per period. Directly reusable for test T1. |
| RegionalEconomicTools: `claude/ind_to_ind_regionalpayments_IO.md`, `claude/payment_flows_method_and_caveats.md`, `claude/payment_network_centrality_plan.md`, `llm_output/yorkshire_humber_sector_highlights_summary.md`, `quarto_docs/payment_network_connectivity_2025.qmd` | ONS experimental industry-to-industry payment flows, 2019–2025, SIC 2-digit by ITL1 only.

- **There is no ITL2 level.** The local file `payments_itl2_sic2_yearly_w_sections.rds` is misnamed: it holds ITL1 columns only (12 regions). The caveats note's remark that the data is "ITL2-capable" is wrong and should be corrected there.
- **A national SIC 5-digit file** (monthly, 2017 to November 2024) gives fine-grained business-to-business structure, but nationally only. Flow location quotients, own-region shares, a decomposition into own region, London and rest of UK, and a measure of how widely money circulates inside a region. Caveats on registered-entity geography, missing households, capture artefacts and disclosure. Plus the finding that "non-tradables" source their inputs non-locally (W3). |
| RegionalEconomicTools: `claude/public_services_inputs_as_output.md` | Why public-service productivity is flat by construction, especially regionally (W5). |
| MONIAC2: `claude_research/productivity/research-plan.md` | Sector-by-place productivity from linking BRES to regional GVA, with hours estimates. That's the data for a sector-level productivity baseline and for any proxy calibrated to the long tail. |
| `econ_models_sandbox/llm_output/tradeables.md` (9 March 2026) | Your earlier digest of Rice and Venables, with critiques and a literature review of "tradeable primacy". It covers foundational economy papers, Faggio and Overman (public jobs crowd out tradable ones), Hanson (2024: smaller multipliers), anchor institutions as exporters, and digitalisation moving the boundary. Several critiques were confirmed in round 1. |
| `econ_models_sandbox/llm_output/supply_demand.md` | Martin et al.'s critique that levelling up was all supply side. The demand-side alternatives (foundational economy, community wealth building, mission investment, transport). |
| Round 1 code: `code/tradeable_jobs/` | The Rice and Venables engine (`functions_rv2023.R`), the UK BRES and ASHE pipeline (`functions_uk.R`), export shares from the input–output tables, and Model A. Round 2 extends these rather than starting again. |
| Companies House work (private repo `companieshouseopen`) | Firm-level GVA from company accounts, 2019–2024, for every size of firm that tags a profit and loss account. Reports: "One person's time" and "What CATO showed about small firms" (13 November 2026); "Jobs and GVA: how they connect" (`local/reports/jobs_gva/jobs_gva.html`, with `claude/jobs_gva_relationship_plan.md`) on cause and effect between jobs and value added, reallocation and rent sharing; "Where firms' value added grew" (`gva_spatial`) on place, closures and replacement; and `claude/gva_productivity_planner.md` on how this GVA differs from the national accounts and the ABS. What it gives round 2 is in section 7 and test T11. Dan to check whether to name the private repo here. |
| Evaluations and papers found for this plan (section 7) | Help to Grow: Management; Made Smarter Adoption; the Growth Vouchers trial; Regional Selective Assistance; spillovers from inward investment; Bloom et al.; ONS management practices; What Works Growth on business advice; Andrews, Criscuolo and Gal. Links are in section 7. |

The atlas catalogue (the topics "Money flows and supply chains", "Where value is booked", "Foundational economy and public services") was used to find these. It also lists notes in the private vault on the foundational economy and frontier firms. Their general ideas are used here (decision 5 in section 9), without linking or quoting them.

## 5. The tests

**Restating the hypothesis so it can fail.** For a given policy effort, raising physical productivity across sectors that sell locally or to other businesses delivers real-income gains at least as large as raising it in tradables. Those gains are more widely shared and less captured by landowners.

- **It fails** if, under realistic linkages and mobility, tradable productivity gives larger real gains to residents, or if non-tradable gains leak away (to other regions through prices, or to land through rents).
- **It holds nationally but fails locally** if the gains are real but spread to other regions. That's an argument for national rather than local policy.

### T1. Add supply chains to the Rice and Venables engine (Model F) — the core test

**Question.** Once sectors buy from each other, does productivity in non-tradable and intermediate sectors raise local real income, and help tradables, through cheaper inputs as well as cheaper consumption?

**Model.** Extend `functions_rv2023.R` so production uses labour, land *and intermediate inputs* from other sectors:

- the cost function becomes $p_{is} = w^{\gamma_L} r^{\gamma_K} \prod_k P_{ik}^{\gamma_{ks}} / a_{is}$, where $P_{ik}$ is the local price index of sector k's goods, so intermediates face the same trade costs as consumer goods;
- the input coefficients $\gamma_{ks}$ come from the UK input–output tables, aggregated to a manageable number of sectors.

This is the standard Caliendo–Parro or Caliendo et al. (2018) structure that Rice and Venables cite. Keep the switches from round 1: mobility, land, trade costs and agglomeration.

**Sectors.** About 15 to 20 groups, defined on three axes:

1. tradability (trade cost, with versions from W3 and T4);
2. upstream position (share of sales to other businesses, Domar weight);
3. what limits productivity in the sector. This typology is borrowed from earlier notes:
    - **catch-up:** ordinary manufacturing, wholesale, logistics, construction, where management time, absorptive capacity, finance for small kit and weak links to demanding customers hold firms back;
    - **limited by local demand:** hairdressers, takeaways, local shops, trades, where more output per hour without more local spending means fewer hours;
    - **squeezed suppliers:** subcontract manufacturing and food processing for supermarkets, where buyer power decides who keeps a gain;
    - **tradable frontier.**

    Care, education and health are held fixed (W5).

**Experiments** (the policy proxies in section 6): raise physical productivity in each group in turn, at an equal policy cost and also at an equal percentage. Run each under the narrow and broad benchmarks.

**Outputs** (each experiment, each place):

- nominal GVA per worker;
- real income per resident;
- employment by sector;
- rents and landowners' income;
- dispersion across places;
- the share of the gain that lands in other places.

**Checks.**

- With no intermediates ($\gamma_{ks} = 0$), the model must reproduce round 1.
- With one place, it must reproduce Hulten: the national gain follows Domar weights.

**Done (14 November 2026).** `functions_modelF.R`, `16_modelF.R`, `16b_modelF_closure.R`; section 11 of [tradeable_jobs_round2.qmd](tradeable_jobs_round2.qmd).

- **The build.** 18 market groups from T2 and 12 places, with productivity sd 0.2, three draws. All non-labour value added is a local fixed factor (land and buildings). Imports and taxes are fixed-price inputs. Foreign demand by sector is calibrated to export shares.
- **Both checks pass:** no intermediates reproduces round 1's engine exactly, and one closed place reproduces Hulten to 1e-7.
- **Closure (a change from round 1's engine).**
    - Rice and Venables's closure has a fixed import price, with a foreign-demand shifter balancing trade. It sends export-sector gains abroad: a 5% gain in machinery gives 0.01 of its Hulten gain.
    - Model F holds foreign demand fixed instead, so trade balances by Walras's law.
    - The two closures rank tradables against the rest in opposite orders. Both are reported. Round 1's headline results compared places within one equilibrium, so they don't depend on this.
- **Results.**
    - National gains run 0.8–1.4 times Hulten. Supply chains raise the upstream groups' gains (construction 0.97% against 0.55% without).
    - With people mobile, a lagging place keeps −21% to 14% of the national gain. With people immobile, it keeps 79–94% from local services and 13–14% from finance and chemicals.
- **Not done:** agglomeration, less elastic consumer demand (T6 says it's needed), and a pass-through switch.

### T2. Domar weights and tradability: where is the national leverage? (quick, data only)

**Question.** Which sectors carry the most national gain per 1% productivity gain, and how tradable are they?

**Method.** From the 2019 input–output analytical tables (already downloaded in round 1):

- the Domar weight per sector: gross output over GDP;
- the share of sales to other businesses;
- the export share (round 1);
- the forward linkage (row sums of the Leontief inverse).

Plot Domar weight against tradability, sized by employment and coloured by foundational type.

**Expected.** Several of the largest Domar weights are in "non-tradable" business-to-business sectors: construction, wholesale and retail, real estate, business services. If so, that's direct support for W4 and a quick, publishable figure.

**Done (14 November 2026).** Script `12_t2_domar_tradability.R`; results in [tradeable_jobs_round2.qmd](tradeable_jobs_round2.qmd).

- **Two-thirds of the market economy's leverage is outside the exported products.** Products exporting at least a quarter of their output carry 37% of it (net Domar weights; providential sectors and imputed rent left out).
- **The expectation was half right.** Construction has the largest weight of any market group (11.4% of GDP, net of its sales to itself). But professional services, finance and wholesale come next, and two of those are tradable.
- **Supply chains carry business-to-business gains to exporters.** About 35–45% of a gain in transport, wholesale, support, professional or financial services ends up in cheaper exports, against 16–28% exported directly.
- **W4 needed correcting** (see W4).
- **What "1%" means matters.** A gross-output gain is worth the Domar weight; a gain in value added per worker is worth the value-added share. The policy proxies (section 6) should say which they mean.
- **The forward linkage** is measured with the Ghosh inverse (upstreamness), not the Leontief row sums as first written here.
- **For Model F:** 19 sector groups, their input coefficients (domestic and imported), cost shares and final demand, in `outputs/t2_*.csv`.

### T3. Productivity of the whole chain behind each product

**Question.** How much of the labour embodied in "tradable" final products sits in non-tradable sectors upstream?

**Method.**

- Labour embodied per £ of final demand is $\lambda' = l' (I - A)^{-1}$, from the input–output tables and employment or hours by industry (BRES; the MONIAC2 hours work). Split each product's embodied labour by sector type.
- The regional version uses the payment flows to regionalise the A matrix, weighting by own-region shares after stripping intermediary SICs.

**Expected.** A large share of manufacturing's embodied labour sits in logistics, wholesale, business services and utilities. So "tradable productivity" partly *is* productivity in non-tradable inputs, and the flow model's lens 3 (chain GVA per worker) is the right way to report it.

**Done, national version (14 November 2026).** Script `15_t3_chain_labour.R`; results in section 10 of [tradeable_jobs_round2.qmd](tradeable_jobs_round2.qmd).

- **As expected, about half the jobs behind manufactured final products are in other groups:** 49% for electronics, machinery and vehicles, 56% food and drink, 63% chemicals and pharmaceuticals.
- **Most jobs embodied in exports are in services:** professional 19%, support 15%, wholesale 10%.
- **Chain GVA per job compresses the gaps between sectors.** Chemicals £201k → £119k, admin and support £40k → £61k.
- **The regional version is not done.** It needs regional coefficients, which the payments can't supply (T4).

### T4. Tradability within Great Britain, measured from payments

**Question.** Can the payment flows give a business-to-business tradability measure by sector that isn't built from geographic concentration (sparsity)?

**Method.** For each SIC 2-digit sector, at ITL1 (the only geography the data has):

- the share of business income received from *other* regions;
- after stripping intermediary payers (SIC 64, 66, 63, 82);
- after filtering out card-settlement flows (very many small transactions);
- reported only for sectors where business-to-business sales are a large share of all sales. That share comes from the input–output tables: intermediate over total use.

**Validation.**

- Scottish input–output tables (sales to the rest of the UK by industry);
- Northern Ireland input–output tables (sales to GB);
- ONS estimates of trade between UK regions, 2019 and 2020. First check whether they're published by industry.

**Then.**

- Compare with round 1's sparsity and export share.
- Rerun the round 1 UK regression with a "business-to-business tradability bias" alongside sparsity bias.
- This also closes the round 1 open item: "trade between GB places by sector".

**Done (14 November 2026): mostly a negative result.** Script `14_t4_payment_tradability.R`; results in section 9 of [tradeable_jobs_round2.qmd](tradeable_jobs_round2.qmd). The regional data were re-downloaded from ONS into this repo's pipeline.

- **The payment measure is stable but not valid yet.**
    - It is stable internally: 0.76 against the raw version, 0.90 without London, 0.79 between 2019 and 2024.
    - It fails the Scottish check: r = 0.02 against Scotland's rest-of-UK sales shares.
    - The published payments, without intermediaries, cover £459bn against £1,456bn of domestic intermediate sales (median division 16%). 73% of monthly cells are suppressed.
- **It is unrelated to sparsity** (r = 0.08), and adds nothing beside sparsity bias in round 1's regression (t = −0.08).
- **ONS interregional trade estimates for 2019 exist, but only for eight industry groups.** Across the six comparable groups (wholesale and retail are valued at sales), trade between regions is unrelated to sparsity. Real estate and professional services, the sparsest group, trade the least.
- **The Northern Ireland tables were not used.** The Scottish check was decisive enough.
- **"Trade between GB places by sector" stays open.** It needs finer official estimates.
- **For T5:** the payments' coverage problem applies there too. Regional coefficient matrices built from them would rest on about a sixth of business-to-business sales. T5 should use them only for ratios within a sector, with that caveat in front.

### T5. Local multipliers and leakage by sector type

**Question.** Does spending injected into local foundational sectors recirculate more locally than spending injected into tradables, as community wealth building assumes?

**Method.**

- Build regional coefficient matrices from own-region payment shares. These are business-to-business only.
- Compute first-round local multipliers by injecting sector, then add households using GDHI and spending shares (a rough Type II).
- Use the existing "pound walking" connectivity measure as a second view.

**Caveats.** Payments are placed at the registered entity and households are missing, so report ranges, not rankings. Any 2019–2025 trend may be capture (see the caveats note).

**Expected.** Your Yorkshire note's finding, that local services employ locally but buy nationally, generalised across regions with uncertainty. If foundational multipliers aren't bigger, the demand-side version of the hypothesis weakens. The supply-side version, through prices and costs, stands or falls on T1.

**Done, limited version (14 November 2026).** Script `18_t5_local_sourcing.R`; section 13 of [tradeable_jobs_round2.qmd](tradeable_jobs_round2.qmd).

- **No multipliers.** Given T4's coverage problem, the payments are used only for a ratio within each buying industry: the share of its business spending paid to its own region, against no home bias.
- **Everyday services don't buy more locally than tradables.** The home-bias index is 1.72 for everyday services against 1.90 for tradable and basic sectors. Retail keeps 28% in its own region.
- **The local buyers are agriculture, ordinary manufacturing, construction and transport.** The ranking holds without London.
- **This matches the Yorkshire note, now for all regions.** The demand-side case for the foundational economy is weak for everyday services.
- **Not done:** the household round (Type II) and the "pound walking" comparison.

### T6. Do productivity gains cost the improving sector jobs?

**Question.** For each sector group, is the effective elasticity E_j above or below 1? That is, does productivity growth in the sector cut its own employment?

**Method.**

- Combine the input–output shares (ω, θ) with final-demand price elasticities from the literature. Elasticities are uncertain, so use ranges.
- Run a descriptive check on UK industry data: productivity growth against employment growth by industry (ONS productivity by industry), as in Autor and Salomons.

**Why it matters.** If productivity in retail, hospitality or care cuts their own jobs, the gain arrives as cheaper goods and services plus displaced workers. With immobile people, those displaced workers are exactly who the hypothesis is meant to help. That's the honest trade-off to show.

**Done (14 November 2026).** Script `17_t6_own_jobs.R` (data) and Model F's E1 runs; section 12 of [tradeable_jobs_round2.qmd](tradeable_jobs_round2.qmd).

- **Data.** ONS productivity by industry division, 1997–2019, stacked five-year differences: hours fall 0.24 log points per log point of output per hour.
    - Business-to-business industries −0.54, local services −0.34, tradables −0.14.
    - Division bias is a caveat.
- **Literature elasticity ranges were not used.** Model F stands in for them.
- **Follow-up, Model F with demand calibrated to T6** (same day, `21_modelF_demand.R`; section 16 of the report). A grid over households' substitution between sectors, firms' substitution between inputs and the export demand elasticity.
    - Best fit: 0.5, 0.2 and 2. Model own-jobs responses are −0.58, −0.37 and −0.01, against T6's −0.54, −0.34 and −0.14.
    - National gains fall to 0.65–0.76 of Hulten in every group.
    - Break-even per point narrows. Upstream is 0.92 with Model F's closure and 1.04 with Rice and Venables's; local services 0.64 and 0.96; long tail 0.84 and 0.53.
    - A caveat exposed: the between-place elasticity of 10 lets a single place's local services draw customers from the others.

### T7. Re-run round 1's claims with supply chains

Run T1's Model F against the round 1 claims, to see which change once sectors are linked:

- **C9:** does a non-tradable advantage still lower nominal wages when non-tradables are inputs to tradables?
- **C13:** does non-tradable demand still crowd out tradables?
- **C8, cost leverage:** cheaper local inputs could raise the 5–9% cost advantage of lagging places. This tests whether improving local non-tradable inputs is the missing "lever" Venables says lagging places lack.

Then add supply chains to Model A (Venables's cities). Tradables buy a share of their inputs from the local or national non-tradable sector, and the test is whether that changes the lock-in edge E.

**Done in Model F (14 November 2026).** Model A with supply chains followed the same day (see the log).

- **C9 holds with supply chains.** A local-services gain lowers the lagging place's nominal wage (retail −0.34%) while its real income rises.
- **C8's lever fails.** Better local inputs raise the place's tradables' unit costs slightly (+0.02% to +0.44%), because wages and rents rise more than input prices fall.
- **C13 was not run separately.**

### T8. Measurement-lens check (runs inside T1, T5 and T7)

For every experiment, show where the official lens (workplace GVA per worker) and the real-income lens disagree in sign. Use both public-service output conventions, as the flow model does.

**Expected.** Productivity in non-tradables looks neutral or negative on the official lens and positive on the real lens. Making that visible is probably the most useful single output for policy.

**Done in Model F (14 November 2026).**

- **Nationally, the lenses agree in sign in all 36 group experiments.** But the official lens shows a fifth to a third of the real gain for retail, hospitality and construction.
- **Locally, with people mobile, they disagree in sign in 8 of 18 group experiments.** Improving local services lowers a place's measured GVA per worker but raises its real income. With people immobile, 1 of 18 disagree.

### T9. Local against national: when do they align? (runs across T1, T5 and T7)

**Method.**

- **Model F** (full employment): report each proxy's local and national gain, spillover share, displacement and land share (section 3). Vary:
    - mobility (immobile, Fréchet, perfect);
    - land supply elasticity;
    - the improved sector's trade cost and share of sales to other places;
    - agglomeration.
- **The "where GVA is booked" flow model, converted to R** (step F0 in section 8; demand-driven output with unemployment): run the slack cases. Inward investment, local procurement and productivity proxies, in a slack place and in a tight one, with local and national accounts side by side.

**Output.** A map of the conditions under which each proxy is aligned, local more than national, or local less than national, checked against the predictions in section 3.

**Done (14 November 2026).** The Model F half is in section 11 of the report (see the T1 note). The flow-model half, after F0, is in section 17: see the log.

- **Mobility is the switch.** With people mobile, local gains leak whatever the group. With people immobile, local and national align for local services and diverge for nationally traded business services.

### T10. Break-even: how cheap must broad catch-up be?

Evidence on the cost of a point of productivity is thin (section 7). So don't assume a single cost. Ask instead: at what ratio of cost per point does broad catch-up (P2), upstream productivity (P3) or local services (P4) deliver the same real gain as a frontier push in tradables (P1)? Answer it locally and nationally, under both benchmarks.

**Anchors.**

- **The "big blocks" arithmetic** from earlier notes, which used invented numbers for a city region. A 3.8% gain across the large lower-productivity blocks adds as much value added as a 20% gain in the top 2% of firms.
- **The evaluation evidence** in section 7, to judge whether the break-even ratio is plausible.

**Output.**

- break-even cost ratios with ranges;
- a short statement of what each would need to be true.

That's more defensible than claiming a cost we don't know.

**Done (14 November 2026).** `19_t10_breakeven.R`; section 14 of the report. A point is the employment-weighted mean log productivity rise; the ratio is the gain per point against the frontier push (P1).

- **National, Model F's closure:** long tail 0.66, upstream 0.74, local services 0.40 (people mobile; the immobile figures are similar).
- **National, Rice and Venables's closure:** 1.08, 1.19 and 1.04. Every alternative beats the frontier push at equal cost per point.
- **Local, for the lagging place, people immobile:** catch-up groups 1.35, local services 1.43. With people mobile, 0.88 and 0.67.
- **The evidence (section 7) can't settle it.** What would need to be true: tail points at about two-thirds the cost of frontier points (Model F closure), or at any cost up to parity (Rice and Venables's closure).

### T11. Ground the models in firm-level data

**Question.** Do the model settings that drive the round 2 results match what UK firms show? The settings in question are within-sector dispersion, how fast labour moves to better firms, how much of a gain is passed through, and local spillovers.

**Method.** From the Companies House firm panel (firms with 10+ employees and a usable GVA):

- **sector-by-size distributions** of GVA per job, and the catch-up potential: GVA if firms below the median reached it;
- **the within/between/entry/exit decomposition** by sector and by ITL1 region;
- **responsiveness** (jobs growth on relative GVA per job) by sector, to set Model F's labour movement;
- **pass-through,** from the rent-sharing estimate, to split gains between pay, profit and prices;
- **place effects:** the share of GVA-per-job variance due to place after sector. This tests the size of the Ricardian place-by-sector differences that Rice and Venables assume (a standard deviation of 0.2).

**Reproducibility** (Dan's decision, 14 November 2026).

- **The export script lives in this repo:** `code/tradeable_jobs/`, numbered with round 2.
- **It reads the Companies House report outputs read-only:** the Parquet and RDS files under `companieshouseopen/local/reports/*/data/`, not the 20 GB database.
- **It writes aggregate tables to `local/tradeable_jobs/companieshouse/`.** That folder is gitignored (checked: the `local/` rule in `.gitignore` covers it).
- **So nothing from the private firm data is committed.** Each table records the Companies House build date it came from. The pipeline rebuilds on this machine, or anywhere the Companies House outputs exist. *Clarified 14 November 2026 (decision 9): Companies House data is open data, so aggregates at any useful level may be committed; the firm-level tables still live in `local/` because they are large and rebuilt from the source project.*

**Two parts.**

- **T11a (early): the descriptive exports.** They give the real-data "big blocks" arithmetic, an early result on the hypothesis itself, and ranges for Model F's settings.
- **T11b (after Model F): the checks.** Model F's physical productivity draws aren't observable, so the check compares what the model produces with what the data measures: revenue productivity by place and sector, its spread, and the decomposition. In practice, choose the settings so the model reproduces those moments.

**T11a done (14 November 2026).** Script `13_t11a_firm_aggregates.R`; results in section 8 of [tradeable_jobs_round2.qmd](tradeable_jobs_round2.qmd). The pooled numbers reproduce the Companies House reports (decomposition, responsiveness 0.042, pass-through 0.22).

- **The long tail has several times the room of the frontier.**
    - Firms below their SIC division and size band's median closing half the gap: about 4.3% of GDP, scaled by each group's value-added share.
    - The top decile gaining 10%: 0.9%.
    - The top decile would need about 46% to match. This is room, not cost; T10 still has to price it.
- **The tail has room inside the frontier sectors too.** Professional services and ICT have the largest tail gains, so "tail against frontier" is a within-sector split, not a sector choice.
- **Jobs moved into the lowest-productivity group.** Among firms present in 2019 and 2024, moves between groups took £1.6k per job off, against £1.8k within groups. Most of it is hospitality's share rising, partly its post-pandemic recovery.
- **Model F settings:**
    - responsiveness 0.03–0.065 by group;
    - pass-through to pay 0.11–0.39 by group, highest in labour-intensive services;
    - within-group log spread 0.42–0.79;
    - place-by-group spread in revenue productivity about 0.05 log points, the target moment for T11b.

**T11b done (14 November 2026).** `20_t11b_moments.R`; section 15 of the report.

- **Model F's revenue-productivity spreads match the firms':** place by sector 0.037 against 0.052, sector 0.32 against 0.31, place 0.075 (mobile) or 0.134 (immobile) against 0.090.
- **Physical spread of 0.2 shows up as about a third as much in revenue productivity.**
- **The mobile benchmark fits better.**

## 6. Policy proxy options: "improving productivity" at different levels

All of these are physical productivity changes (W8). The policy cost of a percentage point is set in a separate table of assumptions, so it can be argued with. Each proxy should be run at an equal *cost* as well as at an equal *percentage* (W7).

| Proxy | In the models | Real-world analogue | Lens where it should show | Caveats |
|---|---|---|---|---|
| **P1. Frontier push in tradables** | Raise $a_{is}$ in the most tradable groups, in places already strong in them | Sector deals, inward investment, R&D support in clusters | Nominal GVA per worker, rents | Lock-in: may not move places that lack the sector (round 1) |
| **P2. Long-tail catch-up within sectors** | Raise $a_{is}$ only where it is below the sector's national median, across all groups | Management practice, technology adoption, business support for SMEs | Real income and wide spread; small change in GVA per worker | Cost per point is unknown; the ONS Management and Expectations Survey gives some orientation |
| **P3. Upstream and intermediate productivity** | Raise $a_{is}$ in business-to-business groups (logistics, wholesale, business services, utilities, construction) | Logistics and digital infrastructure, procurement modernisation, construction methods | National real income (Hulten), tradables' costs, chain GVA per worker | Gains spread nationally through prices; hard to capture locally (W6) |
| **P4. Local everyday services** | Raise $a_{is}$ in local final-demand groups (retail, hospitality, personal services) | High-street and hospitality productivity programmes | Local prices and real income; jobs may fall (T6) | Shows as lower nominal GVA per worker; rents may absorb it |
| *P5. Providential quality: set aside this round (W5)* | *Quality-adjusted output switch, as in the flow model's public-service convention* | *Care and education reform, prevention* | *Access and outcomes* | *Important, but outside the narrow productivity lens; its own strand later* |
| **P6. Labour-saving against input-saving** | The same groups as P1–P4, but change $l_j$ only, or the A column only, or both | Automation against process efficiency | Employment by sector and suppliers (T6) | From the techimpact note; the type of gain changes who loses jobs |
| **P7. Lower trade costs** | Lower $t_s$ for chosen groups: making non-tradables more tradable | Digital services, transport connectivity | Sparsity, specialisation, sector dispersion | Moves sectors across the tradable boundary (UNCTAD point in the digest); can concentrate activity |
| **P8. Demand-led productivity** | Raise local demand (public procurement, the flow model's E7) with a Kaldor–Verdoorn feedback (about 0.5) | Community wealth building, anchor procurement | Output, then productivity with a lag | Feedback strength uncertain; crowd-out (C13) |
| **P9. Land and housing supply** | Raise land supply elasticity $\eta$ | Planning reform | Shares the gain between residents and landowners | Not a productivity policy, but it decides who gets every other proxy's gain |

**Combinations worth running:**

- P1 against P2 against P3 at an equal cost: the core comparison for the hypothesis;
- P4 with and without P9: who keeps the gain;
- P3 with intermediates switched on and off: the value of supply chains (T1's check).

## 7. What does a point of productivity cost? The evidence

**The short answer: almost no UK evaluation reports it.**

- Most UK evaluations report survival, turnover or jobs.
- Productivity effects are either not detected within the evaluation window or so large that the evaluators doubt them.
- So the proxies use scenario ranges (T10), anchored on the few credible estimates below.

| Intervention | Firms | Productivity finding | Cost | Source |
|---|---|---|---|---|
| **Help to Grow: Management** (UK, 2021 on) | SMEs, mostly 5–249 employees | No statistically significant effect on growth or productivity (turnover per worker) in data to March 2023. Survival rose. The evaluators expect any effect to take five years or more | £223m government funding; £750 fee per leader | [Phase 1 final evaluation, 2026](https://assets.publishing.service.gov.uk/media/6a297517d95ffddb05d4ae28/help-to-grow-management-phase-1-final-evaluation-report-process-and-impact-evaluation.pdf); [reports page](https://www.gov.uk/government/publications/help-to-grow-management-annual-and-impact-reports) |
| **Made Smarter Adoption** (UK, 2022–2025) | SME manufacturers | No significant immediate step change. Three-year estimates of GVA per worker of +38% to +51% the evaluators judge not credible. The gains found came mainly from using fewer inputs | £19.8m, March 2022 to December 2024; grants of about £20,000 | [Ipsos final impact evaluation, 2025](https://assets.publishing.service.gov.uk/media/6a69b8434dda8076771a42a8/made-smarter-adoption-programme-final-impact-evaluation-june-2025.pdf) |
| **Growth Vouchers** (UK, randomised trial) | 15,207 SMEs | Turnover +8.2%, short term only, and "potentially at the expense of non-supported firms" | Vouchers paid half the cost of advice, up to £2,000 | [CEP/LSE paper](https://researchonline.lse.ac.uk/id/eprint/126834); [What Works Growth summary](https://whatworksgrowth.org/insights/lessons-for-business-support-schemes-from-a-large-rct-in-the-uk/) |
| **Regional Selective Assistance** (UK manufacturing) | Mostly small firms | Employment, investment and net entry up; no effect on total factor productivity | About $6,300 per job | Criscuolo, Martin, Overman and Van Reenen (2019), *AER* 109(1); [CEPR DP8818](https://repec.cepr.org/repec/cpr/ceprdp/DP8818.pdf) |
| **Spillovers from inward investment** (UK manufacturing, 1973–1992) | Domestic plants | A 10-point rise in foreign presence in an industry raises domestic plants' productivity by about 0.5%; no significant effect within a region | Spillover worth about £2,400 per job (2000 prices), below the incentives typically paid per job | Haskel, Pereira and Slaughter (2007), *REStat* 89(3) |
| **Intensive management consulting** (India, randomised trial) | Large textile plants | +11% (working paper) to +17% (first year, published version) | Five months of hands-on consulting by an international firm per plant, so expensive per firm | Bloom, Eifert, Mahajan, McKenzie and Roberts (2013), *QJE*; [NBER w16658](https://www.nber.org/papers/w16658.pdf) |
| **Management practices** (UK, association) | All sizes | A 0.1 rise in the ONS management score goes with about 9.6% higher productivity; lower quartile to median, about 19%. An association, not a cause | n/a | [ONS management practices](https://www.ons.gov.uk/economy/economicoutputandproductivity/productivitymeasures/articles/managementpracticesingreatbritain/2016to2020) |
| **Business advice, evidence review** (2014) | Various | 17 of 23 robust evaluations found a positive effect on at least one outcome; effects on productivity and GVA more common than on jobs; little cost-effectiveness evidence | n/a | [What Works Growth review](https://whatworksgrowth.org/wp-content/uploads/Business-Advice-Review.pdf) |
| **Diffusion from the frontier** (OECD) | All firms | Frontier firms pulled away from the rest in the 2000s, most of all in services; laggards rarely catch up | n/a | Andrews, Criscuolo and Gal; [VoxEU summary](https://voxeu.org/article/productivity-slowdown-s-dirty-secret-growing-performance-gap) |
| **Firm-level GVA from company accounts** (UK, 2019–2024) | Every size that tags a profit and loss account | GVA per job in 2023, median and middle half: 10–49 employees £85k (£55k–£132k); 50–249 £54k (£40k–£75k); 250+ £33k (£20k–£49k). One-employee companies filing through CATO: median £4.2k. Those small firms' GVA is mostly hours and pricing (sales explain 72% of its variance; capital about 4% of GVA). Selection: big labour-heavy employers in care, retail and hospitality are more likely to tag a profit and loss account | n/a | Dan's Companies House reports, 13 November 2026 (private) |

**What this means for the proxies.**

- **SME management and technology programmes** show no measurable productivity effect within two to four years in the UK. The honest default is no short-run effect and a modest, uncertain long-run one.
- **Subsidies for tradable investment buy jobs, not productivity** (RSA), and spillovers from inward investment are small per pound. So a frontier push (P1) is expensive per point, unless it creates a cluster, and round 1 shows that is uncertain.
- **Intensive operational help can produce double-digit gains** in firms that lack basic practices. The lower-quartile-to-median gap in management (about 19%) suggests there's room in the tail. But the cost per firm is high, and the results may not transfer to UK micro firms.
- **For micro firms, "productivity" is mostly hours and pricing power.** Raising it means more demand or better prices, not efficiency. That moves the local-demand block towards demand-side levers.
- **Measurement is getting harder.** The end of CATO removes the open view of small firms' productivity, which a long-tail strategy would need to monitor.

### What the firm-level GVA data adds

**Yes, it's useful, and not only for micro firms.** For firms with 10 or more employees it gives five things the national and regional statistics can't. All of it is revenue productivity, from mostly mid-sized audited firms. It's also placed at the registered office, and selected by who tags a profit and loss account.

1. **How much room there is in the long tail, by sector and size.** The gap between the lower quartile and the median within a sector and size band is the room for catch-up. It gives a real-data version of the "big blocks" arithmetic: how much aggregate GVA would rise if firms below their sector's median reached it, against a given gain for the top decile. That anchors T10's break-even ratio.
2. **Where aggregate productivity change came from.** For firms with 10+ employees, real GVA per job rose by £5.3k between 2019 and 2024. Split up:
    - within-firm improvement added £1.9k;
    - jobs moving between firms took away £1.7k. That's towards *lower* GVA per job, and almost all of it is between sectors (−£2.0k on sector averages);
    - entry added £6.2k and exit took away £1.2k. Entry is mostly firms starting to tag a profit and loss account, so it's selection, not productivity.

    So within-firm gains were almost cancelled by jobs shifting into lower-productivity sectors. That's direct evidence for the premise of the hypothesis: jobs are moving into the larger, lower-productivity sectors, so their productivity matters more for the aggregate over time.
3. **Reallocation is slow.** A firm with 10% higher GVA per job than its sector grows only about 0.42% faster in jobs the next year, and firms with 250+ employees don't respond at all. This calibrates how fast Model F lets labour move towards more productive firms. It's evidence against frontier gains spreading quickly by pulling jobs towards the best firms.
4. **Who keeps a productivity gain.** A 10% rise in GVA per head comes with a 2.2% rise in pay per head in the same year. That's above matched worker–firm estimates and close to UK company-account studies. So a gain is split between workers, owners and (through prices) customers, not passed straight to prices as in Model F's competitive pricing. T1 should get a pass-through switch calibrated on this, which changes the incidence results in section 3.
5. **How local the spillovers are.** After sector and year, about 0.5% of firms' growth is shared with other firms in the same place, and there's no correlation with neighbours beyond the first kilometre. Closures take the weaker firms (76% of jobs lost were below their sector's median), but the jobs don't reappear nearby. So:
    - the evidence for local productivity spillovers between firms is weak, at least over five years;
    - local labour markets don't absorb closures in the same sector.

    The first bears on the agglomeration assumptions behind cluster strategies (section 3, Model A). The second bears on immobile workers (W6).

**One more caution from the same work, for P4.** In cleaning and facilities, food service, hotels, recreation and residential care, sales follow the wage bill: prices are set on labour costs. Measured GVA per job there is largely a markup on pay, so the narrow productivity lens is at its weakest in exactly the local-services block.

## 8. Order of work

| Step | Work | Depends on | Size |
|---|---|---|---|
| F0 | Convert the flow model to R (below) | `modelling_demand` repo | Medium to large |
| 1 | T2: Domar weights against tradability, from the input–output tables. **Start here:** it fixes the sector groups and input–output coefficients that everything else uses | Round 1 data | Small: a day or less |
| 1b | T11a: export firm-level aggregates by T2's sector groups (catch-up potential, the within/between decomposition, responsiveness, pass-through, place effects) and the real-data "big blocks" arithmetic | T2's groups; Companies House report outputs | Small to medium |
| 2 | T4: payment-flow tradability by sector, with validation against the Scottish and NI tables and ONS trade between UK regions | Payment flows (re-download from ONS into this repo's pipeline), the tables | Medium |
| 3 | T3: chain productivity (embodied labour), nationally and then regionalised | T2, MONIAC2 hours | Medium |
| 4 | T1: Model F, the Rice and Venables engine with intermediates; check against round 1 and Hulten | T2's coefficients; T11a's ranges for dispersion, responsiveness and pass-through | Large: the main build |
| 5 | Policy proxies P1–P9 in Model F, all lenses (T8), both benchmarks | Steps 1–4 and the table of cost assumptions | Medium |
| 6 | T7: round 1 claims with supply chains; Model A with intermediates | Step 4 | Medium |
| 7 | T5: local multipliers by sector type | Step 2 | Medium |
| 8 | T6: productivity against own employment, model and UK data | Steps 2 and 4 | Small to medium |
| 9 | T9: local against national, in Model F and in the flow model (slack cases) | Steps 4–5 and F0 | Medium |
| 9b | T11b: check Model F against the firm data. Compare the model's revenue productivity (wages, value added per worker by place and sector) with the firm moments, not its physical productivity draws directly | Steps 1b and 4 | Medium |
| 10 | T10: break-even cost ratios, with the evidence table in section 7 | Steps 5 and 9 | Small |
| 11 | Write-up: round 2 report and a short note on the hypothesis, nationally and locally | All | Medium |

**F0: converting the flow model to R** (Dan's decision).

- **Source.** The TypeScript engine in `modelling_demand/build/src/engine/` (about 2,400 lines across 23 files). The pieces are:
    - prices, the period solve, the economy, calibration, the run loop and scenarios;
    - eight lens modules: accounts, booking, chains, flows, incomes, measurement, producer, structure;
    - the spec-v1 parameters and calibration, and the experiments.
- **Target.** `code/tradeable_jobs/functions_flow.R` plus scripts, base R plus the packages already in use. Keep the spec's structure and names, so each function maps to a section of `model-spec-v1.md`.
- **Validation.** Before any new use, reproduce the TypeScript results recorded in `build/plan_docs/build-worklog.md` and the test files:
    - the accounting identities (tests T1–T7);
    - the base-year results;
    - the headline table at t = 40 for E1–E8. Before any change: GDP £52.21bn, GNI £47.05bn, unemployment 5.00%. Examples: E6 export slump, GDP −9.65%; E7 local procurement, +0.88%;
    - the lens checks, for example the gadget chain's £132,238 per worker against £300,000 per job on site.

    If the repo can run the TypeScript experiments locally, its output files are a stricter target.
- **Then extend it for round 2:**
    - productivity proxies as changes to labour or input coefficients (P1–P4, P6);
    - local and national accounts side by side (T9);
    - a slack or tight labour market switch;
    - a regional price lens.

**Pipeline.** Everything follows the round 1 pipeline:

- the code lives in `code/tradeable_jobs/`, numbered from 12;
- downloads go to the gitignored `local/`;
- results are cached, and `00_run_all.R` extends to cover the new scripts.

**The payment data.** It is currently in `RegionalEconomicTools/local/data/`. It should be re-downloaded from the ONS article (linked in `ind_to_ind_regionalpayments_IO.md`) inside this repo's pipeline, so the work rebuilds here on its own.

## 9. Decisions (Dan, 14 November 2026)

1. **Report both the national and the local version of the hypothesis.** The question is under what circumstances local and national strategy align, and where they don't. That's now section 3 and test T9.
2. **Dig for sources on the cost of a point of productivity.** Done, in section 7. That includes the firm-level GVA reports in the Companies House work. The thinness of the evidence is why T10 asks for break-even ratios rather than assuming a cost.
3. **Care, education and health are set aside.** They're very important, and noted as such in W5, but this round keeps to the narrow productivity lens. In the models they're held fixed.
4. **The payment data is ITL1 only.** There's no ITL2 level: the local file's name is misleading, and the RegionalEconomicTools caveats note should be corrected. The national SIC 5-digit file can help with business-to-business structure nationally (T3, T4).
5. **The private notes have been checked.** Their general ideas are folded in without names or private details:
    - the "big blocks" arithmetic (section 5, T10);
    - the typology of what limits productivity (T1);
    - buyer power and squeezed suppliers (section 3);
    - the point that firms selling to local households need more demand, not just more output per hour (T6);
    - the reading on diffusion: absorptive capacity, the national frontier as translator, the productivity J-curve.

6. **The firm-level GVA data is useful well beyond micro firms** (follow-up, same day). Its five uses are in section 7, with test T11.
7. **The flow model gets converted to R** (step F0), validated against the TypeScript build's recorded results, then extended for T9.

8. **The firm-level tables are stored locally** in `local/tradeable_jobs/companieshouse/` (gitignored), made by an export script in this repo. Nothing from the private data is committed.
9. **Companies House data is open data** (Dan, 14 November 2026, before the overnight commit): include whatever level of aggregation helps in committed outputs and reports.

**Still open.**

- Nothing blocking.
- Whether any of the evaluations in section 7 publish enough cost and effect detail to turn into a cost per point. Bloom et al. and RSA are the likeliest.

## 10. Log

Entries are in time order. Each names the commit it went into; all are on `master`.

**14 November 2026, overnight: T2 to T11b** (Dan asked for every stage to be worked through in order; commit `77a128f`, 08:16, after T2 itself went into `bc81fec` at 02:37 with the round 1 BRES fix).

- **Done:**
    - T2, T11a, T4, T3 (national), T1 (Model F) with T7 (partly), T8 and T9 (model half);
    - T6, T5 (limited), T10 and T11b.
- **Results:** sections 1–15 of [tradeable_jobs_round2.qmd](tradeable_jobs_round2.qmd).
- **T4 is mostly negative.**
    - The payment flows cover a median 16% of a division's intermediate sales and fail the Scottish check.
    - ONS's interregional trade estimates exist only for eight groups.
    - So T3's regional version and T5's multipliers were not built.
- **The trade closure was found and changed in Model F.** Rice and Venables's closure (fixed import price, a demand shifter q balancing trade) makes export-sector gains leak abroad almost entirely. Model F holds foreign demand fixed, and both are reported. Round 1's plan log notes why round 1's results don't depend on it.
- **Mistakes caught:**
    - a repeated `summarise()` ordering bug: totals computed before the weighted means that need them (fixed in T2, T11a and T5);
    - the Scottish column match missing a header with a line break;
    - a local break-even ratio averaged over groups with tiny denominators (now pooled);
    - the report, sources and open decisions checked against the summary to Dan: the data sources weren't linked, the closure caveat wasn't in round 1's log, and the Companies House question wasn't logged. All three were added.

**14 November 2026, morning: demand calibrated to T6, F0 and T9's slack half** (commit `c1a4134`, 08:45).

- **Decision 9.** Companies House data is open data, so the aggregates stay in the report. The overnight work was committed first.
- **Refactor.** Model F's experiments moved into `mf_run_draw()`, run in parallel: identical results, 1 minute instead of 20.
- **Demand calibrated to T6** (`21_modelF_demand.R`; section 16 and the T6 note).
    - Best fit: households' substitution 0.5, firms' 0.2, export demand 2.
    - National gains fall to 0.65–0.76 of Hulten in every group.
    - Break-even ratios narrow; upstream is about level with the frontier push under either closure.
- **F0: the flow model's engine is ported to R** (`functions_flow.R`), with inputs exported from the TypeScript as JSON (`code/tradeable_jobs/flow_model/`).
    - It matches the TypeScript's own output on all 27,016 standard rows across the baseline and ten experiments (`22_flow_model.R`): relative differences of 1e-10 or less.
    - The original was run with Node 26's type stripping, with one class patched in a scratch copy, not in the modelling repo.
- **T9's slack half** (`23_t9_flow_slack.R`; section 17).
    - Demand policies raise local and national incomes. Town-only procurement keeps 74% of the real gain in the town, inward investment 79%.
    - Productivity gains with demand unchanged cost jobs and GDP.
    - Everyday-services productivity still raises real income through prices (the town keeps 99%). Exporters' productivity loses income, because the model's exports are fixed quantities.
    - Slack and base barely differ: wages and prices don't respond to unemployment.
- **Mistakes caught:**
    - the report's T6 bullet was drafted before the results and said Model F agreed with the data on job losses. It doesn't, because Cobb–Douglas demand gives none, and the bullet was corrected;
    - after the refactor, T10's local break-even joined a share the runs now carried themselves, duplicating a column (simplified);
    - tiny differences printed as long decimals in the report (now scientific notation).

**14 November 2026, morning: a tight flow model, local services, Model A and agglomeration** (commit `6585d4f`, 09:45).

- **The flow model got two optional extensions,** both off for the port's check, which still matches:
    - export quantities that respond to price (elasticity 2);
    - a wage curve on local unemployment (elasticity 0.1), moving 30% of the way each period.
- **With them, T9 has a tight economy** (exports +20%, unemployment about 0.9%):
    - Town-only procurement then gives the town 130% of the national real gain. That is crowding-out of other places, C13 appearing only when labour is tight.
    - The town's everyday-services productivity no longer pays the town: freed workers push local wages down.
    - Business-service productivity pays (+0.55% to +0.70%) once exports respond to price.
- **Model F's local services got an elasticity of 3 between places** (`24_modelF_local_sigma.R`), with trade costs moved to keep their cross-place share.
    - The section 16 quirk goes: retail jobs −1.6% when the lagging place alone improves, not +11.6%. With people immobile, the place keeps 75–95% of the gain.
    - National results and break-even ratios barely change (long tail 0.78, upstream 0.91, local services 0.64).
- **Model F with agglomeration** 0.02 and 0.03 (`26_modelF_agglomeration.R`; section 16). It solves, and tilts the break-even ratios slightly towards the frontier push (long tail 0.78 → 0.74). Local shares are unchanged.
- **Model A with supply chains** (`25_modelA_supply_chains.R`; section 11). Tradables buy γ of the non-tradable per unit of output.
    - E falls from 28.9% to 22.2% of cities, and X from 50% to 37.2%, as γ goes from 0 to 0.3.
    - Raising non-tradable productivity 10% widens the range at both ends and raises real income about 7%. It is not an escape from lock-in, matching Model F's verdict on C8.
    - Round 1's Model A results are unchanged.
- **Mistakes caught:**
    - the wage curve's first version cycled in a tight economy (a cobweb: high wages cut exports, then jobs, then wages), fixed with partial adjustment;
    - its 1% unemployment floor then pinned the tight economy, so no policy could move wages (the floor is now 0.5%);
    - two report lookups matched both "P4 local services" and "P4 with P9", printing an NA (patterns anchored).

**14 November 2026, late morning: solvers for multiple equilibria** (Dan asked; commit `e72a75d`, 11:20; `functions_solvers.R`, `27_solvers.R`; section 18).

- **Before this,** each model had one solver:
    - a grid scan and root-finding (Model A);
    - Newton (B);
    - damped wage adjustment from one start (C/D, F);
    - root-finding (DFS);
    - fixed-point iteration (flow model).
- **Added:**
    - a fixed-labour mode in Model F, and the model split into that inner problem and an outer best-response map;
    - hill climbing (adaptive, or fixed-step for large problems), residual search (Nelder–Mead then Newton), brute force on a grid, and continuation;
    - stability by perturbation, plus eigenvalues for interior equilibria.
- **Test case** (two places, two sectors, agglomeration 0.3): three equilibria, as theory says.
    - The model's own solver settles on the unstable symmetric one, or fails from asymmetric starts.
    - Hill climbing finds the two stable ones, residual search the unstable one, brute force all three.
    - Multiple equilibria start at agglomeration of about 0.3, 0.2 and 0.15 for mobility 10, 50 and 200.
- **Full Model F:** the old solver fails from 0.04; continuation solves to 0.3.
    - Unique at 0.1; three stable equilibria at 0.2 and four at 0.3. They differ by up to 2.7% of workers (finance leaving place 11) but under 1% in welfare.
    - The long-tail proxy's break-even is 0.90–0.93 from equilibria where it tips the economy into another, and 0.74–0.75 from the others. Upstream and local services barely depend on the starting point.
- **Mistakes caught:**
    - the first stable equilibria sat at corners (complete specialisation), which the log-share search could never reach (now judged in shares, with a floor);
    - a tolerance passed through `...` was taken by the clustering function's own argument, which split one equilibrium in two and wrongly marked some unstable (renamed);
    - warm-started inner solves gave inconsistent welfare levels (outcomes now use fresh starts);
    - the adaptive hill climb stalls at high mobility (a fixed-step version for large problems).

**14 November 2026, midday: the synthesis** (Dan agreed the order: commit the log, write the synthesis, then strong agglomeration over many draws).

- **A new opening section of the report, "The answer so far",** pulls the tests together against the hypothesis. Its numbers come from the cached results, not typed in.
    1. As a national priority rule, "tradables first" doesn't hold:
        - most leverage is outside the exported products;
        - business-to-business sectors feed exporters;
        - the long tail has about 4.6 times the frontier's room;
        - with demand fitted to UK data, upstream productivity is about level with the frontier push per point.
    2. Productivity in the broader sectors carries costs the shorthand misses: jobs in the improving sector, lost GDP when the economy is slack, an official lens that hides the gain, and land taking a similar share either way.
    3. Local and national strategy align only in some conditions:
        - local services with people staying put;
        - not nationally traded business services;
        - not when people are mobile;
        - demand policy only when labour is slack.
    4. For round 1's question: the tradable split is a poor guide; the trade closure (a Ricardian terms-of-trade question) is the biggest modelling choice; Venables's lever doesn't work.
    5. What's robust, what depends on modelling choices, and what's unknown (the cost of a point).
- **Mistakes caught:** the summary table's local-services column picked up the "P4 with P9" rows and showed NA, and one section reference was wrong. Both fixed before commit.

**14 November 2026, afternoon: strong agglomeration over six draws** (step 3 of the order Dan agreed; `28_strong_agglomeration_draws.R`; section 18, and the synthesis's table and "How sure to be").

- **The run.** Section 18's steps for productivity draws 101–106, in parallel (about an hour):
    - continuation to agglomeration 0.3;
    - six scrambled starts;
    - the four proxies from every stable equilibrium.
- **Equilibria.**
    - Every draw has 2–5 stable equilibria, 21 in all. Continuation and every start converged.
    - Most were found by a single start, so the counts are lower bounds.
    - Within a draw they differ by 2.3–5.8% of workers in one place-sector, and in welfare by at most 0.6%, except one draw (1.4%).
- **Switching.** A proxy switches when some place-sector's share of all workers moves by more than 1 point.
    - The long-tail proxy switched from 8 of 21 starting equilibria, in 3 of 6 draws. It gains when it does: break-even 0.90 against 0.69 when it doesn't, and the comparison holds within draws. Its switches don't start from worse equilibria than its non-switches.
    - The frontier push switched from 2 of 21:
        - once out of a draw's worst equilibrium (1.4% below the best), with 2.35 welfare points per point against 1.63 from the draw's other equilibria;
        - once for slightly less than from the draw's other equilibria (1.52 against 1.56–1.60).
    - Upstream and local services never switched.
- **Averages barely move.** Mean break-evens are 0.77 (long tail), 0.95 (upstream) and 0.68 (local services), against 0.74, 0.90 and 0.63 at agglomeration 0.03. Strong agglomeration adds spread, not a different ranking.
- **Answer to the question set.** Policy-driven switching is common for broad catch-up and rare for the frontier push. On balance it favours broad catch-up, but the biggest single gain from a switch was the frontier push's.
- **Mistakes caught:**
    - a tibble column named `eq` masked the table of equilibria inside `tibble()`, so every draw errored at the policy step (the first run was lost);
    - the by-proxy summary named its count column `switched` before using `switched`, the same summarise() ordering bug as in T2 (fixed: counts last);
    - the cache key was the whole script, so editing the summaries would rerun the hour of draws. It is now the draw function's code and settings. A first version of that key also changed with the report's `scipen` option, because `deparse()` writes 1e-8 differently, so the render started the draws again (the key now fixes `scipen`).

**Status after these entries.** Six round 2 commits are on `master` but not pushed: `bc81fec`, `77a128f`, `c1a4134`, `6585d4f`, `e72a75d` and `ea25170`. The synthesis and the six-draw work are not yet committed.

**Not done:**

- the flow model's lenses beyond the standard rows, and its calibration routine;
- calibrating the flow model's export elasticity and wage curve to its own economy;
- more starts per draw with strong agglomeration (most equilibria were found by one start);
- retrying round 1's local-rent case with the new solvers;
- regional input–output coefficients, needed for T3's regional version and T5's multipliers;
- the household round of T5.
