# Why ABS GVA and Regional-by-Industry GVA values differ

Claude Code research output, February 2026. Sources listed at the end.

Prompt for this output is [here](llm_convos/2026-02-16_0952_In_codeABS_error_ratesR_line_391_Ive_joined.md#human-4).

---

## Overview

The Annual Business Survey (ABS) produces its own GVA values ("approximate GVA" or aGVA) from direct firm surveys. The ONS region-by-industry GVA data is a national accounts product that starts from UK-level Blue Book totals and allocates them to regions top-down. Even where both sources cover the same sector/region/year, the values can diverge substantially. This document summarises why.

## 1. Sectoral coverage differences

The ABS covers the **UK non-financial business economy** - [roughly two-thirds of the economy](https://www.ons.gov.uk/businessindustryandtrade/business/businessservices/methodologies/annualbusinesssurveyqmi). Major exclusions (detailed in the [ABS Technical Report](https://www.ons.gov.uk/businessindustryandtrade/business/businessservices/methodologies/annualbusinesssurveytechnicalreportjanuary2024)):

- **Public administration and defence** (SIC Section O): entirely excluded from ABS. Regional GVA [allocates this using BRES employee counts multiplied by ASHE average public sector earnings](https://www.ons.gov.uk/economy/grossvalueaddedgva/methodologies/regionalgrossvalueaddedproductionapproachqmi).
- **Financial services** (most of SIC Section K): ABS excludes financial service activities (SIC 64), pension funding (65.3) and auxiliary financial activities (66). Only insurance/reinsurance is covered. Regional GVA covers the whole of Section K using [separate data sources](https://www.ons.gov.uk/economy/grossvalueaddedgva/articles/measurementofthefinanceandinsuranceindustriesinestimatesofregionalgrossvalueadded/2018-04-09).
- **Agriculture** (part of Section A): ABS excludes crop and animal farming (SIC 01.1 to 01.5). Only support activities to agriculture, hunting, forestry and fishing are in scope.
- **Education, health, social care** (Sections P and Q): ABS covers **private sector only**. All publicly-provided education, hospital activities, other health, residential care and social work are excluded. This is the main reason health sector ABS values are dramatically lower than regional GVA values - the bulk of the sector is public.
- **Households as employers** (Section T), **extraterritorial organisations** (Section U): excluded.

Regional GVA, by contrast, covers every sector in the economy, using [over 400 input datasets](https://www.ons.gov.uk/economy/grossvalueaddedgva/articles/analysisoftheextentofmodellingandestimationinregionalgrossvalueadded/2018-03-28).

## 2. Top-down vs bottom-up construction

This is fundamental to understanding the divergence:

- **ABS** is bottom-up. Individual businesses report their own turnover, purchases and other items. These are weighted up to represent non-sampled businesses. The result is an aggregate built from individual survey returns.
- **Regional GVA** is top-down. National Blue Book totals (compiled for [112 industry components corresponding to Supply and Use Table industry groups](https://www.ons.gov.uk/economy/regionalaccounts/grossdisposablehouseholdincome/methodologies/regionalaccountsmethodologyguidejune2019)) are the starting point. Regional indicators - drawn from ABS, BRES, ASHE, HMRC and many other sources - are then used to **apportion** those national totals to regions.

Even where ABS is the primary regional indicator for GVA(P), the resulting regional GVA figure will not match the ABS aGVA value, because:
- The national total has been through Supply and Use balancing
- Coverage, conceptual and coherence adjustments have been applied at national level before apportionment
- ABS is used as a **proportional indicator** (i.e. to allocate shares), not as a level

## 3. National accounts adjustments (the "balancing" constraint)

Regional GVA figures are forced to sum to national totals through Supply and Use Table balancing. At national level, this reconciliation process adjusts all three measures of GDP (income, expenditure, production) to agree. [Adjustments include](https://www.ons.gov.uk/economy/regionalaccounts/grossdisposablehouseholdincome/methodologies/regionalaccountsmethodologyguidejune2019):

- **Coverage adjustments**: adding in sectors and activities the ABS doesn't cover
- **Conceptual adjustments**: e.g. illegal production, imputed activities (like imputed rent)
- **Coherence adjustments**: making the three GDP approaches consistent with each other

None of these adjustments exist in the ABS data. ABS aGVA is a [direct survey measure](https://www.ons.gov.uk/businessindustryandtrade/business/businessservices/methodologies/annualbusinesssurveyqmi): total output minus intermediate consumption, with no balancing applied. The [DCMS Economic Estimates technical report](https://www.gov.uk/government/statistics/dcms-economic-estimates-gva-2023-provisional/dcms-economic-estimates-annual-gva-technical-and-quality-assurance-report) explicitly discusses these coverage, conceptual and coherence differences as reasons for preferring national accounts GVA over ABS aGVA.

## 4. How ABS feeds into regional GVA

The ABS's role differs between the two GVA approaches:

- **GVA(P) - Production approach**: ABS contributes [approximately **71%**](https://www.ons.gov.uk/economy/grossvalueaddedgva/articles/analysisoftheextentofmodellingandestimationinregionalgrossvalueadded/2018-03-28) of total GVA(P). It is the [principal regional indicator](https://www.ons.gov.uk/economy/grossvalueaddedgva/methodologies/regionalgrossvalueaddedproductionapproachqmi) for most non-financial business economy sectors.
- **GVA(I) - Income approach**: ABS contributes [approximately **22%**](https://www.ons.gov.uk/economy/grossvalueaddedgva/articles/analysisoftheextentofmodellingandestimationinregionalgrossvalueadded/2018-03-28). The income approach relies more heavily on ASHE (earnings), BRES (employee counts) and HMRC (profits data).
- **GVA(B) - Balanced measure** (the published regional GVA): a [weighted arithmetic mean](https://www.ons.gov.uk/economy/grossvalueaddedgva/methodologies/regionalgrossvalueaddedbalancedqmi) of GVA(I) and GVA(P), with weights determined by quality metrics (coefficients of variation assigned to each region-industry-year combination).

So ABS is heavily used, but is transformed through the allocation and balancing process.

## 5. Multi-region firm apportionment

Both sources have to deal with firms operating across multiple regions, but they handle it differently:

- **ABS regional data**: for multi-site companies, no local unit information is collected directly. Reporting unit data are apportioned among constituent local units using a [**regression model**](https://www.ons.gov.uk/businessindustryandtrade/business/businessservices/methodologies/annualbusinesssurveytechnicalreportjanuary2024) based on IDBR (Inter-Departmental Business Register) local unit employment data, on the assumption that workers across all sites contribute equally to the company's GVA.
- **Regional GVA**: uses the same IDBR employment data but through the broader top-down allocation framework, constrained to national totals.

Importantly, the ONS [notes](https://www.ons.gov.uk/businessindustryandtrade/business/businessservices/methodologies/annualbusinesssurveytechnicalreportjanuary2024) that "Regional ABS data for each sector does not necessarily sum to National ABS totals for each sector" because the regional apportionment methodology (using local unit classification) differs from the national methodology (using reporting unit classification). This can cause sector-level regional totals to diverge from national aggregates even within the ABS itself.

## 6. Vintage and timing differences

- ABS data for year X are typically published [about 16 months after the reference period](https://www.ons.gov.uk/businessindustryandtrade/business/businessservices/methodologies/annualbusinesssurveyqmi) (e.g. 2023 data published around April 2025).
- Regional GVA data are revised [24 months after the reference period](https://www.ons.gov.uk/economy/grossvalueaddedgva/methodologies/regionalgrossvalueaddedbalancedqmi) following Supply and Use balancing.
- The un-suppressed ABS data used as a regional indicator in GVA compilation may be from a different vintage than the publicly available ABS bulletins.

## 7. Extent of modelling and estimation in regional GVA

An [ONS analysis (2018)](https://www.ons.gov.uk/economy/grossvalueaddedgva/articles/analysisoftheextentofmodellingandestimationinregionalgrossvalueadded/2018-03-28) broke down how much of regional GVA is directly observed vs estimated vs modelled:

| Category | GVA(I) | GVA(P) |
|----------|--------|--------|
| Observed data | 31.6% | 22.8% |
| Estimated data | 51.4% | 48.5% |
| Modelled data | 17.0% | 28.7% |

Sectors with particularly high modelling proportions include:
- Electricity/Gas (Section D): 46.7% modelled in GVA(I), 72.5% in GVA(P)
- Finance (Section K): 43.9% in GVA(I), 52.9% in GVA(P)
- Water/Waste (Section E): 35.3% in GVA(I), 59.6% in GVA(P)

These are all sectors where ABS coverage is limited or absent, so regional GVA relies heavily on modelled or estimated data.

## 8. Implications for the observed discrepancies

In rough order of likely magnitude:

1. **Sectoral coverage** is the dominant factor for sectors like health, education and finance where ABS simply does not capture the public or non-business economy component.
2. **National accounts adjustments** mean that even for well-covered sectors, the national total being allocated is different from (and usually larger than) the sum of ABS regional estimates.
3. **Top-down constraint** forces regional GVA values to sum to a national total that has been adjusted. ABS regional data are unconstrained.
4. **Multi-region apportionment** differences affect sectors dominated by large firms operating across many regions.
5. **Vintage/timing** can introduce discrepancies where one source has been revised but the other hasn't.

For sectors where ABS coverage is good (most of manufacturing, construction, wholesale/retail, professional services), the discrepancies are more likely driven by factors 2-5. For sectors with partial or no ABS coverage, factor 1 dominates.

---

## Sources

### ABS methodology
- [Annual Business Survey QMI](https://www.ons.gov.uk/businessindustryandtrade/business/businessservices/methodologies/annualbusinesssurveyqmi)
- [Annual Business Survey Technical Report: January 2024](https://www.ons.gov.uk/businessindustryandtrade/business/businessservices/methodologies/annualbusinesssurveytechnicalreportjanuary2024)

### Regional GVA methodology
- [Regional GVA (Balanced) QMI](https://www.ons.gov.uk/economy/grossvalueaddedgva/methodologies/regionalgrossvalueaddedbalancedqmi)
- [Regional GVA (Production Approach) QMI](https://www.ons.gov.uk/economy/grossvalueaddedgva/methodologies/regionalgrossvalueaddedproductionapproachqmi)
- [Regional GVA (Income Approach) QMI](https://www.ons.gov.uk/economy/grossvalueaddedgva/methodologies/regionalgrossvalueaddedincomeapproachqmi)
- [Regional Accounts Methodology Guide: June 2019](https://www.ons.gov.uk/economy/regionalaccounts/grossdisposablehouseholdincome/methodologies/regionalaccountsmethodologyguidejune2019)

### Analysis of data quality and modelling extent
- [Analysis of the Extent of Modelling and Estimation in Regional GVA (2018)](https://www.ons.gov.uk/economy/grossvalueaddedgva/articles/analysisoftheextentofmodellingandestimationinregionalgrossvalueadded/2018-03-28)
- [Measurement of the Finance and Insurance Industries in Estimates of Regional GVA (2018)](https://www.ons.gov.uk/economy/grossvalueaddedgva/articles/measurementofthefinanceandinsuranceindustriesinestimatesofregionalgrossvalueadded/2018-04-09)

### Other relevant sources
- [DCMS Economic Estimates: Annual GVA - Technical and Quality Assurance Report](https://www.gov.uk/government/statistics/dcms-economic-estimates-gva-2023-provisional/dcms-economic-estimates-annual-gva-technical-and-quality-assurance-report) - explicitly discusses coverage, conceptual and coherence differences between ABS aGVA and national accounts GVA
- [Disaggregating Annual Subnational GVA to Lower Levels of Geography (2021)](https://www.ons.gov.uk/economy/grossvalueaddedgva/articles/disaggregatingannualsubnationalgrossvalueaddedgvatolowerlevelsofgeography/2021-12-13)
- [Regional GVA Inventory for the UK (2009)](https://www.ons.gov.uk/file?uri=%2Feconomy%2Fregionalaccounts%2Fgrossdisposablehouseholdincome%2Fmethodologies%2Fregionalaccounts%2Finventorywebversionfeb1tcm7722032tcm77253853.pdf) - older but comprehensive Eurostat-format inventory of all data sources and methods
