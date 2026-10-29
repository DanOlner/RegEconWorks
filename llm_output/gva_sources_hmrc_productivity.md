# How UK GVA is built, where HMRC data fits, and what feeds regional productivity

Claude Code research output, 25 October 2026, for the regional GVA uncertainty work. Sources are listed at the end. Where something is my own inference or calculation rather than a statement from ONS, it is marked as such.

The VS Code session that did this research crashed before it could save, leaving two drafts. This is the later one, which finished all the planned checks, with sections 10 and 11 and a few caveats merged in from the other. Section 3.1, on ONS's 2009 regional GVA inventory, was added afterwards. So were parts of section 4, on corporation tax, income-approach firm GVA and recent work on VAT purchases (28 October 2026).

One source I could not read. The ChatGPT thread renders only its title ("Explain ONS productivity method") and its backend returns 403, so sections 6 and 7 answer the productivity question from ONS documentation instead.

This builds on [abs_v_regbyindustry.md](abs_v_regbyindustry.md) (why ABS and regional GVA levels differ) and [abs_direct_uncertainty_planner.md](abs_direct_uncertainty_planner.md) (ABS standard errors at ITL1). Section 10 corrects some points in the first of these and in chunk 1.

## Short answers

- **How is UK GVA worked out?** Nationally, ONS measures GDP three ways (output, income and expenditure) and reconciles them each year in supply and use tables (SUTs). For most market industries, the level of output comes from the Annual Business Survey (ABS) and other annual benchmarks. Movement within the year comes from the Monthly Business Survey (MBS) and, for small and medium firms, from VAT turnover. Regional GVA then takes each national component, industry by industry, and shares it out using a "regional indicator": a dataset used only for its regional proportions. Two regional estimates are built this way, by the income approach (GVA(I)) and the production approach (GVA(P)). They are blended into the published balanced figure, GVA(B), using quality weights that are partly built from survey coefficients of variation (CVs).
- **What are the "hundreds" of datasets?** The phrase is from ONS's 2018 article on modelling in regional GVA. It says "over 400 input datasets" are used, but "only relatively few of them have a weight sufficient to be worth considering". No published list names all of them for annual regional GVA. The closest is the annex to ONS's 2017 balancing paper, which lists about 100 component and indicator rows with their weights across 33 industries. Section 3 lists every breakdown I found, including two source catalogues ONS published in 2026 for other GDP products.
- **Does ONS calculate firm-level GVA from HMRC data?** Not in anything published that I found. HMRC data enters regional GVA in four ways:
  - self-assessment profits of sole traders and partnerships;
  - VAT turnover growth, used to project the latest year;
  - VAT turnover, used to split ITL3 and local authority figures by industry;
  - the business register (IDBR), which is built from VAT and PAYE registrations and supplies the employment counts used to place multi-site firms' activity.

  ONS has held VAT purchases data (box 7) since at least 2016 and looked at using it for intermediate consumption. In December 2018 it said it was "too early to give any firm commitment or timescale". In 2025 and 2026 it said it is testing VAT purchases for early national estimates of intermediate consumption, but no published GVA uses them yet. Corporation tax data feeds national company profits, not regional GVA, and ONS gets it only as industry totals, not company records (section 4).
- **Can ONS get more granular and accurate firm GVA than the ABS? Is it HMRC data?** More complete coverage, yes: VAT returns cover about 2 million registrations with no sampling error. But they give turnover and purchases, not GVA, and they are filed by VAT unit, not by site. To place VAT turnover in a region, ONS splits it across a firm's sites by site employment on the business register, which is the same kind of assumption the ABS relies on. So HMRC data doesn't solve the multi-site geography problem, and it adds problems of its own: head offices, VAT groups and volatility. ESCoE's 2025 review of the VAT-based quarterly regional GDP found weak links to annual regional GVA in many industries.
- **What GVA goes into regional productivity, and what does that do to error?** ONS divides GVA(B) by "productivity hours" or "productivity jobs", which are built from the LFS, APS, BRES and short-term employment surveys. It uses GVA(B) at current basic prices for levels and chained volume GVA(B) for real growth. The error in that ratio depends on how far the numerator and denominator share sources. Where GVA is shared out by employment or pay, regional productivity differences are largely set by assumption, and their measured error is misleadingly small. That applies to public administration, much of health and education, finance, and multi-site firms. Where GVA comes from the ABS and hours from the APS, the two errors roughly add.

## 1. National GVA: the total that gets shared out

- **Three approaches, one framework.** The GDP quality report says the three measures "become coherent in the long-term through the use of a supply and use framework". Recent years are provisional until they have been through SUT balancing. The September 2026 regional release still calls 2024 provisional for this reason.
- **Output approach.** "The overall level of output is still derived from the Annual Business Survey (ABS) and other annual benchmark sources" (GDP QMI, last revised April 2022). Short-term movement comes from the MBS, and since 22 December 2017 also from VAT turnover. VAT is used for growth rates only, and only for the smaller size bands; large firms stay on the MBS.
- **How much VAT is in national output now.** ONS's GDP(O) source catalogue for Blue Book 2026 (published 15 October 2026) lists the source behind every output series, with its weight in parts per thousand. Its summary tables show:
  - the MBS is the current-price source for about 51% of GDP(O) weight;
  - government spending accounts for about 16% and household spending about 12%;
  - VAT is used in series covering about 36% of the weight: 70 of 124 parts per thousand in production, 29 of 57 in construction and 262 of 812 in services.
- **Income approach: company profits use corporation tax data.** Private non-financial companies' gross operating surplus is benchmarked each year on gross trading profits from HMRC corporation tax returns. These cover "over 98%" of businesses but arrive about two years late, and ONS applies "over 30 adjustments" to fit national accounts concepts (OSR, January 2024). The quarterly profits survey was discontinued in April 2020. ONS gets totals, not company records: "HMRC currently provides ONS with aggregate trading profit data (gross operating surplus) for Standard Industrial Classification 2007 (SIC 2007) at a two-digit level on an annual basis" (ONS, July 2017). OSR's 2024 review describes the same arrangement. HMRC removes financial companies and public corporations, and "supplies figures aggregated by company account periods ending on a calendar year basis".
- **No error measures.** "We do not publish a measure of the sampling error or non-sampling error associated with GDP" (GDP QMI).

## 2. Regional GVA: sharing out national totals

### 2.1 The mechanism

National control totals come from the SUTs for 112 industry components (Regional Accounts Methodology Guide, 2019). "A regional indicator is a dataset that provides regional proportions, which in turn are used to allocate national totals" (GVA(B) QMI). So only each indicator's regional *distribution* matters, not its level. That's why ABS aGVA levels and regional GVA levels differ even where the ABS is the indicator. GVA(I) is compiled down to ITL3. GVA(P) is compiled only to ITL2.

### 2.2 Income approach, GVA(I)

| Component | Main regional indicators (2019 methodology guide, 2017 balancing paper) |
|---|---|
| Compensation of employees | ASHE earnings × BRES employee counts for most industries; ABS employee costs for manufacturing; Defra for agriculture; LFS for households as employers; MoD and Civil Service data for the forces and Extra-Regio |
| Gross trading profits of companies | ABS operating surplus; for finance and public industries, compensation of employees or wages; Oil and Gas Authority (Extra-Regio); BERD for R&D |
| Mixed income (self-employed) | HMRC self-assessment sole-trader profits for most industries; ABS for manufacturing; Defra for agriculture |
| Partnerships' profits | HMRC self-assessment partnership profits |
| Rental income | Non-domestic rates for businesses; house prices and dwelling stock for households, including imputed rent |
| Taxes on production | Business rates, vehicle excise duty and about 20 smaller levies |
| Public corporations' surplus | BRES public-sector employment |

In 2014, ASHE carried 23.4% of GVA(I)'s weight, BRES 23.6%, the ABS 21.7% and other sources 31.3% (2017 balancing paper, Table 1). Compensation of employees is about half of GVA(I), and most of it is allocated by BRES jobs × ASHE pay.

### 2.3 Production approach, GVA(P)

Output and intermediate consumption are allocated separately for each industry, and GVA(P) is the difference. The ABS regional split is the indicator for most industries. The exceptions are:

- agriculture: Defra;
- banking: Bank of England fees and interest margins, at ITL1 only;
- other finance: compensation of employees;
- public sector: BRES jobs × ASHE pay;
- sole traders in construction, transport, hotels and catering, information and communication, and professional services: HMRC data;
- R&D: BERD;
- real estate and imputed rent: house prices;
- households as employers: LFS.

In 2014 the ABS carried 70.8% of GVA(P)'s weight, BRES (public sector) 12.7% and others 16.5%. The 2018 article gives similar shares from a different cut: ABS about 71%, BRES about 7%, ASHE about 6%, rental data about 9%, HMRC self-assessment about 3%.

### 2.4 Balancing into GVA(B)

This is from the 2017 balancing paper (Fenton and West), repeated almost word for word in the methodology sheet of the September 2026 quality-metrics workbook.

1. Balance at the most detailed level both approaches share: ITL2 × 33 industries.
2. Weight each component by its UK national share, taken from the Blue Book, so the weights aren't changed by the regional process.
3. Give each component a quality score from 0 to 1.
   - For components whose indicator comes from the ABS, ASHE or BRES, the score is `(100 − 2 × CV) / 100`, floored at 0, so a CV of 50% or more scores zero.
   - Every other component gets a fixed A, B or C rating (0.9, 0.7 or 0.3), which is the same for all regions and years. HMRC self-assessment data is rated B. In the 2017 test data, components rolled forward from the previous year were rated C.
4. Each approach's quality = Σ (component weight × component quality).
5. GVA(B) = the mean of GVA(I) and GVA(P), weighted by their two quality scores, for each region, industry and year.
6. "Apply any necessary manual intervention to address anomalous results." A network of regional statisticians and economists reviews the estimates, and the paper quotes von Moltke: "No statistical plan survives contact with the data".
7. Push the balanced totals back down to detailed industries and components, constraining iteratively until everything adds up.

### 2.5 The latest year

GVA(P) for the newest year has no ABS data yet. Since the first GVA(B) release in December 2017, ONS has projected it forward with VAT turnover growth: "We have used the annual growth in turnover between 2015 and 2016, as measured by the Value Added Tax (VAT)". The 2017 paper rated this method B. The September 2026 release says 2024's regional industry estimates were made "by applying growth in" GDP output industry figures and then constrained.

### 2.6 Below ITL2

The 2017 paper says the income approach provides the ITL3 estimates, which are "the starting point" for local authorities. Since December 2018, ONS has used "administrative turnover data from Value Added Tax (VAT) records to inform the detailed industry breakdown of regional GVA to the NUTS3 and local authority levels". The current QMIs don't describe this step in detail.

The experimental small-area method (December 2021) is explicit. VAT turnover is "allocated between the sites of a business according to the relative share of the total workforce", which "assumes workers across all sites contribute equally to a company's gross value added".

### 2.7 Real terms

Current-price GVA(P) is deflated industry by industry with national deflators, because "no regional price indices are currently available". It is singly deflated and constrained to national chained volume totals (2019 methodology guide). The September 2026 release changed how regional GDP, as opposed to GVA, is deflated.

### 2.8 What ONS says about accuracy

"It is not currently possible to define the accuracy of the estimates in terms of detailed statistical properties … the reliability of the estimates is measured by the extent of revisions" (GVA(B), GVA(P) and GVA(I) QMIs). The 2009 inventory (section 3.1) used almost the same words, and added: "It is important to note that there are other aspects of accuracy, which revisions analysis cannot attempt to measure. A value can be reliable (meaning 'not revised') without being accurate."

The 2018 article estimated that, for 2014:

- GVA(I) was about 32% observed directly by region, 51% estimated by sampling and weighting, and 17% modelled (apportioned from larger areas);
- GVA(P) was about 23% observed, 49% estimated and 29% modelled.

## 3. The "hundreds" of datasets: what is actually written down

The 2018 article: "The UK Regional Accounts measure of gross value added (GVA) is a very complex statistic that combines two independent measures, each compiled using hundreds of input datasets" and "there are over 400 input datasets that are used across the income and production measures". It doesn't publish the list.

| Document | What it breaks down | Notes |
|---|---|---|
| [ONS 2018, extent of modelling in regional GVA](https://www.ons.gov.uk/economy/grossvalueaddedgva/articles/analysisoftheextentofmodellingandestimationinregionalgrossvalueadded/2018-03-28) | Principal sources and their shares; observed, estimated and modelled shares by region and SIC section (Tables 1 to 15) | 2014 data |
| [Fenton and West 2017, balanced regional GVA consultation paper](https://consultations.ons.gov.uk/national-accounts/consultation-on-balanced-estimates-of-re/supporting_documents/development-of-a-balanced-measure-of-regional-gross-value-addedpdf) | Annex A lists every component and indicator with its 2014 weight in each of 33 industries. Annex B gives each one's quality rating | I count 97 rows: 77 income, 20 production. They run from ABS operating surplus down to training-board levies, the Crossrail business rate supplement, illegal drugs and prostitution |
| [Regional Accounts Methodology Guide, June 2019](https://www.ons.gov.uk/economy/regionalaccounts/grossdisposablehouseholdincome/methodologies/regionalaccountsmethodologyguidejune2019) | Tables 2 to 12: indicator by component and industry for GVA(I) and GVA(P); deflation; balancing | The fullest current-method description |
| [Regional GVA Inventory for the United Kingdom, September 2009](https://www.ons.gov.uk/file?uri=%2Feconomy%2Fregionalaccounts%2Fgrossdisposablehouseholdincome%2Fmethodologies%2Fregionalaccounts%2Finventorywebversionfeb1tcm7722032tcm77253853.pdf) | Sources and methods of the old income-only method, in Eurostat's standard format | Names the main indicator sources. Its compilation table is a separate spreadsheet, not in the PDF. See section 3.1 |
| [Regional GVA(B) quality metrics, September 2026](https://www.ons.gov.uk/economy/grossvalueaddedgva/datasets/regionalgrossvalueaddedbalancedqualitymetrics) | Aggregate quality scores only, not the component list | See section 8 |
| [Quarterly regional GDP data source catalogue, July 2026](https://www.ons.gov.uk/economy/grossdomesticproductgdp/datasets/quarterlyregionalgdpenglandandwalesdatasourcescatalogue) | Source, geography, measure and frequency for 141 industry rows | VAT is the source for 66 rows. 88 rows are regional data and 29 are UK data shared out to regions |
| [GDP(O) source catalogue, Blue Book 2026](https://www.ons.gov.uk/economy/grossdomesticproductgdp/datasets/gdpodatasourcescatalogue) | National output approach: source, frequency, deflator and VAT use for 20 sections, 110 industries and 153 lower-level series, with weights | National only |
| [VAT industry selection matrix](https://www.ons.gov.uk/economy/grossdomesticproductgdp/datasets/vatindustryselectionmatrix) | Which industries and size bands use VAT in GDP(O) | Latest edition February 2024 |
| [ESCoE TR-27, Table 1](https://www.escoe.ac.uk/publications/regional-gdp-review/) | Industry by industry: sources for quarterly regional GDP, UK quarterly GDP and Scottish Government GDP side by side | A good one-table view |

My inference, not stated by ONS: about 100 indicator rows, many applied separately across 33 or more industries and at several geography levels, makes "over 400 input datasets" plausible as a count of input series rather than 400 distinct surveys. The 2018 article's own point stands either way: three ONS surveys (ABS, ASHE and BRES) carried 69% of GVA(I) and 84% of GVA(P) in 2014.

### 3.1 What the 2009 inventory adds

ONS's Regional Accounts branch compiled this inventory in Eurostat's standard format (*Regional GVA Inventory for the United Kingdom*, September 2009, by Joshua Abramsky, Kenneth Carey and Marc Carlton). It describes the method used before the production approach and balancing were added. Regional GVA was then "compiled exclusively using a top-down approach and the method of compilation is completely income-based". The UK and Ireland were the only EU countries using the income approach. There was no real-terms regional GVA at all, because "satisfactory deflators for profits … are not available", and a production-based measure was expected "in 2011 or 2012". Much of the method has changed since, so the details matter most for older vintages and the research that used them.

- **A short list of main sources.** Table 2 names ten: ASHE, the Short-Term Employment Surveys (STES), PAYE data, the two parts of the Annual Business Inquiry (which became BRES and the ABS in 2009), the Farm Business Survey, the LFS, armed forces data from DASA, onshore oil and gas data from DECC, and HMRC self-assessment returns. Other components use business rates, dwelling stock values (for household rent, including imputed rent), vehicle licensing and a few smaller administrative series. Pay was about 60% of GVA, operating surplus and mixed income about 37%, and taxes on production about 2.4%. For "a fuller assessment of the relative contribution of these items", the inventory points to a compilation table in "a separate spreadsheet" (its Appendix 1), which isn't in the PDF. I haven't looked for it.
- **HMRC data was central, but only for regional shares.** The inventory names PAYE and self-assessment data, alongside the ABI, STES and ASHE, as "the main datasets used".
  - PAYE: "Anonymised wages and salaries data from a 1% sample of PAYE records are supplied to ONS". Regional pay totals at NUTS1 were constrained to HMRC data, which also drove the commuting adjustment for London, the South East and the East of England.
  - Self-assessment: all returns were used, 3.15 million from sole traders and 1 million from partners for 2006/07. Each was placed at the filer's home address, "because this is the legal requirement of the self-assessment process". So these indicators measured where the self-employed live, and no adjustment was made for the workplace-based figures ONS published. ONS was discussing a switch to business addresses with HMRC.
  - Business locations came from "the addresses given by enterprises when they register to pay VAT … and/or PAYE … and by the addresses given by reporting units for local units on the business surveys".
  - Nothing in it builds GVA for individual firms from tax data.
- **Company profits followed pay.** Except in manufacturing, companies' gross trading profits were shared out by pay: "prorated using wages and salaries from ASHE*STES" in most industries, and by farm pay in agriculture. Only manufacturing used survey profits, from the ABI. Below NUTS1, operating surplus and taxes on production were shared out "using compensation of employees as indicators", apart from manufacturing and most self-employment income. So below NUTS1, most GVA outside manufacturing followed the local pay bill (my reading). Today most companies' profits are shared out using ABS operating surplus (section 2.2).
- **Noise was damped rather than measured.**
  - ASHE earnings cells where "the coefficient of variation is > 15 and/or the sample size is <10" were adjusted automatically. Each was replaced by a blend of its own three-year average (relative to the national figure) and an estimate built from the region's all-industry earnings and the national industry pattern, and "the higher the standard error, the higher the weight on the second variable". Survey CVs were already being used inside the method, as they are in today's balancing (section 2.4).
  - The recommended "headline" figures were a five-year weighted moving average (weights of 3/27, 6/27, 9/27, 6/27 and 3/27 centred on the year, with fewer years at the end of the series), because "sampling error is unavoidable in the survey inputs (and in the 1% PAYE samples)".
  - Part-time pay was multiplied by 0.8 "to damp the volatility of this variable".
  - Of the sample sources, only ASHE and the ABI came with CVs, and only the LFS with confidence intervals. STES, the Farm Business Survey and the PAYE sample had neither.
- **Accuracy: the same statement as now, and one chart.** The inventory's accuracy wording is almost the same as today's QMIs (section 2.8). Its only evidence is a chart of revisions to 2006 GVA, from provisional to final estimates. Read by eye, the UK total was revised up about 2% and London about 9%, but only about 1.5 points of London's revision came from the regional indicator data. The rest came from Blue Book changes to the national totals. Revisions from the indicator data alone were within about ±1.5% for every region. So that year's national revision landed mostly on London rather than evenly, presumably because the revised industries were concentrated there (my reading of the chart).
- **Some long-lived assumptions.** Farmers' non-farming income, and farming by non-farmers, were shared out using regional proportions "from a survey carried out in 1989". Armed forces pay had been extrapolated since a 2002 national estimate. Offshore oil and gas pay assumed "all actual extraction is offshore and all related services are onshore, and that average pay is the same in both".

## 4. HMRC data in GVA

| HMRC source | What ONS gets | Where it is used | How it is placed in regions |
|---|---|---|---|
| VAT returns | Box 6 turnover from every return, monthly, as raw data. Box 7 "total value of purchases and all other inputs" is also held | GDP(O) growth for small and medium firms. Regional GVA(P) latest-year projection. ITL3 and local authority industry split. About 70% of quarterly regional GDP inputs. Small-area GVA. Keeps the IDBR up to date, and IDBR turnover is an auxiliary variable in ABS weighting | VAT number → IDBR enterprise (over 99% matched). Split to reporting units by registered employment, then to sites by IDBR site employment |
| PAYE | Registrations; ASHE's sample (1% of employee jobs from PAYE records); Real Time Information (RTI) | IDBR frame; ASHE (and so compensation of employees); RTI in experimental UK productivity and household income. "Through 2025, the ONS has secured access to the HMRC PAYE RTI data feed and we have begun comparative analysis with our existing compensation of employees (CoE) data sources" (ONS, December 2025) | Not found as a direct regional GVA indicator now. The 2019 guide says PAYE was the main indicator for residence-based GVA(I), which stopped in 2014. In 2009, NUTS1 pay totals were also constrained to HMRC data (section 3.1) |
| Self assessment | Sole-trader and partnership profits, described as "a virtual census of the self-employed workforce" | GVA(I) mixed income and partnership profits (about 7% of GVA(I)); GVA(P) sole traders in some industries (about 3%) | Rated B in balancing. In 2009 HMRC placed them at the filer's home address, and ONS was discussing a move to business address (section 3.1). I haven't found whether that changed |
| Corporation tax | Gross trading profits as totals by two-digit industry, not company records. Excludes financial and public corporations. About 2 years late | National company profits benchmark | Not used regionally. Companies' regional profits come from ABS operating surplus |

### Is any of this firm-level GVA?

HMRC holds the makings of firm-level value added in two forms:

- **Production approach:** VAT turnover minus VAT purchases (boxes 6 and 7). This is the same idea as ABS aGVA.
- **Income approach:** PAYE pay plus company profits from corporation tax returns and the accounts filed with them. Self-assessment covers sole traders and partnerships.

An earlier draft of this note called VAT purchases "the only HMRC source that could support a firm-level value-added measure". That was wrong: the income approach could too. ONS uses neither at firm level.

Here is the trail on VAT purchases:

- **July 2016:** ONS says it will analyse box 7 "as an estimator of intermediate consumption, where practical".
- **October 2018:** "Feasibility work is underway to explore how these data could be used as a proxy for purchases or intermediate consumption", with "significant conceptual challenges to overcome". ONS also planned to "use both VAT turnover and expenditure data to produce GVA(B)" for very small areas.
- **December 2018:** "it is too early to give any firm commitment or timescale".
- **May 2021:** ONS researchers built firm-level "VAT-approximated value added" (vGVA = VAT turnover – VAT expenditure) for a panel of 1.5 million VAT filers, to see how firms' turnover and purchases moved during the pandemic (ESCoE TR-11, Barrand, Daniel, Dey-Chowdhury and Walton). They stress that "This VAT concept of expenditure is not the same as the intermediate consumption concept". VAT purchases include capital spending and goods for resale, and they miss exempt businesses, flat-rate filers and unregistered businesses.
- **December 2021:** the small-area GVA method uses turnover only.
- **December 2025:** "For the measurement of intermediate consumption in short-term GDP(O) estimates, we view VAT as the most promising option and where we will see the biggest gain" (ONS update on OSR's GDP review).
- **August 2026:** "We are investigating the use of Value Added Tax (VAT) purchases data, linked to our Quarterly Acquisitions and Disposals of Capital Assets survey (to remove capital purchases which do not count towards intermediate consumption), to provide estimates of intermediate consumption within three months of the quarter ending" (ONS blog, Walton and Dey-Chowdhury). Early GDP currently assumes turnover moves with GVA until the annual surveys arrive.

And on corporation tax:

- **ONS doesn't get company records.** It gets industry totals (section 1). In July 2017 ONS called corporation tax data its "preferred solution" for measuring company profits, and said "micro-level data must be used rather than pre-defined aggregated totals" to get the full benefit. It also suggested using VAT and PAYE RTI data to project profits forward until the tax data arrive. OSR's 2024 review still describes totals. In December 2025 ONS said it is "seeking opportunities to improve early estimates of private non-financial corporations (PNFC) gross operating surplus (GOS)", and that "We rely on other government departments and private organisations sharing their data with us to move this work forward".
- **Taxable profit isn't operating surplus.** "A Corporation Tax Computation fundamentally converts accounting profit into taxation trading profit" (ONS, 2017). Taxable profit deducts capital allowances instead of depreciation, and is reduced by losses carried forward from earlier years and by group relief. So a company can show no taxable profit in a year when its operating surplus is positive. ONS makes "over 30 adjustments" to the totals (section 1).
- **It arrives late.** Companies have 12 months after their accounting year to file, and accounting years don't match calendar years. In 2017 HMRC delivered totals 16 months after the end of the calendar year.
- **It is filed by company, not by site.** A group can book its pay in one company and its profits in another, and a registered office need not be where the company trades. PAYE doesn't help with geography either: ONS's RTI regional figures "are based on where employees live and not the location of their place of work" (RTI bulletin, October 2026). So placing multi-site firms in regions would still need register site employment, as with VAT (section 5).
- **Workplace location won't be added to PAYE.** In 2022 HMRC consulted on asking employers to report, through RTI, "the office location or normal work base of their employees", to understand "where businesses' real economic activity takes place". Policy and research respondents supported it; businesses called it costly and hard to define for mobile, hybrid and multi-site workers. The government "will not proceed with the approach set out in the consultation". It is looking at other routes instead, including linking business rates to tax records through Digitalising Business Rates.

So firm-level value added from VAT data has been built in ONS research, but no published ONS GVA uses it, and none uses corporation tax records. What ONS is now testing is aggregate: VAT purchases to improve intermediate consumption in early national GDP, and RTI for compensation of employees. Neither is aimed at firm-level or regional GVA. The only firm-level GVA in the official system is ABS approximate GVA (aGVA) for sampled businesses.

Outside ONS, researchers can work with HMRC VAT microdata through HMRC Datalab. A Productivity Institute project led by Giordano Mion (Sussex) uses the VAT panel, which has firm revenue and the cost of materials and services for "roughly 2 million firms", linked to the business register. It is aimed explicitly at granular regional productivity. No outputs are listed yet.

Separately, Russell Black (Department for Business and Trade, King's College London and ESCoE) gave an ESCoE webinar in March 2026 that "combined firm-level VAT turnover and expenditure to create new estimates of firm-level GVA for all UK firms above the VAT threshold", covering 2005 to 2024. It warned that "there are disadvantages in noise and bias". The event page links no paper and mentions no regional results, and I found no paper or slides elsewhere. It extends Black's earlier work with Rebecca Riley and Garry Young, which split UK productivity growth into within-firm and reallocation effects using ABS microdata. That was presented as an ESCoE webinar in January 2025, with slides, and at the 2024 UNSW-ESCoE conference.

The income route has also been built outside ONS. The Business-to-Worker Register (Advani, Dyèvre, Summers and others, CenTax; technical note and ESCoE conference slides, May 2026) links corporation tax, VAT, PAYE and Companies House records in HMRC Datalab for 2002 to 2022. It covers corporations, partnerships, sole traders and public bodies. Its business-level variables include turnover, profits (EBIT and EBITDA), depreciation, investment, wage bill, employees, and "VAT Box 7 purchases and other inputs". Its geography doesn't solve the workplace problem. "Each business-year is located by aggregating its workers' Output Areas (OAs) up to the firm level", and those output areas come from PAYE and Self Assessment home addresses. So firms are placed where their workers live. The register keeps each firm's five most common output areas by worker count, a travel-to-work area and a postcode. The first challenge it lists is that taxable profits on tax returns differ from financial-accounting profits. The authors deal with this by stripping out capital allowances and balancing charges and applying their own depreciation estimates, then check the results against FAME company accounts. Listed limitations include "No systematic corporate-group aggregation yet". The slides say it is "Designed to complement and enhance official statistics".

## 5. Is there anything more granular and accurate than the ABS?

**The ABS.** It samples about 62,000 GB businesses each year (NISRA samples about 11,000 in Northern Ireland). It includes every business with 250 or more employees, and about half the sample carries over from year to year. Results are weighted to the IDBR using register employment or turnover, and register turnover is itself VAT-derived (ABS technical report, January 2024).

**What VAT adds:**

- census-like coverage of VAT-registered businesses, with no sampling error;
- quarterly timing;
- fine industry detail.

**What VAT lacks:**

- It doesn't give GVA, only turnover, plus purchases ONS doesn't yet use.
- It misses businesses below the registration threshold and much VAT-exempt activity.
- It is raw. ONS made "on average 50 manual adjustments to the data each month", and says "the data would be unusable without these adjustments" (VAT QAAD report, 2019).
- It is filed per VAT unit. ONS lists problems with "turnover and employment being attributed to head offices, holding companies or umbrella companies" (quarterly regional GDP methods, July 2026).

**Both sources depend on the register to place activity.** Neither the ABS nor VAT tells ONS which site produced what.

- ABS regional figures come from a regression model. Its inputs are three-digit industry, region and eight size bands. It is fitted on businesses with fewer than three sites and fewer than 100 employees, and constrained to each firm's returned total (ABS technical report, section 5.8).
- Regional VAT figures split turnover by site employment: "Turnover from HMRC VAT returns are apportioned to industry and region based on IDBR local unit employment data" (quarterly regional GDP catalogue, note 3).

About a quarter of local plants belonged to multi-plant enterprises in 2015: 31% in the North East and 21% in London. Register employment for small businesses can be several years old (ONS, April 2018).

**Evidence on accuracy for regional use.** ESCoE's review of the VAT-based quarterly regional GDP (Spowage and Milne, March 2025) found:

- mean absolute revisions to quarterly growth of 1.6 to 1.9 percentage points by region, against 0.12 for the UK;
- that the construction source data correlated with annual regional GVA growth at between 0.46 and 0.87, depending on region;
- that, for one region, 11 of 20 sections correlated below 0.5 with annual regional GVA.

It recommended checking whether "Inter-Departmental Business Register shares used to derive VAT data" are stable. It also warned against using "a regional source just because it exists".

Section 10 sets out what this means for the wording in chunk 1 and in [abs_v_regbyindustry.md](abs_v_regbyindustry.md).

## 6. What GVA goes into regional productivity

The ONS series is [Regional and subregional labour productivity, UK](https://www.ons.gov.uk/economy/economicoutputandproductivity/productivitymeasures/bulletins/regionalandsubregionallabourproductivityuk/2023). The latest edition, covering 2023, was published on 19 June 2025. The 2024 edition has been moved twice and is now due on 24 November 2026. ONS cites geography and deflation changes, then a seasonal adjustment review of new headline UK productivity measures.

**Numerator (QMI, last revised July 2025):**

- GVA(B) "at current basic prices, excluding taxes (less subsidies) on products", consistent with the Blue Book (Blue Book 2024 for the 2023 edition);
- current-price indices (UK = 100) for comparing levels;
- chained volume GVA(B) for real growth;
- subregional current-price series are published both smoothed ("a weighted average of up to five years") and unsmoothed; chained volume series are unsmoothed only;
- geographies: ITL1, ITL2, ITL3, local authority districts, combined authorities and economic regions.

The QMI also says the ITL1 estimates "use GVA in current prices from the output (or production approach)", so it isn't certain which measure feeds the ITL1 industry figures (section 11).

**Denominator:**

- "Productivity jobs" are employees plus self-employed plus HM Forces plus government-supported trainees. Hours are jobs × average hours.
- At ITL1, both come from LFS microdata by region of work, with employee jobs from the short-term employment surveys, constrained to UK totals.
- Below that, a "total jobs" series (BRES employees, APS self-employed, trainees and forces) shares out the regional figures. Employee hours are local authority jobs × ITL3 industry average hours from the APS, constrained to ITL1.

**Quality statements.** These are "official statistics in development". The QMI refers to "the absence of confidence intervals for the subregional productivity data". The 2023 edition warns that the 2023 APS was "of reduced quality". On 30 October 2025, ONS corrected the chained volume ITL2, ITL3 and combined authority tables.

**Imputed rent.** It is inside GVA(B) but has no hours attached. According to search results I didn't follow up, ONS releases from 2018 to 2020 included an alternative productivity series excluding imputed rental, and a 2026 SQW blog cites ONS figures putting imputed rent at 9% to 11% of UK GVA over 1998 to 2023. I didn't check whether current releases still publish the series without imputed rent.

**UK labour input is unsettled.** Since 16 June 2026, ONS has recommended that users "focus on the experimental RTI approach" for UK productivity, because of LFS response problems. That approach uses PAYE RTI worker counts × LFS average hours. Regional figures are constrained to UK totals, so the choice flows down.

## 7. How the GVA inputs shape productivity error

For productivity P = Y / L, with small errors:

`CV(P)² ≈ CV(Y)² + CV(L)² − 2ρ·CV(Y)·CV(L)`

Here ρ is the correlation between the errors in GVA and in labour input. How the GVA was regionalised decides ρ, and sometimes decides P outright.

| Case | How the regional GVA was made | What regional productivity then measures | Error behaviour |
|---|---|---|---|
| A. Independent sources | ABS output and purchases shares (most manufacturing, much market services); hours from LFS/APS | Real differences in output per hour, as far as the ABS sees them | Errors roughly add. Illustration: CV(Y) = 10%, near the median ABS aGVA CV at ITL1, and CV(L) = 5% give CV(P) ≈ 11% |
| B. Shared out by employment | Y_r = Y_UK × E_r / E_UK. Applies to quarterly regional GDP industries 65.1–2, 66 and 92, small-area GVA, and VAT turnover of multi-site firms | Close to the UK figure everywhere, by construction | Employment sampling error cancels in the ratio. The output looks precise, but the real regional differences are unknown, so the error is bias towards the mean |
| C. Shared out by pay bill | Y_r ∝ BRES jobs × ASHE pay. Covers public administration (the "Government" component was 94.5% of GVA(P) in section O in 2014, 42% in P and 58% in Q). Also finance GVA(I): compensation of employees is about 60%, and profits (about 30%) "use the same data as CoE" | Pay per hour, plus the mismatch between BRES jobs and APS/LFS hours | ASHE error plus source-mismatch noise. Differences reflect pay, not output |

Some further points:

- **GVA(B) is a blend.** Most of GVA(I)'s compensation of employees is case C. The more weight balancing gives GVA(I), the more regional productivity tracks pay.
- **Below ITL2 there is no GVA(P).** ITL3 and local authority figures rest on the income approach plus VAT turnover split by employment, so cases B and C weigh more heavily in subregional productivity.
- **Smoothing.** A five-year weighted average cuts sampling noise. About half the ABS sample overlaps from year to year, so errors are positively correlated and the cut is smaller than the textbook square-root-of-n gain. Smoothing also blurs turning points.
- **The latest year is weaker.** It is projected rather than measured, and ONS's own quality scores fall sharply for it (section 8).
- **National deflators.** Real productivity uses UK industry deflators, so real regional differences within an industry show no regional price effects.
- **Revisions are the error we can see.** Gouma, McCann and Ortega-Argilés (International Productivity Monitor 48, 2025) looked at the June 2024 release. It showed London output per hour falling 0.9% a year over 2019 to 2022, made up of GVA falling 0.3% a year and hours rising 0.6% a year, while London's population fell. Between the 2023 and 2024 releases, nominal GVA was "the most heavily revised" component, especially downwards for London and Wales. Inner London West's 2021 growth in GVA per head went from 20.1% to 11.5%. They conclude the convergence story more likely reflects "the quality and reliability of the official statistics in development". ONS's reply (Prothero) agreed it is wise to wait for more years of data.

## 8. A useful find: ONS publishes its balancing quality scores

The [regional GVA(B) quality metrics workbook](https://www.ons.gov.uk/economy/grossvalueaddedgva/datasets/regionalgrossvalueaddedbalancedqualitymetrics) (23 September 2026) gives the paired GVA(I) and GVA(P) quality scores for every ITL2 area × 33 industries × 1998 to 2024. These are the scores used in the weighted mean in section 2.4. This matters for the chunk 1 framing. ONS says accuracy "is not currently possible to define", yet it does use survey CVs internally to decide how much to trust each estimate, and it publishes the result.

My summary of the file covers 1,157 ITL2 × industry rows with complete numbers, from 37 ITL2 areas. The September 2026 release says ONS suppressed estimates for several ITL2 areas, including West of England and North Wales, because of a problem converting to the new ITL25 boundaries, and that it expected a complete dataset within four to six weeks. That is probably why areas are missing here, but I didn't check area by area.

| Year | GVA(I) score: p10 / median / p90 | GVA(P) score: p10 / median / p90 | Cells where GVA(P) scores higher | Median weight on GVA(P) |
|---|---|---|---|---|
| 2012 | 0.51 / 0.77 / 0.87 | 0.38 / 0.75 / 0.89 | 51% | 0.50 |
| 2019 | 0.51 / 0.76 / 0.88 | 0.31 / 0.78 / 0.89 | 54% | 0.50 |
| 2022 | 0.45 / 0.64 / 0.83 | 0.32 / 0.78 / 0.90 | 78% | 0.53 |
| 2024 (provisional) | 0.31 / 0.39 / 0.69 | 0.50 / 0.70 / 0.71 | 91% | 0.62 |

The next table gives medians across ITL2 areas for 2022, by industry, sorted by GVA(I) score. The "CV-equivalent" column inverts ONS's formula, CV = 50 × (1 − score). This is my crude reading, not ONS's. It is exact only for components scored from a CV, and each aggregate score also mixes in fixed A, B and C ratings.

| Industry | GVA(I) score | GVA(P) score | CV-equivalent I / P (%) |
|---|---|---|---|
| CD Coke and refined petroleum | 0.19 | 0.12 | 41 / 44 |
| CF Pharmaceuticals | 0.31 | 0.38 | 34 / 31 |
| K Finance and insurance | 0.44 | 0.70 | 28 / 15 |
| S Other services | 0.49 | 0.46 | 25 / 27 |
| B Mining and quarrying | 0.51 | 0.63 | 25 / 18 |
| I Accommodation and food | 0.54 | 0.74 | 23 / 13 |
| Q Health and social work | 0.54 | 0.77 | 23 / 12 |
| A (02–03) Forestry and fishing | 0.55 | 0.83 | 22 / 8 |
| R Arts and recreation | 0.56 | 0.80 | 22 / 10 |
| H Transport and storage | 0.56 | 0.79 | 22 / 10 |
| M Professional, scientific, technical | 0.57 | 0.82 | 22 / 9 |
| N Administrative and support | 0.58 | 0.85 | 21 / 7 |
| D Electricity and gas | 0.58 | 0.66 | 21 / 17 |
| J Information and communication | 0.58 | 0.79 | 21 / 10 |
| F Construction | 0.60 | 0.72 | 20 / 14 |
| P Education | 0.63 | 0.85 | 18 / 7 |
| G Wholesale and retail | 0.64 | 0.88 | 18 / 6 |
| O Public administration | 0.65 | 0.77 | 17 / 11 |
| CL Transport equipment | 0.66 | 0.62 | 17 / 19 |
| L Real estate | 0.69 | 0.68 | 16 / 16 |
| E Water and waste | 0.70 | 0.85 | 15 / 8 |
| T Households as employers | 0.70 | 0.30 | 15 / 35 |
| CE Chemicals | 0.72 | 0.71 | 14 / 14 |
| CB Textiles and clothing | 0.75 | 0.80 | 13 / 10 |
| CI Computers and electronics | 0.76 | 0.78 | 12 / 11 |
| CJ Electrical equipment | 0.78 | 0.79 | 11 / 11 |
| A (01) Agriculture | 0.78 | 0.90 | 11 / 5 |
| CM Other manufacturing and repair | 0.80 | 0.82 | 10 / 9 |
| CH Basic and fabricated metals | 0.80 | 0.85 | 10 / 8 |
| CK Machinery and equipment | 0.81 | 0.84 | 10 / 8 |
| CC Wood and paper | 0.82 | 0.84 | 9 / 8 |
| CG Rubber, plastics, non-metallic minerals | 0.83 | 0.87 | 9 / 7 |
| CA Food, drink and tobacco | 0.84 | 0.86 | 8 / 7 |

What this shows:

- **The scores measure trust in each regional indicator.** They don't cover the national total being shared out, the regional allocation model, or the manual adjustments. Public sector scores, for example, reflect the BRES and ASHE CVs, not whether jobs × pay is the right measure of output.
- **The provisional year is much weaker.** Median GVA(I) quality falls from 0.76 (2019) to 0.39 (2024), and balancing leans on GVA(P) instead. Any analysis that leans on the newest year is leaning on the weakest data.
- **The ballpark matches chunk 1.** For manufacturing, GVA(P) CV-equivalents of 7% to 9% are in the same range as the ABS aGVA CVs grafted on in chunk 1 (median about 10% at ITL1 × two-digit), despite the different grain.
- **There are extreme cells.** Inner London West food manufacturing scores 0.02 on GVA(I) for every year from 1998 to 2009.

## 9. What this means for RegEconWorks

- **ABS errors fit only some industries.** ABS sampling error is the right error model for ABS-indicator industries: most manufacturing and much of market services. For the public sector, finance and other industries allocated by labour inputs, it is the wrong error model. Their real uncertainty is in the allocation assumption, which no CV captures. These industries could be flagged separately rather than given ABS error bars.
- **Top-down allocation changes the error structure.** It removes national-level sampling error, because the UK total is fixed from the national accounts. What remains is error in regional shares. For a small region, share error is close to level error. For a region with a large share of an industry (London in finance or information and communication) it is smaller. The planner's finding that regional errors within a division are mildly negatively correlated is relevant here.
- **For productivity, label each industry and region by case.** Use case A, B or C from section 7, before putting error bars on the ratio. In cases B and C a tight interval would be misleading.
- **The ONS quality metrics could be a second, official error proxy.** They are available at ITL2 × 33 industries × year and could be set against the ABS CVs as a cross-check, with the caveats in section 8.
- **Re-check the newest year when it is revised.** The latest year deserves wider bounds or a revision-based check, given the quality drop in 2024 and the regional revision evidence.

## 10. Corrections to earlier notes in this repo

- [abs_v_regbyindustry.md](abs_v_regbyindustry.md), section 4, says the income approach relies on "HMRC (profits data)". The HMRC profits used regionally are self-assessment profits of sole traders and partnerships, about 7% of GVA(I). Companies' profits are shared out using ABS operating surplus, or pay in finance and the public sector. HMRC corporation tax data is used only for the UK total (sections 1, 2.2 and 4).
- [abs_v_regbyindustry.md](abs_v_regbyindustry.md), section 5, describes the ABS regional model as based on register employment, "on the assumption that workers across all sites contribute equally to the company's GVA". The ABS technical report describes a regression model on industry, region and size band (section 5). ONS states the equal-contribution assumption explicitly for its VAT-based small-area method (section 2.6), not in the ABS report. Both depend on register employment.
- Chunk 1 ([maindoc.qmd](../docs/chunks/uncertainty_in_regionalGVA/maindoc.qmd), line 142) says that for multi-site firms "GVA is allocated in proportion to site employment count". That fits the VAT-based methods exactly. For the ABS it's a simplification: the ABS model also uses the site's industry, region and size band, though still not any firm-specific information.
- Chunk 1's health note (line 146) describes public sector GVA as "regional job count multiplied by average wage". That fits public administration and the public-sector part of health. Non-market education is apportioned by pupil numbers weighted by cost (regional GDP QMI, January 2025). The September 2026 release also refined how human healthcare GVA is apportioned, to reflect "the subsidising of NHS prescription charges in the countries of the UK".

## 11. Things I couldn't confirm

Four open points are questions only ONS can answer, so they are listed in section 12: the full list of inputs, how ITL3 and local authority GVA(B) are built now, whether VAT box 7 is used, and whether self-assessment profits are still placed by home address. The others:

- Whether ITL1 productivity by industry uses GVA(B) or GVA(P). The July 2025 QMI mentions GVA(B), but also says the regional estimates "use GVA in current prices from the output (or production approach)".
- Whether the 24 November 2026 productivity release will change the labour inputs (section 6).
- Whether current productivity releases still include a series without imputed rent (section 6).
- What the ChatGPT thread said.
- Where the 2009 inventory's compilation table is: a separate spreadsheet of each item's contribution (section 3.1). I haven't looked for it.

## 12. Questions to put to ONS (regionalaccounts@ons.gov.uk)

- Is there a list of the 400+ input datasets for annual GVA(B)? An updated version of the 2017 Annex A and B, or of the 2009 inventory's compilation table, would do.
- Exactly how are ITL3 and local authority GVA(B) built now? What role do VAT turnover and IDBR site employment play, and how stable are those shares from year to year?
- ONS is testing VAT purchases (box 7) for early national intermediate consumption. Is it used, or planned, anywhere in regional GVA?
- In 2009, HMRC self-assessment profits were placed at the filer's home address, and ONS was discussing a move to business address. Which is used now?
- In 2017 ONS wanted company-level corporation tax data. Has it got it? Has it tested company profits plus PAYE pay as a firm-level measure of value added?
- Could the quality metrics be published at component level, with the underlying CVs?

## Sources

### Regional GVA methods and quality

- [Analysis of the extent of modelling and estimation in regional GVA (ONS, March 2018)](https://www.ons.gov.uk/economy/grossvalueaddedgva/articles/analysisoftheextentofmodellingandestimationinregionalgrossvalueadded/2018-03-28)
- [Development of a balanced measure of regional gross value added (Fenton and West, ONS consultation paper, 2017)](https://consultations.ons.gov.uk/national-accounts/consultation-on-balanced-estimates-of-re/supporting_documents/development-of-a-balanced-measure-of-regional-gross-value-addedpdf)
- [Regional accounts methodology guide (ONS, June 2019)](https://www.ons.gov.uk/economy/regionalaccounts/grossdisposablehouseholdincome/methodologies/regionalaccountsmethodologyguidejune2019)
- [Regional GVA (balanced) QMI (last revised June 2019)](https://www.ons.gov.uk/economy/grossvalueaddedgva/methodologies/regionalgrossvalueaddedbalancedqmi)
- [Regional GVA (production approach) QMI (March 2017)](https://www.ons.gov.uk/economy/grossvalueaddedgva/methodologies/regionalgrossvalueaddedproductionapproachqmi)
- [Regional GVA (income approach) QMI (October 2017)](https://www.ons.gov.uk/economy/grossvalueaddedgva/methodologies/regionalgrossvalueaddedincomeapproachqmi)
- [Regional economic activity by GDP QMI (January 2025)](https://www.ons.gov.uk/economy/grossvalueaddedgva/methodologies/regionaleconomicactivitybygrossdomesticproductqmi)
- [Regional economic activity by GDP, UK: 1998 to 2024 (ONS, 23 September 2026)](https://www.ons.gov.uk/economy/grossdomesticproductgdp/bulletins/regionaleconomicactivitybygrossdomesticproductuk/1998to2024)
- [Regional GVA (balanced), UK: 1998 to 2016 (first GVA(B) release, December 2017)](https://www.ons.gov.uk/economy/grossvalueaddedgva/bulletins/regionalgrossvalueaddedbalanceduk/1998to2016)
- [Regional GVA (balanced), UK: 1998 to 2017 (December 2018)](https://www.ons.gov.uk/economy/grossvalueaddedgva/bulletins/regionalgrossvalueaddedbalanceduk/1998to2017/previous/v3)
- [Measurement of the finance and insurance industries in regional GVA (ONS, April 2018)](https://www.ons.gov.uk/economy/grossvalueaddedgva/articles/measurementofthefinanceandinsuranceindustriesinestimatesofregionalgrossvalueadded/2018-04-09)
- [Disaggregating annual subnational GVA to lower levels of geography (ONS, December 2021)](https://www.ons.gov.uk/economy/grossvalueaddedgva/articles/disaggregatingannualsubnationalgrossvalueaddedgvatolowerlevelsofgeography/2021-12-13)
- [Regional GVA (balanced) quality metrics (dataset, 23 September 2026)](https://www.ons.gov.uk/economy/grossvalueaddedgva/datasets/regionalgrossvalueaddedbalancedqualitymetrics)
- [Regional GVA Inventory for the United Kingdom (Abramsky, Carey and Carlton, ONS Regional Accounts, September 2009)](https://www.ons.gov.uk/file?uri=%2Feconomy%2Fregionalaccounts%2Fgrossdisposablehouseholdincome%2Fmethodologies%2Fregionalaccounts%2Finventorywebversionfeb1tcm7722032tcm77253853.pdf)

### Quarterly regional GDP and VAT

- [Update on reinstating quarterly regional GDP estimates for England and Wales (ONS, July 2026)](https://www.ons.gov.uk/economy/grossdomesticproductgdp/methodologies/updateonreinstatingquarterlyregionalgdpestimatesforenglandandwalesjuly2026)
- [Quarterly regional GDP, England and Wales: data sources catalogue (July 2026)](https://www.ons.gov.uk/economy/grossdomesticproductgdp/datasets/quarterlyregionalgdpenglandandwalesdatasourcescatalogue)
- [Regional GDP Review, ESCoE TR-27 (Spowage and Milne, March 2025)](https://www.escoe.ac.uk/publications/regional-gdp-review/)
- [VAT turnover data in national accounts: background and methodology (ONS)](https://www.ons.gov.uk/economy/grossdomesticproductgdp/methodologies/vatturnoverdatainnationalaccountsbackgroundandmethodology)
- [VAT update, July 2016 (ONS)](https://www.ons.gov.uk/economy/grossdomesticproductgdp/methodologies/vatupdatejuly2016)
- [Future uses of VAT data (ONS Economic Review, October 2018)](https://www.ons.gov.uk/economy/nationalaccounts/uksectoraccounts/compendium/economicreview/october2018/futureusesofvat)
- [QAAD report for VAT turnover data (ONS, April 2019)](https://www.ons.gov.uk/economy/economicoutputandproductivity/output/methodologies/qualityassuranceofadministrativedataqaadreportforvalueaddedtaxturnoverdata)
- [VAT industry selection matrix (ONS dataset)](https://www.ons.gov.uk/economy/grossdomesticproductgdp/datasets/vatindustryselectionmatrix)
- [Meeting the challenge of economic measurement during the COVID-19 pandemic through extended use of administrative VAT data (Barrand, Daniel, Dey-Chowdhury and Walton, ESCoE TR-11, May 2021)](https://escoe-website.s3.amazonaws.com/wp-content/uploads/2021/05/10100649/ESCoE-TR-11.pdf)
- [Update on the Office for Statistics Regulation's review into GDP (ONS, 23 December 2025)](https://www.ons.gov.uk/economy/grossdomesticproductgdp/articles/updateontheofficeforstatisticregulationsreviewintogdp/2025-12-23)
- [Managing the trade-off between timeliness and accuracy in producing our best estimates of GDP (ONS blog, 3 August 2026)](https://blog.ons.gov.uk/2026/08/03/managing-the-trade-off-between-timeliness-and-accuracy-in-producing-our-best-estimates-of-gdp/)

### National GDP, ABS and HMRC

- [GDP QMI (last revised April 2022)](https://www.ons.gov.uk/economy/grossdomesticproductgdp/methodologies/grossdomesticproductgdpqmi)
- [GDP(O) data sources catalogue, Blue Book 2026 (15 October 2026)](https://www.ons.gov.uk/economy/grossdomesticproductgdp/datasets/gdpodatasourcescatalogue)
- [Annual Business Survey technical report (ONS, January 2024)](https://www.ons.gov.uk/businessindustryandtrade/business/businessservices/methodologies/annualbusinesssurveytechnicalreportjanuary2024)
- [Regional firm-level productivity analysis, non-financial business economy (ONS Economic Review, April 2018)](https://www.ons.gov.uk/economy/nationalaccounts/uksectoraccounts/compendium/economicreview/april2018/regionalfirmlevelproductivityanalysisforthenonfinancialbusinesseconomygreatbritainapril2018)
- [Gross operating surplus of private non-financial corporations: current and upcoming work (ONS, January 2024)](https://www.ons.gov.uk/economy/grossdomesticproductgdp/articles/grossoperatingsurplusforprivatenonfinancialcorporationscurrentandupcomingwork/january2024)
- [OSR spotlight on profitability and gross operating surplus statistics (January 2024)](https://osr.statisticsauthority.gov.uk/publication/spotlight-on-quality-assessment-report-profitability-of-uk-companies-and-gross-operating-surplus-of-non-financial-corporations/pages/3), and [its findings on HMRC data](https://osr.statisticsauthority.gov.uk/publication/spotlight-on-quality-assessment-report-profitability-of-uk-companies-and-gross-operating-surplus-of-non-financial-corporations/pages/4)
- [Enhanced financial accounts: improving the measurement of company quarterly profit (ONS, 21 July 2017)](https://www.ons.gov.uk/economy/nationalaccounts/uksectoraccounts/articles/economicstatisticstransformationprogramme/enhancedfinancialaccountsukflowoffundsimprovingthemeasurementofcompanyquarterlyprofit)
- [Earnings and employment from PAYE RTI, UK: October 2026 (ONS, 20 October 2026)](https://www.ons.gov.uk/employmentandlabourmarket/peopleinwork/earningsandworkinghours/bulletins/earningsandemploymentfrompayasyouearnrealtimeinformationuk/latest)
- [Evidence on productivity growth from VAT data for UK companies, 2005–2024 (ESCoE webinar, Russell Black, 19 March 2026)](https://www.escoe.ac.uk/events/evidence-on-productivity-growth-from-value-added-tax-data-for-uk-companies-2005-2024/)
- [Aggregate productivity decompositions using structural business survey data: evidence from the UK (ESCoE webinar, Russell Black, 16 January 2025)](https://www.escoe.ac.uk/events/aggregate-productivity-decompositions-using-structural-business-survey-data-evidence-from-the-uk/), with [slides](https://escoe-website.s3.amazonaws.com/wp-content/uploads/2024/12/17104727/BRY_ESCOE_jan.pdf)
- [The CenTax Business-to-Worker Register: technical note, version 1.0 (Advani, Dyèvre, Gazmuri-Barker, Hughson, Mahajan and Summers, May 2026)](https://centax.org.uk/wp-content/uploads/2026/05/business_to_worker_register.pdf)
- [The Business-to-Worker Register: linking all businesses to all workers in the UK (Dyèvre, Advani, Gazmuri-Barker, Hughson, Mahajan and Summers, ESCoE conference slides, May 2026)](https://escoe-website.s3.amazonaws.com/wp-content/uploads/2026/06/11101541/Arnaud-Dyevre-business_to_worker_register_slides_escoe.pdf)
- [Improving the data HMRC collects from its customers: summary of responses (HMRC, April 2023)](https://www.gov.uk/government/consultations/improving-the-data-hmrc-collects-from-its-customers/public-feedback/improving-the-data-hmrc-collects-from-its-customers-summary-of-responses)
- [UK regional productivity level and growth: from the micro to the macro (Productivity Institute project, Mion)](https://productivity.ac.uk/research/projects/uk-regional-productivity-level-and-growth-from-the-micro-to-the-macro)
- [HMRC Datalab research projects](https://www.gov.uk/government/publications/hmrc-datalab/hmrc-datalab-research-projects-to-date)

### Productivity

- [Regional and subregional labour productivity QMI (ONS, July 2025)](https://www.ons.gov.uk/employmentandlabourmarket/peopleinwork/labourproductivity/methodologies/regionalandsubregionallabourproductivity)
- [Regional and subregional labour productivity, UK: 2023 (ONS, 19 June 2025)](https://www.ons.gov.uk/economy/economicoutputandproductivity/productivitymeasures/bulletins/regionalandsubregionallabourproductivityuk/2023)
- [Regional and subregional labour productivity, UK: 2024 (release page, due 24 November 2026)](https://www.ons.gov.uk/releases/regionalandsubregionallabourproductivityuk2024)
- [UK productivity introduction: January to March 2026 (ONS, May 2026)](https://www.ons.gov.uk/employmentandlabourmarket/peopleinwork/labourproductivity/articles/ukproductivityintroduction/januarytomarch2026andoctobertodecember2025)
- [Regional and subregional productivity in the UK: February 2018 (ONS; includes the ex-imputed-rent series)](https://www.ons.gov.uk/employmentandlabourmarket/peopleinwork/labourproductivity/articles/regionalandsubregionalproductivityintheuk/february2018)
- [Are UK regional productivity disparities really narrowing? (Gouma, McCann and Ortega-Argilés, International Productivity Monitor 48, 2025)](https://csls.ca/ipm-archive/ipm-issue-48/are-uk-regional-productivity-disparities-really-narrowing-an-investigation-into-recent-productivity-data-revisions/)
- [ONS response to the above (Prothero, International Productivity Monitor 48)](https://csls.ca/ipm-archive/ipm-issue-48/ons-response-to-are-uk-regional-productivity-disparities-really-narrowing/)
- [The hidden housing effect: imputed rent and local productivity (SQW blog, 2026)](https://www.sqw.co.uk/Blog/hidden_housing_effect)
