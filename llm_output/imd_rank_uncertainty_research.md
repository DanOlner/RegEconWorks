# Uncertainty in the English Index of Multiple Deprivation: data sources, weights and a route to rank ranges

Claude Code research note, 10 November 2026. This starts the research for a new bundle. The goal is rank-range uncertainty for the Index of Multiple Deprivation (IMD): showing which LSOAs and local authorities can and can't be told apart statistically, once error in the underlying data is carried through to the final ranks.

The note covers three things in order:

1. All the datasets used to build the IMD (section 2).
2. How the indicators are weighted and combined into domains and sub-domains (section 3).
3. How the domains are combined into the final IMD score and rank, and summarised for local authorities (section 4).

It then sets out what the Indices already say about uncertainty (section 5), the error sources by type of data (section 6), related work on rank uncertainty (section 7), a first rough calculation (section 8), options for getting to rank ranges (section 9) and questions for Dan (section 10).

It is based on the [English Indices of Deprivation 2025 (IoD 2025)](https://www.gov.uk/government/statistics/english-indices-of-deprivation-2025), published by MHCLG on 30 October 2025. I read the [technical report](https://assets.publishing.service.gov.uk/media/68ff59c80f801e57b5bef907/ID_2025_Technical_Report.pdf) in full and searched the [research report](https://assets.publishing.service.gov.uk/media/68ff547a49d08dd781b48351/ID_2025_Research_Report.pdf). I downloaded Files 7, 8 and 9 on 10 November 2026 and checked them. Where something is my own calculation or inference, it says so. My calculations are in sections 3.8, 4.4 and 8, and the R scripts are in [code/imd_uncertainty](../code/imd_uncertainty/).

A follow-up report, [docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.html](../docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.html) (source: the `.qmd` beside it), covers three things:

- what open and secure data mean for estimating the IMD's error;
- whether the shrinkage step can be run backwards to recover each LSOA's error;
- a first lower bound on rank ranges, from Income and Employment error alone.

## Short answers

- **55 indicators, 7 domains, 6 sub-domains.** The IoD 2025 uses 55 indicators (39 in 2019), from about 20 data suppliers. Most are administrative records: DWP benefits, the National Pupil Database, hospital and mental health records, deaths, and police recorded crime. Two come from the 2021 Census. Five are modelled estimates. The geography is the 33,755 LSOAs of 2021, summarised to 296 local authority districts (2024 boundaries).
- **About half the IMD rests on DWP benefit records.** By nominal weight (my calculation), the Income and Employment domains (45%) plus the two benefit-based health indicators (about 5.6%) come from DWP data. The next-largest single inputs are the Census adult skills indicator (6.75%) and the DfT connectivity score (4.65%).
- **Three ways of combining indicators within domains.**
  - Income and Employment are simple rates: non-overlapping counts of people, summed and divided by a population.
  - Health, Crime and the children and young people part of Education turn each indicator into a normal score using its rank, then add them with weights from maximum likelihood factor analysis.
  - Barriers and Living Environment use normal scores with equal weights inside each sub-domain.
  - Where a domain has two sub-domains, each sub-domain is ranked and transformed to an exponential distribution, then combined: 50/50 for Education and Barriers, 70/30 indoors/outdoors for Living Environment.
- **Domains to IMD.** Each domain score is ranked across all LSOAs. The rank is transformed to an exponential distribution running from 0 to 100, with the most deprived 10% spread over 50 to 100. The transformed scores are summed with weights of 22.5% (Income, Employment), 13.5% (Education, Health) and 9.3% (Crime, Barriers, Living Environment), and the sum is ranked. These weights haven't changed since 2004. **I rebuilt the published IMD score from the published transformed domain scores and these weights, to within 0.001** (section 4.4).
- **Shrinkage is the only formal handling of uncertainty.** The Indices treat administrative data as samples from a "super-population" and shrink each LSOA's rate towards a parent-group mean (empirical Bayes). In 2025 the parent group is the LSOA's area-classification supergroup within its local authority. But neither report publishes standard errors, confidence intervals or rank ranges. The guidance says ranks show "broadly" whether one area is more deprived than another, and that differences between less deprived areas are "less well defined".
- **Public data limit what can be rebuilt.** Most published indicators are post-shrinkage rates without counts. Only the Income, Employment, IDACI and IDAOPI numerators are published as counts, rounded to the nearest 5 and suppressed below 10. The four pupil-level education indicators (Key Stage 2, Key Stage 4, absence, persistent absence) aren't published at all, at DfE's request.
- **A first look at scale (my calculation, rough).** Treating each LSOA's Income count as a binomial draw, the 95% interval for its Income domain rank has a median width of about 770 ranks within the most deprived 10% of LSOAs, and about 3,500 ranks in the less deprived half. That is one domain, with crude assumptions (section 8), but it suggests rank uncertainty is large and grows towards the less deprived end.

## 1. How the IMD is built: the seven stages

The technical report (section 3.1) sets out seven stages:

1. Domains of deprivation are identified (the same seven since 2004).
2. Indicators are chosen for each domain.
3. Shrinkage estimation is applied to improve the reliability of small-area data.
4. Indicators are combined into domain scores, via sub-domain scores where a domain has them.
5. Domain scores are ranked and the ranks transformed to an exponential distribution.
6. The transformed domain scores are combined with explicit weights to form the IMD score, which is then ranked.
7. The IMD, domains and supplementary indices are summarised for larger areas such as local authorities.

Stages 3 to 7 are where data error turns into rank uncertainty. Stages 4 to 6 are mostly rank-based, so an error in one LSOA's data can move other LSOAs' ranks too.

The two supplementary indices, IDACI (children) and IDAOPI (older people), are subsets of the Income domain. They aren't part of the IMD.

## 2. The datasets: all 55 indicators

The ID numbers are the report's own (Table J.2). Columns:

- "Shrunk" says whether shrinkage was applied. "LAD parent" means the shrinkage target was the local authority, not the area-classification supergroup within the authority (footnote 22).
- "File 8" says whether the indicator is in the published underlying indicators file.

Time points differ between indicators. Each uses the latest data available when the Indices were built.

### 2.1 Income Deprivation Domain (22.5% of the IMD)

| ID | Indicator: adults and children in benefit units receiving… | Supplier |
|---|---|---|
| ID1 | Income Support | DWP |
| ID2 | Income-based Jobseeker's Allowance | DWP |
| ID3 | Income-based Employment and Support Allowance | DWP |
| ID4 | Pension Credit (Guarantee) | DWP |
| ID5 | Universal Credit, "out of work" conditionality groups (no work requirements, planning for work, preparing for work, searching for work) | DWP |
| ID6 | Universal Credit, "in work" groups, with equivalised income after housing costs below 70% of the national median | DWP |
| ID7 | Housing Benefit only, with income after housing costs below 70% of the median | DWP (RAPID, Single Housing Benefit Extract) |
| ID8 | Tax Credits only, with income after housing costs below 70% of the median (housing costs imputed from UC data by LSOA and family type) | DWP (RAPID) |
| ID9 | Asylum seekers in dispersed accommodation receiving support (Sections 95, 98 and 4) | Home Office |

- **Time point.** End of March 2024 for all numerators.
- **Denominator.** Total resident population, mid-2022, from a bespoke ONS small-area series that includes prisoners.
- **Construction.** The nine counts don't overlap and are summed. Where the numerator exceeds the denominator, the denominator is set equal to the numerator. Shrinkage is applied to the domain rate.
- **Threshold.** The 70% of median income after housing costs threshold was computed by DWP from the Family Resources Survey (the HBAI data).
- **File 8.** The domain numerator only, rounded to the nearest 5, with counts below 10 suppressed. Five LSOAs are suppressed.

### 2.2 Employment Deprivation Domain (22.5%)

| ID | Indicator: claimants aged 18 to 66 of… |
|---|---|
| ID10 | Jobseeker's Allowance (contribution- and income-based) |
| ID11 | Employment and Support Allowance (contribution- and income-based) |
| ID12 | Incapacity Benefit |
| ID13 | Severe Disablement Allowance |
| ID14 | Carer's Allowance |
| ID15 | New Style Jobseeker's Allowance |
| ID16 | New Style Employment and Support Allowance |
| ID17 | Income Support |
| ID18 | Universal Credit, no work requirements |
| ID19 | Universal Credit, searching for work |
| ID20 | Universal Credit, planning for work |
| ID21 | Universal Credit, preparing for work |

- **Source.** DWP (RAPID linked to the Customer Information System for location).
- **Time point.** The average of 12 monthly counts across financial year 2022/23. This was chosen to predate the managed migration to Universal Credit, which rolled out unevenly across the country.
- **Denominator.** Population aged 18 to 66, mid-2022, including prisoners.
- **Construction.** Non-overlapping count ÷ denominator, then shrinkage.
- **File 8.** The domain numerator only, rounded and suppressed as for Income.

### 2.3 Education, Skills and Training Deprivation Domain (13.5%)

| ID | Indicator | Source and time point | Shrunk | File 8 |
|---|---|---|---|---|
| | *Children and young people sub-domain* | | | |
| ID22 | Key Stage 2 scaled scores (maths, reading, grammar, punctuation and spelling) | DfE National Pupil Database: 2018/19, 2021/22, 2022/23 | Yes, each year separately (LAD parent) | No |
| ID23 | Key Stage 4 average capped points score (best 8) | DfE NPD: same three years | Yes, each year separately (LAD parent) | No |
| ID24 | Pupil absence: share of half-day sessions missed, primary, secondary and special schools | DfE NPD: same three years | Yes (LAD parent) | No |
| ID25 | Persistent absence: share of pupils missing 10% or more of sessions | DfE NPD: same three years | Yes (LAD parent) | No |
| ID26 | Young people under 21 not entering higher education (denominator: population aged 14 to 17, less prisoners) | JISC; ONS: 2018/19 to 2022/23 | Yes | Yes (suppressed where the at-risk population is under 23) |
| | *Adult skills sub-domain* | | | |
| ID27 | Adults aged 25 to 66 with no or level 1 qualifications, or who cannot speak English well (non-overlapping) | ONS Census 2021, special table | Yes | Yes (rate) |

- The pupil data cover state-funded schools only and are located by pupil residence.
- 2019/20 and 2020/21 were skipped because of pandemic assessment changes. For KS2 and KS4, each year is standardised and shrunk separately, then the years are combined "into a single indicator using factor analysis".
- No LSOA indicator from pupil microdata can be published (File 8 notes). The children and young people sub-domain is published only as a score (Files 4 and 5).

### 2.4 Health Deprivation and Disability Domain (13.5%)

| ID | Indicator | Source and time point | Shrunk | File 8 |
|---|---|---|---|---|
| ID28 | Comparative Illness and Disability Ratio: age-sex standardised ratio of people receiving DLA, ESA, AA, Industrial Injuries Disablement Benefit and related, IB, SDA, PIP or the UC health caseload | DWP: four quarters of 2022/23 | Yes | Yes |
| ID29 | Years of potential life lost: deaths under 75 from any cause, weighted by age at death, age-sex standardised | ONS deaths: 2018 to 2022 | Yes (LAD parent) | Yes |
| ID30 | Acute morbidity: emergency admissions lasting more than one day, age-sex standardised | Hospital Episode Statistics: 2021/22 to 2022/23 | Yes (LAD parent) | Yes |
| | *Mental health composite (published only as the composite)* | | | |
| ID34 | Suicide mortality, simple rate | ONS: 2018 to 2022 | Yes (LAD parent) | No |
| ID33 | Mental health in-patient admissions (care clusters 01 to 08) | Mental Health Services Data Set: 2021/22 and 2022/23 | Yes (LAD parent) | No |
| ID31 | Estimated patients prescribed anxiolytics or antidepressants, from GP practice prescribing volumes, shared out to LSOAs by patient registrations | NHS practice prescribing and GP registration data: 2021/22 and 2022/23 | Not stated (footnote 22 lists it under LAD parent) | No |
| ID32 | DLA and PIP claimants with mental health or behavioural disease codes, as a share of people aged 0 to 66 | DWP: four quarters of 2022/23 | Yes | No |

### 2.5 Crime Domain (9.3%)

| ID | Indicator |
|---|---|
| ID35 | Violence with injury (including homicide), per 1,000 at-risk population |
| ID36 | Violence without injury, per 1,000 at-risk population |
| ID37 | Stalking and harassment, per 1,000 at-risk population |
| ID38 | Burglary, per 1,000 at-risk properties |
| ID39 | Theft and robbery, excluding shoplifting, per 1,000 at-risk population |
| ID40 | Criminal damage and arson, per 1,000 at-risk population |
| ID41 | Public order and possession of weapons, per 1,000 at-risk population |
| ID42 | Anti-social behaviour incidents, per 1,000 at-risk population |

- **Source.** Geocoded records from the Home Office Data Hub, the raw Police.uk repository and bespoke extracts from all 39 forces. They were processed inside Lancashire Constabulary.
- **Time points.** Six years of recorded crime (2018/19 to 2023/24). Two years of anti-social behaviour (2022/23 and 2023/24).
- **Mapping and constraining.**
  - Records within 10 m of an LSOA boundary are split equally between the neighbouring LSOAs.
  - Records located at police premises are spread across the whole force area.
  - Recorded crime counts are then constrained to published force-area totals. Anti-social behaviour is constrained to the geocoded total instead.
- **Denominators.**
  - At-risk population: resident population plus non-resident workplace population. The workplace part comes from the 2011 Census for 2018/19 and 2019/20, the 2021 Census for 2020/21 and 2021/22, and the average of the two for 2022/23 and 2023/24.
  - Burglary: Census 2021 dwellings plus OS AddressBase non-residential properties.
- All eight are shrunk, and all eight are published as rates (no counts).

### 2.6 Barriers to Housing and Services Domain (9.3%)

| ID | Indicator | Source and time point | Shrunk | File 8 |
|---|---|---|---|---|
| | *Geographical barriers sub-domain* | | | |
| ID43 | Connectivity score: walking, cycling and public transport travel time to 33 types of destination, weighted by trip frequency | DfT Connectivity Tool, 2025 | No | Yes |
| | *Wider barriers sub-domain* | | | |
| ID44 | Housing affordability: households with a head under 40 unable to afford to buy or to rent privately (two components) | Modelled by Bramley (Heriot-Watt) from UKHLS, FRS, Census 2021, Land Registry, Zoopla and VOA rents: 2018 to 2022 | Unclear | Yes (both components) |
| ID45 | Household overcrowding by Census occupancy rating (two components: rooms and bedrooms) | Census 2021 | Yes | Yes (both) |
| ID46 | Statutory homelessness acceptances per household, local authority level | MHCLG H-CLIC: 11 quarters, October 2021 to June 2024 | No (LAD level) | Yes |
| ID47 | Core homelessness: rough sleeping, unconventional accommodation, hostels, unsuitable temporary accommodation, sofa surfing (local authority level) | Modelled by Bramley; Appendix A names the Joseph Rowntree Foundation as source: 2020/21 to 2022/23 | No (LAD level) | Yes |
| ID48 | Broadband upload and download line speed | Ofcom, December 2024 | No | Yes |
| ID49 | Patients per full-time-equivalent GP, practice level, shared out to LSOAs by patient registrations | NHS GP workforce statistics, November 2024 | No | Yes |

### 2.7 Living Environment Deprivation Domain (9.3%)

| ID | Indicator | Source and time point | Shrunk | File 8 |
|---|---|---|---|---|
| | *Indoors sub-domain* | | | |
| ID50 | Housing in poor condition: modelled share of homes failing any of three Decent Homes components (Category 1 hazard, disrepair, modernisation) | BRE model from English Housing Survey 2019 and 2020, Experian and OS dwelling data, 2023 | Yes (per chapter 4 and File 8) | Yes |
| ID51 | Housing energy performance: 100 minus the mean EPC score. About 60% of homes have a valid EPC; the rest are imputed from the five nearest similar dwellings | MHCLG EPC open data, 2012 to December 2024; OS National Geographic Database | Yes | Yes |
| ID52 | Housing lacking private outdoor space: a 0 to 100 score for how far a property's back-of-house space falls below the 120 m² national median | OS and ONS property data, mid-2023, with imputation for implausible values | Yes | Yes |
| | *Outdoors sub-domain* | | | |
| ID53 | Air quality: NO₂, PM2.5, SO₂ and benzene, each divided by the WHO 2021 guideline and summed | Defra modelled background concentrations on a 1 km grid, 2023 | No | Yes |
| ID54 | Pedestrian and cyclist road casualties, weighted 1, 2 and 3 for slight, serious and fatal; records within 100 m of a boundary are split | DfT road safety data (severity-adjusted), 2019 to 2023 | Yes | Yes |
| ID55 | Noise: share of residents exposed to 55 dB Lden or more from road, rail and aircraft | Defra Noise Modelling System, Round 4 (2021) | Yes | Yes |

### 2.8 Denominators

Denominators are a shared input to most indicators, so they deserve their own line in any error budget (Appendix B).

- ONS supplied bespoke mid-2022 LSOA population estimates, by single year of age and sex, with and without prisoners. These were the latest available when the Indices were finalised in summer 2025.
- The same mid-2022 populations weight the LSOAs in the local authority summaries.
- Other denominators come from the same source as the numerator (NPD, Census) or are built specially (the crime at-risk population and property counts).

## 3. Within-domain combination and weights

The report describes three methods (section 3.5):

1. **Simple rates** (Income, Employment, and the adult skills sub-domain). Non-overlapping counts are summed and divided by the at-risk population. The weight of each benefit is implicit: it is that benefit's share of the count. These are the only domain scores with a direct meaning, the share of people who are deprived.
2. **Normal scores combined with factor-analysis weights** (Health, Crime, and the children and young people sub-domain). Each indicator, after shrinkage, is ranked and converted to a standard normal score. A one-factor maximum likelihood factor analysis gives the weights, which are then applied to the normal scores (Appendix D). The report says no meaningful second factor appeared in any domain.
3. **Normal scores combined with equal weights** (the wider barriers, indoors and outdoors sub-domains).

Where a domain has two sub-domains, each sub-domain score is ranked and transformed to the same exponential distribution used in stage 5 (section 4.1). The two are then combined with set weights.

### 3.1 Income and Employment

Single rates. Shrinkage is applied to the domain rate itself, so there is no further weighting.

### 3.2 Education, Skills and Training

**Children and young people sub-domain**, factor-analysis weights (Table 4.1):

| Indicator | Weight |
|---|---|
| Key Stage 2 attainment | 0.169 |
| Key Stage 4 attainment | 0.192 |
| Pupil absence | 0.247 |
| Persistent pupil absence | 0.246 |
| Entry to higher education | 0.146 |

**Adult skills sub-domain**: one non-overlapping rate, so no weighting.

The two sub-domains are exponentially transformed and combined with **equal weights**.

### 3.3 Health Deprivation and Disability

The mental health indicator is itself a factor-weighted composite of normal scores (Table 4.4):

| Component | Weight |
|---|---|
| Suicide mortality | 0.105 |
| Hospital admissions | 0.186 |
| Prescribing | 0.211 |
| Health benefits | 0.498 |

The domain is then a factor-weighted sum of four normal scores (Table 4.5):

| Indicator | Weight |
|---|---|
| Comparative Illness and Disability Ratio | 0.294 |
| Years of potential life lost | 0.240 |
| Acute morbidity | 0.222 |
| Mental health composite | 0.244 |

There are no sub-domains, so the Health domain score is roughly normally distributed until stage 5.

### 3.4 Crime

A factor-weighted sum of eight normal scores (Table 4.6):

| Indicator | Weight |
|---|---|
| Violence with injury | 0.151 |
| Violence without injury | 0.154 |
| Stalking and harassment | 0.132 |
| Burglary | 0.074 |
| Theft | 0.097 |
| Criminal damage | 0.144 |
| Public order and possession of weapons | 0.145 |
| Anti-social behaviour | 0.103 |

### 3.5 Barriers to Housing and Services

- **Geographical barriers sub-domain**: the connectivity score alone.
- **Wider barriers sub-domain**: five items, each a normal score, with equal weights. Three of the five are themselves combinations:
  - housing affordability: owner-occupation and private-rental components, each a normal score, combined with equal weights;
  - overcrowding: rooms and bedrooms components, combined with equal weights;
  - homelessness: the standardised core and statutory homelessness scores added together;
  - broadband speed;
  - patient-to-GP ratio.
- The two sub-domains are exponentially transformed and combined with **equal weights**. The report notes they correlate weakly and tend to "counterbalance" each other (footnote 30).

### 3.6 Living Environment

- **Indoors sub-domain**: housing in poor condition, energy performance and lack of private outdoor space, as normal scores with equal weights.
- **Outdoors sub-domain**: air quality, road casualties and noise, as normal scores with equal weights.
- The two sub-domains are exponentially transformed and combined **70% indoors, 30% outdoors**. The weights come from ONS time-use data (2014/15) and were 67/33 in 2019.

### 3.7 Gaps in the description of within-domain construction

These matter for an exact rebuild and for knowing the effective weights. They're listed as questions in section 10.

- **Are composite items re-standardised?** The homelessness item is "standardised core plus standardised statutory". Housing affordability and overcrowding are equal-weighted pairs. If they aren't re-standardised before entering the wider barriers sub-domain, their spread differs from the single-indicator items, so "equal weights" wouldn't give them equal influence.
- **Shrinkage of modelled indicators.** Appendix C (C.1.3) says modelled indicators, "road distance indicators" and LAD-level indicators are not shrunk. But chapter 4 and File 8 say housing in poor condition and noise are shrunk. Road distance indicators no longer exist in 2025, so the Appendix C sentence may be a leftover from 2019. For housing affordability, chapter 4 doesn't say either way.
- **Order of steps for overcrowding.** Paragraph 4.8.13 describes ranking to normal scores *then* shrinkage. Shrinkage is defined on proportions, and File 8 publishes overcrowding as proportions. Probably shrinkage came first.
- **Footnote 22** lists "self harm" among the indicators shrunk to the LAD. There's no self-harm indicator in 2025.
- **Standard errors for non-proportions.** Appendix C gives the shrinkage formula for counts out of a population (`r` of `n`). It doesn't say how the standard error is formed for the KS2 and KS4 point scores, the age-sex standardised ratios (CIDR, years of life lost, acute morbidity), the crime rates with workplace-adjusted denominators, or the property-level EPC and outdoor-space scores.

### 3.8 Nominal share of the IMD by indicator (my calculation)

This multiplies the domain weight by the sub-domain weight and by the indicator weight. It is a nominal share only. Ranking and the exponential transforms mean an indicator's real influence on an LSOA's rank depends on where the LSOA sits in each distribution. It also assumes composite items carry equal weight within their sub-domain (see 3.7).

| Input | Nominal share of IMD |
|---|---|
| Income domain (9 benefit counts, implicit weights) | 22.5% |
| Employment domain (12 benefit counts, implicit weights) | 22.5% |
| Adult skills (Census 2021) | 6.75% |
| Connectivity score | 4.65% |
| CIDR | 3.97% |
| Mental health composite (of which health benefits 1.64%, prescribing 0.70%, admissions 0.61%, suicide 0.35%) | 3.29% |
| Years of potential life lost | 3.24% |
| Acute morbidity | 3.00% |
| Each indoors living environment indicator (3) | 2.17% each |
| Pupil absence, persistent absence | 1.67%, 1.66% |
| Each crime indicator (8) | 0.69% (burglary) to 1.43% (violence without injury) |
| KS4, KS2, entry to HE | 1.30%, 1.14%, 0.99% |
| Each wider barriers item (5) and each outdoors indicator (3) | 0.93% each |

DWP benefit records supply Income, Employment, CIDR and the mental health benefits component: about 50.6% of the nominal weight. The Home Office asylum count is a small part of the Income numerator.

## 4. From domains to the IMD

### 4.1 Rank and exponential transformation (stage 5)

Each domain score is ranked across all N = 33,755 LSOAs. The rank is scaled to R, where R = 1/N for the least deprived and R = 1 for the most deprived. It is then transformed (Appendix E):

```
X = -23 * ln( 1 - R * (1 - exp(-100/23)) )
```

X runs from 0 (least deprived) to 100 (most deprived). The constant 23 means:

- the most deprived 10% of LSOAs have X between 50 and 100;
- cancellation is limited to about 10%. An LSOA most deprived on one domain and least deprived on another, equally weighted, still ends up around the 90th percentile of deprivation. With plain ranks or normal scores it would end up around the 50th.

The same transform is applied to sub-domain ranks before they are combined (section 3).

The report says this transform makes the Indices "discriminate well between deprived neighbourhoods but not so well between those areas in the less deprived part of the distribution" (3.6.4).

### 4.2 Domain weights (stage 6)

| Domain | Weight |
|---|---|
| Income | 22.5% |
| Employment | 22.5% |
| Health Deprivation and Disability | 13.5% |
| Education, Skills and Training | 13.5% |
| Barriers to Housing and Services | 9.3% |
| Crime | 9.3% |
| Living Environment | 9.3% |

```
IMD score = 0.225*X_income + 0.225*X_employment + 0.135*X_health + 0.135*X_education
          + 0.093*X_barriers + 0.093*X_crime + 0.093*X_living
```

The IMD score is then ranked (1 = most deprived) and cut into deciles.

Where the weights come from (section 3.7 and Appendix F):

- They were set for the IoD 2000 from the poverty literature (Townsend) and from judgements about indicator robustness. Income and Employment get the most weight.
- They have been unchanged since the Crime domain was added in 2004.
- Dibben and others (2007) tested three empirical ways of setting the weights: a survey of social exclusion, revealed preference from public spending, and a discrete choice experiment. The only change they suggested was swapping the Employment and Health weights. The report says this "would make little difference" (I haven't read the original study).
- Consultations before the 2007, 2010, 2015 and 2025 editions favoured keeping the weights. The 2025 methods review (Dibben and Lloyd) concluded that re-weighting "would not provide a notable improvement". The report gives no figures for that review.

### 4.3 Local authority summaries (stage 7)

Six summary measures are published for each local authority (Table 3.2), all population-weighted with mid-2022 populations:

- **Average rank**: the population-weighted mean of the LSOA ranks.
- **Average score**: the population-weighted mean of the LSOA scores. It gives more weight to very deprived LSOAs than the average rank does.
- **Proportion of LSOAs in the most deprived 10% nationally.**
- **Extent**: the share of the population in the most deprived 30% of LSOAs, with a weight of 1 for the most deprived 10% falling to 0.05 at the 30th percentile.
- **Local concentration**: the population-weighted mean rank of the authority's most deprived LSOAs that together hold 10% of its population.
- **Income scale and employment scale**: counts of income- and employment-deprived people.

Each measure is ranked across authorities. MHCLG stresses that "no single summary measure is the 'best' measure".

The LSOA-to-LAD lookup was corrected on 17 November 2025. One LSOA, E01027305, had been put in Cherwell; it belongs in West Northamptonshire. Files 10, 11 and 14 were reissued as "v2".

### 4.4 Rebuilding the IMD from the published files (my check)

Using File 7 (all ranks and scores) and File 9 (transformed domain scores):

- **The transform.** Applying the formula in 4.1 to each published domain rank reproduces the File 9 transformed score to within 0.003 for all seven domains.
- **The weights.** Multiplying File 9 by the weights in 4.2 reproduces the published IMD score to within 0.0008 (correlation 1.0000000). The weights are used exactly as printed: 9.3% three times, so they add to 99.9%, not 100%. Ranking needs no rescaling, so this doesn't matter.
- **Ranks.** Ranking the rebuilt score matches the published rank to within 3 places for every LSOA. The differences are ties: the published score has 3 decimal places and 9,849 tied values.

So stages 5 and 6 can be rerun exactly from public data, which is what a simulation needs.

How crowded the IMD score scale is depends on position (my calculation from File 7). The number of LSOAs within ±1 IMD score point of a given rank is:

| IMD rank | IMD score | LSOAs within ±1 point |
|---|---|---|
| 1 | 94.2 | 1 |
| 100 | 76.7 | 32 |
| 1,000 | 59.9 | 190 |
| 3,375 (10% line) | 44.9 | 419 |
| 10,000 | 26.8 | 1,185 |
| 16,878 (median) | 17.5 | 1,801 |
| 30,000 | 5.8 | 2,266 |

The same score error therefore moves an LSOA many more ranks in the middle and less deprived parts of the distribution than in the most deprived tail.

### 4.5 What the construction means for uncertainty

- **Ranks depend on everyone.** Stages 4 to 6 rank every LSOA, so an LSOA's transformed score depends on the scores of all the others. A simulation has to rerun the whole chain for every LSOA in each draw, not perturb one LSOA at a time.
- **Two rounds of exponential stretching.** Sub-domains and domains are both exponentially transformed. The deprived tail is stretched, which separates the most deprived LSOAs. The middle and less deprived parts are squeezed, which crowds them together (4.4).
- **Threshold measures are fragile near the line.** Deciles, the "most deprived 10%" proportion and the extent measure all depend on which side of a line an LSOA falls. LSOAs near rank 3,375 are where small errors flip a classification.
- **Some errors are shared.** The two homelessness indicators are constant within a local authority. Shrinkage pulls LSOAs in the same authority and supergroup towards a common mean. Modelled indicators share inputs over wide areas: housing market areas for affordability, 1 km grid squares for air quality. Police recording practice differs by force. Shared errors don't average out when LSOAs are summarised to local authorities.

## 5. What the Indices already say and do about uncertainty

- **Shrinkage, framed as sampling error.** Appendix C says administrative data and the Census are "regarded as samples from 'super-populations', which one could consider to be samples in time". So year-to-year chance variation counts as error even though the data are near-complete counts. This is useful: the Indices' own design accepts a sampling-style error model.
- **The shrinkage formula** (Appendix C). For an LSOA with `r` events out of `n`:

  ```
  m_j  = log( (r + 0.5) / (n - r + 0.5) )                 empirical logit
  s_j² = (n + 1)(n + 2) / ( n (r + 1)(n - r + 1) )        its variance
  M    = the same logit for the parent group (supergroup within LAD)
  t²   = sum over the k LSOAs in the group of (m_j - M)² / (k - 1)
  w_j  = (1/s_j²) / (1/s_j² + 1/t²)
  m*_j = w_j m_j + (1 - w_j) M,  then back-transformed to a rate
  ```

- **The shrinkage model already implies a standard error.** In the usual empirical Bayes reading, the posterior variance of the shrunk logit is about `w_j × s_j²` (my inference: standard empirical Bayes, not stated in the report). It ignores uncertainty in `M` and `t²`. This gives a ready-made, method-consistent error for every shrunk indicator, if `r` and `n` can be recovered.
- **Before-and-after checks.** All indicators were compared before and after shrinkage to see how far unreliable scores moved (5.2.1). The results aren't published.
- **"Diversity of inputs" as robustness.** The report argues that with 55 indicators from many sources, "there is little chance that an area is identified as highly deprived due to a bias in one of the component indicators" (5.2.1). This is a claim that errors largely cancel. It is untested in the published material, and testing it is part of what this bundle would do.
- **Guidance on reading ranks.** Ranks show "broadly" whether one LSOA is more deprived than another (research report 3.2.3). The Indices discriminate less well at the less deprived end (3.2.10). Changes between editions mix real change with changes to method, data and geography (3.2.6 and 3.4).
- **No error measures published.** Neither report gives standard errors, confidence intervals or rank ranges for any indicator, domain, IMD rank or local authority summary. I searched both reports; I didn't read the FAQ.
- **Weight sensitivity.** The 2007 and 2025 weight reviews said re-weighting made little difference, but the report gives no figures for either (4.2).

## 6. Error sources by type of data

This is a first pass at what kinds of error each source carries. "Random" means chance variation of the kind shrinkage targets. "Systematic" means error that can differ between areas and wouldn't average out.

| Data | Indicators | Random error | Systematic error | Anything published to size it? |
|---|---|---|---|---|
| DWP benefit records | ID1–8, ID10–21, ID28, ID32 | Year-to-year variation in claims; small counts in some LSOAs (median Income numerator about 310) | Take-up of benefits varies between areas; address lags in the Customer Information System; the shift to Universal Credit; Tax Credit housing costs imputed | Fraud and error statistics (national); take-up estimates (national); no LSOA error |
| Home Office asylum support | ID9 | Small, very clustered counts | Placement policy; temporary accommodation excluded | None |
| ONS small-area population estimates | All rate denominators; local authority weights | — | Built top-down from local authority figures; ONS checks them for bias against the Census; the March 2024 numerators are set against a mid-2022 population (some Income numerators exceed the population) | Uncertainty intervals at local authority level only; no LSOA intervals |
| Census 2021 | ID27, ID45; household and workplace denominators | Cell key perturbation (small counts nudged) and record swapping for disclosure control | Pandemic timing (workplace population); imputation; question changes since 2011 | Local authority confidence intervals; disclosure-control method notes |
| DfE National Pupil Database | ID22–25 | Small numbers of pupils per LSOA per year (hence three years pooled) | State schools only; post-pandemic absence changes | Not published at LSOA level |
| JISC higher education entry | ID26 | Small cohorts | Depends on applicants' home postcodes | Suppressed below 23 at-risk |
| ONS deaths | ID29, ID34 | Rare events (hence five years) | Coroner coding of suicide | None at LSOA level |
| HES and MHSDS hospital data | ID30, ID33 | Moderate counts | Trusts that don't submit, or submit inconsistently, to MHSDS; local admission practice | Data quality statements |
| GP prescribing and GP workforce | ID31, ID49 | — | Practice figures shared out to LSOAs by patient registrations (apportionment error); dose assumptions | None |
| Police recorded crime and anti-social behaviour | ID35–42 | Counts over 6 years (2 for anti-social behaviour) | Under-reporting; recording practice differences across 39 forces; geocoding; the 10 m boundary split; workplace denominator assumptions | Force-area checks; OSR report on recorded crime quality |
| Modelled indicators | ID44, ID47, ID50, ID53, ID55 | Model error (none published) | Coarse inputs shared over wide areas: housing market areas, 1 km air quality grid, a national survey sample (EHS 2019 and 2020) scaled down to dwellings | Model documentation only |
| EPC and OS property data | ID51, ID52 | Imputation for about 40% of homes (EPC) | Which homes have EPCs (sales and lets, not a random sample); caravan adjustments | None |
| DfT, Ofcom | ID43, ID48, ID54 | Road casualties are rare (five years used) | Model assumptions (connectivity); ISP-reported line speeds | Severity adjustment notes |
| MHCLG homelessness | ID46 | — | Local authority level only, constant across its LSOAs; imputed returns excluded | Statistics notes |

Things that cut across the table:

- **Mismatched time points.** Numerators run from 2018 to 2024; denominators are mid-2022.
- **Published counts are rounded.** Rounding to the nearest 5 adds about ±2.5 to each published count.
- **Errors move together.** Shrinkage parent groups and local-authority-level indicators make errors move together within an authority.

## 7. Related work on rank uncertainty

### 7.1 League tables and rank intervals

- Goldstein and Spiegelhalter (1996), *League tables and their limitations*, set out the case for putting intervals on ranks rather than presenting point rankings.
- Marshall and Spiegelhalter (1998) applied it to IVF clinics. Rank intervals were very wide, and many year-to-year rank changes came with no significant change in the underlying rate.
- Leckie and Goldstein (2011) made the same argument for school league tables.

### 7.2 Inference for ranks

- Mogstad, Romano, Shaikh and Wilhelm (2024, *Review of Economic Studies*) give marginal confidence sets (for one unit's rank) and simultaneous confidence sets (for all units' ranks at once). They are designed to stay computable for large numbers of units. One of their applications is ranking US neighbourhoods by intergenerational mobility.
- The R package `csranks` implements them. Its `csranks(x, Sigma, ...)` takes the estimates and their **covariance matrix**.
  - At 296 local authorities that's easy.
  - At 33,755 LSOAs a dense matrix would be about 9 GB, so formal simultaneous sets for all LSOAs need a different route (section 9).

### 7.3 Composite indicators

- Saisana, Saltelli and Tarantola (2005, *JRSS A*) set out uncertainty and sensitivity analysis for composite indices. They perturb weights, normalisation and data together by Monte Carlo and report each unit's rank distribution.
- The OECD and JRC *Handbook on Constructing Composite Indicators* (2008) builds on this.
- Saisana and Saltelli's later work reports a median simulated rank and an interval. In the 2010 Environmental Performance Index, Iceland ranked 1st, but its simulated median rank was 7, with an interval of 2 to 8.
- These studies mostly perturb *method* choices. This bundle's focus is *data* error, though the two can be layered (question 2).

### 7.4 Deprivation indices with uncertainty

- **Brazil.** The Brazilian small-area index (Índice Brasileiro de Privação, 2025) put 95% intervals on every area's score, using "random weights" and "random numerators". It flagged areas whose interval spans two or more deciles away from the point estimate's decile: 4.5% of areas and 2.5% of the population.
- **Scotland.** The method comes from Brown, Allik, Dundas and Leyland (2014), *Carstairs scores for Scottish postcode sectors, datazones and output areas from the 2011 Census* (University of Glasgow).
- **A guide.** Allik and others (2020, *Journal of Epidemiology and Community Health*) review options for building small-area indices, including how putting areas into deciles or quintiles reduces the effect of uncertainty.
- I read these at abstract and summary level only.

### 7.5 Critiques of the IMD

- Deas, Robson, Wong and Bradford (2003, *Environment and Planning C*) questioned, among other things, the basis of the expert-set domain weights (from the abstract and a secondary citation).

### 7.6 Gap

My searches didn't find a published study putting rank intervals on the English IMD from data error. That doesn't prove there isn't one, and it's worth asking the IoD research team (question 11).

### 7.7 Links within this repo

- The regional GVA chunk ([docs/chunks/uncertainty_in_regionalGVA](../docs/chunks/uncertainty_in_regionalGVA/)) asks the same question for GVA: separating signal from noise.
- In [adding_uncertainty_planner.md](adding_uncertainty_planner.md), the section "Comparing slopes properly: z-test on the difference, not CI overlap" applies directly. Whether two areas can be told apart should come from the distribution of their *difference*, for example the share of simulation draws in which A ranks above B, not from whether their rank intervals overlap.

## 8. A first look at scale: the Income domain alone (my calculation)

This is a rough illustration, not a result.

**Method.**

- For each LSOA, I took the published (shrunk) Income rate as the centre.
- I used the published numerator and mid-2022 population as `r` and `n` in the Appendix C variance formula.
- I formed a 95% interval on the logit scale and turned its ends back into rates.
- I then read off the Income ranks those rates would take, holding every other LSOA's published rate fixed.

**What it leaves out.**

- Shrinkage would *narrow* the intervals (posterior variance `w_j × s_j²`, section 5). For Income, `w_j` is close to 1 (next point).
- Denominator error and rounding to 5 would *widen* them.
- Every other LSOA's own error is ignored.
- The other six domains are ignored.
- It also takes the super-population framing at face value.

**Shrinkage is small for Income.** The published shrunk rate differs from the raw numerator ÷ population by a median of +0.03 percentage points. The 1st and 99th percentiles are −0.34 and +0.41 points, and the largest difference is 0.86 points. The correlation is 0.99996. Counts are big enough that shrinkage barely moves Income.

**Rank interval widths:**

| Income domain rank band | Median width of the 95% rank interval | Interquartile range |
|---|---|---|
| 1 to 100 | 48 ranks | 20 to 65 |
| 1 to 3,375 (most deprived 10%) | 772 ranks | 522 to 1,054 |
| 3,376 to 10,000 | 1,806 ranks | 1,531 to 2,088 |
| 10,001 to 20,000 | 2,811 ranks | 2,501 to 3,188 |
| 20,001 to 33,755 | 3,534 ranks | 2,864 to 3,913 |

Even on the best-measured domain, a typical LSOA in the most deprived decile has a 95% rank interval spanning about 2% of all LSOAs. In the less deprived half it spans about 10%. If this holds up once the full chain is run, it fits the guidance that the less deprived end is "less well defined". It would also mean that rankings within that half say little about which LSOA is more deprived than which.

## 9. Towards rank ranges: options

This is a sketch for discussion, not yet a plan.

### Option A: Monte Carlo through the whole chain (recommended main route)

For each of, say, 1,000 draws:

1. Perturb every indicator using an error model chosen for its type (section 6).
   - For shrunk count-based indicators, draw from the shrinkage posterior.
   - For LAD-level indicators, use one shared draw per local authority.
   - For modelled indicators with no published error, use assumed coefficients of variation, tested over a range.
2. Rerun stages 4 to 7 exactly as published: normal scores, factor weights held fixed, the exponential transforms, the domain weights and the six local authority summaries.
3. Record every LSOA's rank and decile, and every local authority's summary values and ranks.

Outputs from the draws:

- rank intervals for each LSOA and local authority;
- the probability that each LSOA is in each decile, or in the most deprived 10% or 20%;
- for any two areas, the share of draws in which one ranks above the other;
- for local authorities, `csranks` simultaneous confidence sets, using the 296 × 296 covariance from the draws (if that's statistically defensible; to check).

### Option B: domain by domain, starting with Income and Employment

These are the two domains rebuildable from published counts, and together they carry 45% of the weight. This could be the first chunk: "how separable are LSOAs on income and employment deprivation alone?"

### Option C: method uncertainty as a separate layer

Re-estimate the factor weights in each draw. Vary the domain weights (for example the Dibben swap), the constant 23, the 70/30 split and the shrinkage parent group. Keep this layer separate from data error so the two can be compared, Saisana-style.

### Data access, whichever option

**Public data** can rebuild:

- Income, Employment, IDACI and IDAOPI counts;
- rates for most other indicators (counts would have to be recovered as rate × an approximate denominator);
- the area-classification supergroups, from the [GeoDS LSOA classification](https://data.geods.ac.uk/dataset/lsoac);
- Census tables.

**Not public:**

- the pupil-level education indicators;
- the mental health components;
- counts and exact denominators for crime;
- any model error for the modelled indicators.

These would need either a request to MHCLG and the research team (Deprivation.org and OCSI) for counts or standard errors, or secure access (DfE data via the ONS Secure Research Service).

## 10. Questions and decisions

Each has a suggested default so work can start without waiting.

1. **Which edition?** IoD 2025 is current and uses 2021 LSOAs. IoD 2019 uses 2011 LSOAs and has more published analysis behind it. *Suggested: IoD 2025 only, with 2019 at most as a side check on rank changes.*
2. **What counts as uncertainty?** Three layers:
   - (a) chance variation, in the Indices' own super-population sense;
   - (b) measurement and systematic error that can be roughly sized: denominators, rounding, Census perturbation, apportionment;
   - (c) method choices: weights, transforms, shrinkage target.

   *Suggested: (a) and (b) as the main result; (c) as a separate, clearly labelled layer.*
3. **What's the headline output?** Rank intervals, decile-membership probabilities, pairwise "A more deprived than B" probabilities, or simultaneous confidence sets. *Suggested: for LSOAs, decile-membership probability plus a 90% rank interval; for local authorities, rank intervals on each summary measure plus `csranks` simultaneous sets.*
4. **Which local authority summary measures?** All six, or the ones most used in practice (average score, proportion in the most deprived 10%, extent)? *Suggested: all six in the data; two or three in the write-up.*
5. **Public data only, or ask the research team?** The children and young people sub-domain can't be rebuilt from public data. *Suggested: start public-only, treating that sub-domain's error as an assumption with a range; at the same time, ask MHCLG and the IoD team whether LSOA counts or standard errors can be shared.*
6. **Shrinkage in the simulation.** Draw from the empirical Bayes posterior, which follows the Indices' method and is narrower, or from the raw binomial, which ignores shrinkage and is wider? *Suggested: the posterior as the main run, the raw binomial as a bound.*
7. **Factor-analysis weights.** Hold them at the published values in each draw, or re-estimate them? *Suggested: hold them fixed for data error; re-estimate only in the method layer.*
8. **Indicators with no published error** (the modelled ones, connectivity, broadband, the GP ratio, homelessness). *Suggested: assumed coefficients of variation tested over a range, with shared draws where the input is shared (local authority, housing market area, 1 km grid); report how much each assumption moves the results.*
9. **Confidence level and multiple comparisons.** 90% or 95%? Should pairwise statements be corrected for the number of comparisons? *Suggested: 90% marginal intervals for display, simultaneous sets where the claim is about the whole ranking.*
10. **Policy hook.** Is there a particular use of IMD cut-offs to test, for example "most deprived 10%" or "20%" thresholds used to target funding? That would decide which thresholds the outputs focus on. I haven't checked which current schemes use which cut-offs.
11. **Contacting the IoD team.** The section 3.7 gaps (re-standardised composites, which modelled indicators are shrunk, step order for overcrowding, how standard errors are formed for non-proportions) could be put to the team along with question 5. Do you want to do that, and should it come from you directly?
12. **Where the bundle lives.** The scripts are now in `code/imd_uncertainty/`. The write-up could go in, for example, `docs/chunks/imd_uncertainty/`, following the existing layout. Should this note move into the chunk folder?

## Things I couldn't check

- Figure 3.3 of the technical report is an image (a summary diagram of the whole construction), so I relied on the text.
- I didn't read Dibben and others (2007), Noble and others (2004, Annex F on factor analysis), the 2025 methods review, or the IoD 2025 FAQ.
- I read the uncertainty papers in section 7 at abstract or summary level, apart from the `csranks` reference manual.
- Whether housing affordability is shrunk, and whether composite items are re-standardised (section 3.7).
- What standard errors the Indices used for non-proportion indicators.
- Searches may have missed existing work on IMD rank uncertainty.

## How the checks were done

The scripts are in [code/imd_uncertainty](../code/imd_uncertainty/) and run from the project root, like the rest of `code/`. They download File 7 (CSV), File 8 and File 9 (Excel) from the IoD 2025 page into `local/imd_raw/`, which is gitignored, and reuse them after that.

- **[functions.R](../code/imd_uncertainty/functions.R)**: downloads and loaders for the three files, the domain weights, the Appendix E exponential transform and the Appendix C logit variance.
- **[01_rebuild_imd.R](../code/imd_uncertainty/01_rebuild_imd.R)** (section 4.4): applies the exponential transform to the File 7 domain ranks and compares the result with File 9. Rebuilds the IMD score as the weighted sum of the File 9 scores and compares it with the File 7 IMD score and rank. Counts the LSOAs within ±1 point on the sorted File 7 IMD scores.
- **[02_income_rank_intervals.R](../code/imd_uncertainty/02_income_rank_intervals.R)** (section 8): uses the File 8 Income numerators and the File 7 mid-2022 populations with the Appendix C logit variance. Maps the 95% bounds to ranks against all 33,755 published Income rates.
- **[03_nominal_weights.R](../code/imd_uncertainty/03_nominal_weights.R)** (section 3.8): multiplies the domain, sub-domain and indicator weights from the technical report, sums the share resting on DWP data, and groups the indicators by what File 8 publishes.

Scripts 04 to 07 feed the follow-up report:

- **[04_shrinkage_rebuild.R](../code/imd_uncertainty/04_shrinkage_rebuild.R)**: rebuilds the shrinkage step for Income and Employment.
- **[05_shrinkage_inversion_test.R](../code/imd_uncertainty/05_shrinkage_inversion_test.R)**: a synthetic test of running shrinkage backwards.
- **[06_rare_event_reliability.R](../code/imd_uncertainty/06_rare_event_reliability.R)**: applies the inversion to the crime and road casualty rates.
- **[07_income_employment_mc.R](../code/imd_uncertainty/07_income_employment_mc.R)**: a Monte Carlo carrying Income and Employment error to IMD and local authority ranks.

They also use Files 6 and 10.

## Sources

### English Indices of Deprivation 2025

- [English indices of deprivation 2025: statistics page and data files (MHCLG, 30 October 2025, updated 17 November 2025)](https://www.gov.uk/government/statistics/english-indices-of-deprivation-2025)
- [IoD 2025 Technical Report (McLennan, Noble and others, October 2025)](https://assets.publishing.service.gov.uk/media/68ff59c80f801e57b5bef907/ID_2025_Technical_Report.pdf)
- [IoD 2025 Research Report](https://assets.publishing.service.gov.uk/media/68ff547a49d08dd781b48351/ID_2025_Research_Report.pdf)
- [File 7: all ranks, scores, deciles and population denominators (CSV)](https://assets.publishing.service.gov.uk/media/691ded56d140bbbaa59a2a7d/File_7_IoD2025_All_Ranks_Scores_Deciles_Population_Denominators.csv)
- [File 8: underlying indicators](https://assets.publishing.service.gov.uk/media/691dec012c6b98ecdbc500d4/File_8_IoD2025_Underlying_Indicators.xlsx)
- [File 9: transformed domain scores](https://assets.publishing.service.gov.uk/media/691ded670dcbf6343e9a2a6c/File_9_IoD2025_Transformed_Domain_Scores.xlsx)
- [UK LSOA classification (2021/2 LSOAC), Geographic Data Service](https://data.geods.ac.uk/dataset/lsoac)
- Dibben, C., Atherton, I., Cox, M., Watson, V., Ryan, M. and Sutton, M. (2007) *Investigating the Impact of Changing the Weights that Underpin the Index of Multiple Deprivation 2004*. Communities and Local Government (cited in the technical report; not read).

### Population and Census quality

- [ONS: measures of statistical uncertainty in local authority mid-year population estimates](https://www.ons.gov.uk/peoplepopulationandcommunity/populationandmigration/populationestimates/articles/measuresofstatisticaluncertaintyinonslocalauthoritymidyearpopulationestimates/2011to2019)
- [ONS: small area population estimates in the transformed population estimation system](https://www.ons.gov.uk/peoplepopulationandcommunity/populationandmigration/populationestimates/methodologies/smallareapopulationestimatesinthetransformedpopulationestimationsystemmethodsdevelopment)
- [UK Data Service: statistical disclosure control methods for Census 2021 (PDF)](https://ukdataservice.ac.uk/app/uploads/sdcmethods2023-05-10.pdf)

### Rank uncertainty and composite indicators

- [Goldstein and Spiegelhalter (1996), League tables and their limitations, *JRSS A* 159(3)](https://ideas.repec.org/a/bla/jorssa/v159y1996i3p385-409.html)
- [Marshall and Spiegelhalter (1998), Reliability of league tables of in vitro fertilisation clinics, *BMJ*](https://pmc.ncbi.nlm.nih.gov/articles/PMC28567)
- [Leckie and Goldstein (2011), on school league tables and their uncertainty](https://core.ac.uk/download/32602527.pdf)
- [Mogstad, Romano, Shaikh and Wilhelm (2024), Inference for ranks, *Review of Economic Studies* 91(1)](https://econpapers.repec.org/RePEc:oup:restud:v:91:y:2024:i:1:p:476-518.); [NBER working paper version](https://nber.org/system/files/working_papers/w26883/w26883.pdf)
- [`csranks` R package reference manual](https://cran.r-project.org/web/packages/csranks/refman/csranks.html)
- [Saisana, Saltelli and Tarantola (2005), Uncertainty and sensitivity analysis techniques as tools for the quality assessment of composite indicators, *JRSS A* 168(2)](https://econpapers.repec.org/RePEc:bla:jorssa:v:168:y:2005:i:2:p:307-323)
- [OECD and JRC (2008), Handbook on Constructing Composite Indicators](https://doi.org/10.1787/9789264043466-en)

### Deprivation indices

- [Índice Brasileiro de Privação (2025), *International Journal of Population Data Science*](https://pmc.ncbi.nlm.nih.gov/articles/PMC12629185/)
- [Allik and others (2020), Creating small-area deprivation indices: a guide for stages and options, *JECH*](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6929699/)
- Brown, D., Allik, M., Dundas, R. and Leyland, A. H. (2014) *Carstairs Scores for Scottish Postcode Sectors, Datazones and Output Areas from the 2011 Census*. University of Glasgow (cited by the IBP paper; not read).
- [Deas, Robson, Wong and Bradford (2003), Measuring neighbourhood deprivation: a critique of the Index of Multiple Deprivation, *Environment and Planning C* 21(6)](https://ideas.repec.org/a/sae/envirc/v21y2003i6p883-903.html)

### This repo

- [docs/chunks/uncertainty_in_regionalGVA](../docs/chunks/uncertainty_in_regionalGVA/)
- [adding_uncertainty_planner.md](adding_uncertainty_planner.md), section "Comparing slopes properly: z-test on the difference, not CI overlap"
