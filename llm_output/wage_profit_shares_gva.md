# Wages and profits in GVA: sectors, firms, value chains, countries and places

Claude Code research output, 29 October 2026. It pulls together published research and official data on how GVA splits between pay and profits, and adds some new UK and US calculations made for this note.

Where something is my own inference or calculation rather than a published finding, it is marked as such. My calculations are in sections 3.2, 5.2, 5.3, 7.2 to 7.5 and 7.7. The method is summarised in "How the numbers were computed" near the end, and the R scripts are in [code/wage_profit_shares](../code/wage_profit_shares/).

The note builds on two earlier pieces:

- [gva_sources_hmrc_productivity.md](gva_sources_hmrc_productivity.md) explains how ONS builds regional GVA. Section 7.1 below depends on it.
- The research notes in [DanOlner/modelling_demand](https://github.com/DanOlner/modelling_demand/tree/master/research/notes), especially [supply-chains-buyer-power-and-gva.md](https://github.com/DanOlner/modelling_demand/blob/master/research/notes/supply-chains-buyer-power-and-gva.md), [where-gva-is-recorded.md](https://github.com/DanOlner/modelling_demand/blob/master/research/notes/where-gva-is-recorded.md), [flows-and-value-added.md](https://github.com/DanOlner/modelling_demand/blob/master/research/notes/flows-and-value-added.md), [productivity-incomes-and-wealth.md](https://github.com/DanOlner/modelling_demand/blob/master/research/notes/productivity-incomes-and-wealth.md) and [revenue-vs-physical-productivity.md](https://github.com/DanOlner/modelling_demand/blob/master/research/notes/revenue-vs-physical-productivity.md). Where I reuse their evidence, I say so and don't repeat it in full.

## Short answers

- **The UK split.** In 2023, pay (compensation of employees) was 53% of UK GVA at basic prices. Gross operating surplus and mixed income made up 46%, and taxes on production 1%. That is about £1.17 of pay for every £1 of operating surplus and mixed income. But about a fifth of that surplus is the imputed rent of owner-occupied housing, which no firm earns. Without it, the ratio is about 1.5 to 1. ONS's preferred labour share, which treats part of self-employed income as pay, was 59.5% of GVA at factor cost in 2023. That's up from 53.8% in 1996 but below the 68% to 74% of 1948 to the late 1960s. Unlike the US, the UK labour share hasn't fallen since the mid-1990s.
- **Industries differ far more than places.** By industry, UK labour shares run from almost zero (owner-occupied housing) and about 10% to 25% (oil and gas, energy, real estate) to over 80% (health, care, education). Places sit in a narrow band. Excluding real estate, the ITL1 regions range from 62% (London) to 72% (North East), and ITL2 areas from 58% (Inner London West) to 75% (Merseyside).
- **Within industries, the big story is firms, not sectors.** In the US, the aggregate labour share fell mainly because output moved to "superstar" or "hyper-productive" firms with low labour shares. The typical firm's labour share didn't fall. UK manufacturing evidence points the other way: the typical firm's share fell. UK markups have risen modestly, mostly at the top of the distribution, and UK firms share less of their profits with workers than they used to.
- **Supply chains average factor shares out.** In the UK input–output tables, when you count every domestic supplier behind each product's final sales, the spread of labour shares across products narrows by over a quarter. In labour-intensive service and food chains, much of the surplus arises at suppliers: wholesalers, landlords, energy firms, leasing companies and farms. Globally, the profit share of value chains for manufactured goods rose between 1995 and 2008, especially the return to intangibles such as brands and design. Low- and medium-skilled pay fell as a share.
- **Countries look more alike once measurement is fixed.** Raw labour shares appear to range from 5% to 80% across countries. Once self-employed income is counted, most countries sit between 65% and 80%. Once housing and self-employment are handled consistently, labour shares in most advanced economies have been stable or have risen. The US (and Canada) are the exceptions.
- **Geography: the quantitative picture is real but partly constructed.** ONS's regional pay and profit components show London with the lowest labour share. That is mostly because London's industries have higher profit shares than the same industries elsewhere, not because of its industry mix. But regional profits are themselves shared out with indicators, and in finance and public services those indicators are pay. So part of the regional pattern reflects how ONS shares out profits rather than any measurement of them. The Annual Business Survey (ABS) gives a different regional ordering. Where profits actually go is clearer in the Scottish primary income accounts. Scotland's GNI was 94% of its GDP in 2021, because profits flow to owners outside Scotland. The best explanations of the geography are still qualitative: spatial divisions of labour, branch plants, head offices, and buyer power along supply chains.

## 1. What "wages" and "profits" mean in GVA

**The identity.** GVA at basic prices = compensation of employees + gross operating surplus + mixed income + (taxes less subsidies on production). GVA at factor cost leaves out the last term.

**UK, 2023** (ONS input–output analytical tables, consistent with Blue Book 2025):

| Component | £bn | Share of GVA |
|---|---|---|
| Compensation of employees | 1,330 | 53.2% |
| Gross operating surplus and mixed income | 1,141 | 45.7% |
| Taxes less subsidies on production | 26 | 1.1% |
| GVA at basic prices | 2,497 | 100% |
| *of which: owner-occupiers' housing services* | *254* | *10.2%* |

**Five things that change the measured ratio** of pay to profit:

1. **Self-employment.** Mixed income (sole traders) is part pay, part return on capital. Partnerships' profits sit inside gross trading profits, not mixed income. ONS compares five ways of splitting mixed income, which give 2023 UK labour shares from 55.2% (none of it counted as pay) to 63.5% (the self-employed assumed to earn the average employee's pay). ONS prefers 59.5%, which splits mixed income in the same proportions as the rest of the economy ([ONS, November 2024](https://www.ons.gov.uk/economy/economicoutputandproductivity/output/articles/trendsintheuklabourshare1997to2023/2024-11-25); [ONS 2018 methods](https://www.ons.gov.uk/economy/economicoutputandproductivity/productivitymeasures/methodologies/estimatingtheimpactoftheselfemployedinthelabourshare)). Owners of one-person companies who pay themselves in dividends show up as profit, not pay (my inference; ONS and Gutiérrez and Piton both flag the growth of incorporated self-employment).
2. **Housing.** Owner-occupiers' imputed rent is operating surplus with no workers attached. Gutiérrez and Piton put housing's labour share at about 6%, against about 66% in the corporate sector ([Bank Underground, 2019](https://bankunderground.co.uk/2019/08/07/is-there-really-a-global-decline-in-the-non-housing-labour-share/)).
3. **Depreciation.** Gross operating surplus includes the cost of capital wearing out. ONS's net labour share (pay over net value added at factor cost) was 71.5% in 2023, against a gross share of 59.5%.
4. **Taxes on production.** Business rates and similar taxes are in GVA at basic prices but not at factor cost. They are small in the UK (1% of GVA net of subsidies in 2023).
5. **"Profit" isn't pure profit.** Operating surplus pays for capital (depreciation, interest, the required return on equity), rents on land and natural resources, and true economic profit. Barkai estimates that in the US non-financial corporate sector the labour share fell about 10% and the capital share about 30% in percentage terms, while the pure profit share rose by more than 12 percentage points, over $1.1 trillion in 2014 ([Barkai, *Journal of Finance* 2020](https://econpapers.repec.org/RePEc:bla:jfinan:v:75:y:2020:i:5:p:2421-2463)).

**Why it matters for the rest of this note.** Most of the variation between industries, and some between places and countries, comes from these five items rather than from firms paying workers more or less. Sections 3, 6 and 7 adjust for housing and self-employment where they can.

## 2. The UK aggregate

From ONS's 2024 labour share article and its chart data (UK, % of GVA at factor cost, ONS method 5 unless stated):

- **Long run.** 74.4% in 1948 and between 68% and 74% until the late 1960s. It fell to about 65% in the early 1970s, jumped to 70.6% in 1975, then fell to 53.8% in 1996. It rose to 60.1% by 2001 and has stayed between 58.9% and 60.8% since. It was 59.5% in 2023.
- **Corporate sector only.** 62.3% gross and 72.8% net of depreciation in 2023.
- **Drivers of the rise since 1996**, according to ONS: the National Minimum Wage, more graduates, a tight labour market, a 340% rise in employers' social contributions (pensions auto-enrolment and deficit repair), and a shift towards services. ONS says "The UK has not experienced the decoupling between pay and productivity reported in other advanced countries."
- **G7 comparison** (method 4, index 1995 = 100, 2023): UK 108, France 101, Germany 97, Italy 98, Canada 94, US 90, Japan 95 (2022).
- **The median worker is a different question.** Teichgraeber and Van Reenen find that mean hourly compensation tracked productivity from 1981 to 2019, but median wages fell about 25 percentage points behind. About three fifths of that gap is rising pay inequality and about a third is non-wage costs, mostly pensions. Adjusted for self-employment and non-wage costs, they find the labour share fell about 3.5 points over four decades ([*International Productivity Monitor* 41](https://csls.ca/ipm-archive/ipm-issue-41/have-productivity-and-pay-decoupled-in-the-uk/); also in the modelling_demand incomes note).

ONS's numbers and Teichgraeber and Van Reenen's differ in period and adjustment, so they shouldn't be compared directly. Both reject a large UK fall in the labour share.

## 3. Across industries

### 3.1 UK broad groups (ONS)

ONS's industry chart (% of industry GVA at factor cost):

| Industry group | 1997 | 2022 |
|---|---|---|
| Real estate | 5.1 | 7.6 |
| Agriculture | 43.9 | 50.2 |
| Financial and insurance | 45.5 | 48.8 |
| Production | 58.5 | 54.9 |
| Construction | 82.0 | 60.4 |
| Distribution, transport, hotels and restaurants | 66.6 | 75.0 |
| Professional and support | 70.0 | 75.1 |
| Information and communication | 65.0 | 77.2 |
| Other services | 72.1 | 78.7 |
| Government, health and education | 84.2 | 83.8 |
| All industries | 57.9 | 62.1 |

Of the 4.3 point rise from 1997 to 2022, ONS attributes 2.4 points to shifts between industries, as services with higher labour shares grew. The largest fall within an industry was construction, down 21.6 points. I haven't found an ONS explanation. My guess is the growth of self-employment and one-person companies, whose owners' income counts as surplus.

### 3.2 UK detailed products, 2023 (my calculation)

From the 2023 product-by-product input–output table, labour share = compensation ÷ (compensation + operating surplus and mixed income). This counts all mixed income as profit, so it understates labour shares where self-employment is common. ONS's regional components show mixed income at 43% of agriculture's factor income, 38% in other services, 32% in construction and 20% in arts and recreation.

- **Lowest** (excluding owner-occupiers' housing at about 0%): oil and gas extraction 8.6%, electricity 17.3%, gas supply 17.6%, real estate (excluding fee-based) 22.5%, sewerage 22.7%, insurance and pensions 23.5%, agriculture 24.7%, water supply 30.0%, alcohol and tobacco 30.2%, refined petroleum 30.2%, pharmaceuticals 31.2%.
- **Highest** (excluding households as employers at 100%): membership organisations 87.1%, residential care and social work 85.4%, health 80.6%, air transport 79.6%, employment services 79.0%, paints and coatings 77.7%, education 77.4%, warehousing 76.8%, food and drink serving 76.6%.
- **Spread** (GVA-weighted, 102 products, excluding owner-occupiers' housing and households as employers): mean 59.9%, 10th percentile 23.5%, median 63.1%, 90th percentile 79.0%, standard deviation 18.7 points.

### 3.3 Why industries differ

From the evidence above and the research cited later:

- **Capital intensity and natural resource rents.** Extraction, energy, water and real estate need large fixed assets, and some earn resource or location rents. Their gross operating surplus also carries heavy depreciation.
- **Housing and property.** Real estate's surplus is mostly rent on buildings, including imputed rent.
- **Self-employment.** Agriculture, construction, personal services and the arts look capital-heavy only if mixed income is all counted as profit.
- **Market power and intangibles.** Pharmaceuticals, alcohol and tobacco, and some finance have high margins tied to brands, patents or scale. This links to the markup evidence in section 4.
- **Non-market output.** Public services' output is measured mostly by their inputs, so their labour share is high by construction. Their surplus is mainly the depreciation of public capital. The modelling_demand foundational economy note covers why these sectors fit badly with GVA-based measures.

## 4. Within industries: across firms

- **US: reallocation to superstar firms.** Autor, Dorn, Katz, Patterson and Van Reenen find that the US labour share fell mainly because sales moved to the leading firms in each industry, which have high markups and low labour shares. The unweighted mean labour share across firms was roughly flat from 1982 ([*QJE* 2020](https://researchonline.lse.ac.uk/id/eprint/83616)).
- **US manufacturing plants.** Kehrig and Vincent find the aggregate labour share in US manufacturing fell from 62% in 1967 to 41% in 2012, while the typical plant's rose by over 3 points. Output moved to "hyper-productive" plants with low labour shares. Their low shares come from high revenue productivity and a price premium, not low wages. In the 2018 version, they last only five to eight years before returning to their peers' level ([NBER WP 25275](https://econpapers.repec.org/RePEc:cpr:ceprdp:13333)).
- **UK manufacturing is different.** Valenzuela and Richiardi, using UK manufacturing firm data for 1998 to 2014, find the fall in the aggregate labour share was driven "entirely" by the representative firm, mainly because average productivity pulled away from real wages. Changes in dispersion between firms slightly offset the fall. They estimate that firm heterogeneity holds the aggregate labour share about 10 points higher than it would be in an economy of identical firms ([CeMPA WP 9/23](https://www.microsimulation.ac.uk/publications/publication-568040/); I read the abstract only).
- **UK markups.** The CMA finds average GB markups rose about 10% since 1997 and that the rise was up to three times larger at the top of the distribution. High-markup firms are older, bigger and more profitable (via the modelling_demand revenue-vs-physical note).
- **Less profit reaches workers.** Bell, Bukowski and Machin, using the top 300 UK listed companies over 35 years, find that wages still respond to firm-level profit shocks but much less after 2000 than in the 1980s and 1990s ([*Journal of Labor Economics* 2024](https://researchonline.lse.ac.uk/id/eprint/119448)).
- **Employer concentration.** Abel, Tenreyro and Thwaites find UK labour market concentration varies a lot across industries and regions but was stable overall from 1998 to 2017. More concentration goes with lower pay for workers without collective agreements, and with a weaker link between productivity and pay ([CFM DP 2018-27](https://www.lse.ac.uk/CFM/assets/pdf/CFM-Discussion-Papers-2018/CFMDP2018-27-Summary.pdf)).
- **OECD countries.** Where labour shares fell, Schwellnus and others find both a fall at the technological frontier and a shift of market share to "superstar" firms with low labour shares. The frontier fall mainly reflects capital-intensive firms with low labour shares entering the frontier ([OECD Economics WP 1503, 2018](https://econpapers.repec.org/RePEc:oec:ecoaaa:1503-en)).

**Reading these together** (my synthesis). Within an industry, a firm's labour share is mostly an inverse measure of its margin. It is low where the firm has high revenue productivity, pricing power, intangibles or a recent productivity jump, and high where the firm is squeezed. That makes the firm-level split a demand-and-power story as much as a technology story, which fits the Webber and Huaccha framing in the modelling_demand notes.

## 5. Along supply chains and value chains

### 5.1 The accounting

The modelling_demand supply-chain note sets out the identity. Chain GVA = final sales − primary and imported inputs, and the prices between stages only decide who gets what. So the split between pay and profit at each stage depends on bargaining power at each link as well as on the stage's own technology. Webber and Huaccha's illustrative yoghurt chain has labour shares of 45% (dairy), 33% (processor) and 30% (shop), and net-profit shares of 18%, 13% and 33%. These numbers are hypothetical.

### 5.2 UK supply chains, 2023 (my calculation)

For each product, I traced the pay and surplus generated by every UK industry behind its final sales, using the Leontief inverse of the 2023 domestic input–output table. I then compared that "whole-chain" labour share with the product's own labour share. Imported inputs are left out, because their pay and profit are earned abroad.

- **The spread narrows.** The GVA-weighted standard deviation across products falls from 18.7 points (own industry) to 13.5 points (whole chain). The 10th percentile rises from 23.5% to 33.7% and the 90th falls from 79.0% to 75.0%. The mean barely moves (59.9% to 59.7%). Rankings mostly survive: the correlation between the two measures is 0.98.
- **Capital-heavy products have more labour in their chains:**

  | Product | Own labour share | Whole-chain labour share |
  |---|---|---|
  | Oil and gas extraction | 8.6% | 19.9% |
  | Electricity | 17.3% | 32.7% |
  | Insurance and pensions | 23.5% | 33.3% |
  | Agriculture | 24.7% | 38.9% |
  | Construction | 41.9% | 48.3% |

- **Labour-intensive products have more profit in their chains:**

  | Product | Own labour share | Whole-chain labour share |
  |---|---|---|
  | Residential care | 85.4% | 80.2% |
  | Health | 80.6% | 75.0% |
  | Air transport | 79.6% | 65.5% |
  | Food and drink serving | 76.6% | 68.2% |
  | Bakery products | 73.4% | 64.5% |
  | Meat products | 65.8% | 56.3% |
  | Retail | 62.6% | 60.7% |
  | Dairy products | 62.0% | 51.5% |

- **Where the extra surplus comes from** (my decomposition of each chain's surplus by the supplying product):
  - Food and drink serving: 56% of the chain's surplus arises at suppliers, spread widely. The largest sources are wholesale (10% of supplier surplus), commercial property (10%), electricity (6%), drinks manufacturing (5%) and agriculture (5%).
  - Air transport: 75% arises at suppliers, led by rental and leasing, mostly aircraft (25%), and property (15%).
  - Retail: commercial property is the largest supplier source (20% of supplier surplus), then advertising (10%).
  - Dairy products: agriculture supplies 48% of supplier surplus. Much of that is farmers' mixed income, which is partly pay for their own work, so the dairy chain's labour share is understated. The same applies, less strongly, to bakery and meat.
  - Commercial property rent is among the top two supplier sources in most of the service chains I checked. Paying landlords is one of the main ways capital income enters labour-intensive service chains.

### 5.3 By type of final demand, 2023 (ONS's own table)

ONS's "primary input content of final use" table splits each £ of final demand into imports, product taxes, pay, surplus and production taxes. I computed the labour share of the domestic value added in each:

| Final demand | Pay ÷ (pay + surplus) | Import content per £ |
|---|---|---|
| Government consumption | 71.4% | 10.9% |
| Non-profit institutions | 72.1% | 5.9% |
| Services exports | 60.9% | 17.5% |
| Goods exports outside the EU | 55.8% | 29.2% |
| Investment (GFCF) | 55.2% | 14.7% |
| Goods exports to the EU | 52.2% | 28.7% |
| Household consumption | 41.7% | 11.1% |

Household consumption looks capital-heavy because it includes owner-occupiers' imputed rent. That's a reminder that "the profit share of what households buy" is partly housing, not firms' margins.

### 5.4 Case studies along single chains

- **US food (USDA ERS Food Dollar, 2024).** Of each dollar spent on domestically produced food, 54.1 cents paid salaries and benefits, 32.7 cents property income, 7.2 cents taxes, and about 6 cents imports (the last by my subtraction). By industry, food services' value added was 38.6 cents of each dollar and farms' 6.7 cents. Labour's share rose from 51.6 cents in 2020, when property income peaked at 39.4 cents, its highest since 1997 ([ERS summary findings](https://ers.usda.gov/data-products/food-dollar/summary-findings)). This is the closest published equivalent to my section 5.2 calculation, for one chain.
- **UK dairy.** Retail margins on liquid milk rose while farmgate prices fell in the 2000s, and processors' margins fell. In 2022–23, retailers absorbed some cost increases (CMA). Details and caveats are in the modelling_demand supply-chain note.
- **iPhone, 2010.** Kraemer, Linden and Dedrick estimate Apple's profit at 58.5% of the sales price, other firms' profits at about 15%, materials 21.9%, non-China labour 3.5% and China labour 1.8%. Suppliers' profits are booked in their headquarters' country (in the modelling_demand where-GVA-is-recorded note).
- **The smile curve.** Value added is said to be higher at the research and design end and the marketing and retail end than in assembly. Rungi and Del Prete find a U-shape in value added against distance from final demand in about 2 million EU firms. They also find foreign affiliates add more value in the middle stages, while domestic firms keep more at the two ends ([*Economics Letters* 2018](https://econpapers.repec.org/RePEc:eee:ecolet:v:164:y:2018:i:c:p:38-42)). These studies measure value added, not its split into pay and profit.

### 5.5 Global value chains

- **Manufactures, 1995–2008.** Timmer, Erumban, Los, Stehrer and de Vries trace all value added in the global value chains of final manufactured goods, using WIOD. Capital's share rose from 40.9% to 47.4%. High-skilled labour rose from 13.8% to 15.4%, while medium-skilled fell from 28.7% to 24.4% and low-skilled from 16.6% to 12.8% ([*JEP* 2014](https://econpapers.repec.org/RePEc:aea:jecper:v:28:y:2014:i:2:p:99-118); figures from [Timmer's 2015 ECB presentation](https://www.ecb.de/home/pdf/research/compnet/20150625/1g_Timmer.pdf)). Total labour therefore fell from about 59% to 53% (my sum).
- **Intangibles.** Chen, Los and Timmer find falling labour and rising capital shares over 2000–2014, mainly from rising income to intangibles, especially in chains for durable goods. An earlier WIPO version puts intangible capital income at about 31% of the value of manufactured goods in 2014 ([NBER WP 25242](https://www.nber.org/papers/w25242); [WIPO WP 36](https://www.wipo.int/edocs/pubdocs/en/wipo_pub_econstat_wp_36.pdf)).
- **Where in the chain a country sits matters.** The IMF found that in advanced economies about half the fall in labour shares came from technology and that global integration contributed about half as much. In emerging markets, taking part in global value chains was the main driver ([IMF blog on WEO April 2017, chapter 3](https://www.imf.org/en/blogs/articles/2017/04/12/drivers-of-declining-labor-share-of-income)).
- **Booking.** Where the profit of a chain is recorded depends on who owns the intellectual property and on tax planning. Tørsløv, Wier and Zucman estimate that about 36% of multinational profits are shifted to tax havens (in the modelling_demand where-GVA-is-recorded note, with Ireland's 2015 GDP jump as the extreme case).

## 6. Across countries

- **Levels.** The ILO puts the global labour income share, including imputed self-employed income, at about 52.3% of GDP in 2022 to 2024. It fell 0.6 points from 2019 to 2022, and press coverage reports a 1.6 point fall over two decades ([ILO metadata](https://unstats.un.org/sdgs/metadata/files/Metadata-10-04-01.pdf); [WAM report of the ILO's September 2024 update](https://www.wam.ae/en/article/143q2cy-global-labour-income-share-declines-putting-upward)). I couldn't open the ILO's own report.
- **Measurement explains most apparent gaps.** Gollin found raw labour shares across countries range from about 5% to 80%. Once the income of the self-employed is counted, most countries fall between 65% and 80%, with no systematic link to income per head ([*JPE* 2002](https://econpapers.repec.org/RePEc:ucp:jpolec:v:110:y:2002:i:2:p:458-474)).
- **The decline is contested outside the US.** Karabarbounis and Neiman found the global labour share fell from the early 1980s in seven of the eight largest economies and in most industries. Most of the fall, and most of the variation between countries, was within industries. They attribute about half to cheaper investment goods ([NBER Reporter 2017](https://www2.nber.org/reporter/2017number4/karabarbounis.html)). Gutiérrez and Piton argue that once housing and self-employment are treated consistently, labour shares have been stable in most advanced economies except the US and Canada. US manufacturing's labour share fell 21%, against 1.5% in Europe ([BoE Staff WP 811](https://www.bankofengland.co.uk/-/media/boe/files/working-paper/2019/revisiting-the-global-decline-of-the-non-housing-labor-share.pdf)). Rognlie finds the long-run rise in the net capital share in seven large economies, including the UK, comes from housing ([Brookings 2015](https://www.brookings.edu/articles/deciphering-the-fall-and-rise-in-the-net-capital-share)).
- **Why corporate sectors differ between countries.** The US corporate sector covers only legal corporations, while countries following SNA 2008 also include quasi-corporations, partnerships and housing they own. So "corporate labour shares" aren't like for like across countries (Gutiérrez and Piton).

**Taken together** (my synthesis). Differences between countries in the split between pay and profit are smaller than they look. They are driven by self-employment, housing, natural resources, where a country sits in global value chains, and where multinationals book profits. The US is the clear case of a real fall in the non-housing labour share. The UK has risen since the mid-1990s.

## 7. Geography

### 7.1 First, how ONS builds regional pay and profits

ONS publishes regional pay, profit and other income components for ITL1 and ITL2 by industry ([dataset](https://www.ons.gov.uk/economy/grossvalueaddedgva/datasets/nominalregionalgrossvalueaddedbalancedperheadandincomecomponents)). But each component is a national total shared out by an indicator (see [gva_sources_hmrc_productivity.md](gva_sources_hmrc_productivity.md), section 2.2):

- compensation of employees: BRES jobs × ASHE pay, and ABS employee costs in manufacturing;
- company trading profits: ABS operating surplus for most industries, but **pay** for finance and the public sector;
- mixed income: HMRC self-assessment, placed at the filer's home address as of 2009;
- rental income: business rates, house prices and dwelling stock.

Two consequences:

- **Where profits are shared out by pay, the regional labour share is set by assumption.** Finance's labour share varies only from 43.6% to 50.0% across ITL1 regions in 2023 (standard deviation 2.0 points). For most manufacturing industries, whose profits follow ABS operating surplus, the standard deviation is 5 to 13 points.
- **Older vintages are worse.** In ONS's 2009 method, company profits outside manufacturing were shared out by pay. So regional labour shares outside manufacturing were close to uniform by construction. Any study of regional labour shares using GVA(I) components from before the 2017 balancing work should be read with this in mind (my inference from the 2009 inventory).

Even under today's method, ABS operating surplus is placed at sites by the ABS's regional model, which uses register employment. So a multi-site firm's profits are spread across its sites, not measured where they arise.

### 7.2 UK ITL1 regions, 2023 (my calculation)

The labour share here follows ONS method 5, which splits mixed income by each region's own ratio of pay to other factor income. "Expected from mix" applies each industry's labour share for the UK less Extra-Regio to the region's industry mix (excluding real estate). "Within-industry gap" is the actual share minus the expected share.

The benchmark is UK less Extra-Regio because that is what the 12 regions add up to. Using the whole UK would set mining's benchmark labour share at 12% rather than 51%, because offshore oil and gas sits in Extra-Regio. That would give mining areas such as North Eastern Scotland a large, spurious positive gap.

| Region | Labour share, all industries | Excluding real estate | Expected from mix | Within-industry gap (points) | Trading profits, % of factor income |
|---|---|---|---|---|---|
| North East | 64.6% | 72.2% | 68.6% | +3.6 | 19.2% |
| West Midlands | 64.0% | 71.6% | 68.7% | +2.8 | 20.6% |
| East Midlands | 63.0% | 70.9% | 69.2% | +1.7 | 21.3% |
| South West | 60.5% | 70.1% | 68.5% | +1.6 | 19.9% |
| Northern Ireland | 62.2% | 69.8% | 68.9% | +0.9 | 21.9% |
| North West | 62.6% | 69.7% | 68.8% | +0.9 | 23.2% |
| South East | 60.2% | 69.6% | 69.0% | +0.7 | 21.2% |
| Wales | 62.1% | 69.6% | 68.3% | +1.3 | 21.9% |
| Yorkshire and The Humber | 62.2% | 69.4% | 68.4% | +1.0 | 21.3% |
| Scotland | 61.1% | 68.7% | 67.8% | +0.9 | 21.3% |
| East of England | 57.6% | 66.3% | 68.5% | −2.1 | 23.8% |
| London | 56.5% | 62.1% | 65.5% | −3.4 | 27.9% |
| UK less Extra-Regio | 60.2% | 67.8% | | | 23.1% |
| UK (including Extra-Regio) | 59.6% | 66.9% | | | 23.9% |

What stands out:

- **London is low because of trading profits within industries, not housing.** London's rental income share (10.1% of factor income) is actually the lowest of any region. The South West, South East and East are all above 13%. Its industry mix explains about 2.3 points (40%) of its 5.7 point gap from the UK less Extra-Regio. The other 3.4 points are within industries. Comparing industry by industry (which gives a slightly smaller total, −3.2 points), the biggest contributors are professional and scientific services (−1.1 points), wholesale and retail (−0.5), information and communication (−0.4) and administrative services (−0.35). One candidate for professional services (my inference, not checked) is partnership income: large law and accounting partnerships' profits count as trading profits, and are partly pay for partners' work.
- **Most regions are above the UK figure.** That's because London is large and low, and the UK total also includes Extra-Regio. Extra-Regio is mostly offshore oil and gas: £30bn of GVA in 2023 with a labour share of about 10%. Offshore profits aren't placed in Scotland or anywhere else.
- **Scotland's own pattern.** Food and drink manufacturing, mostly whisky, has a labour share of 49.8% in Scotland against 62.0% for the UK. That alone takes 0.45 points off Scotland's total.

### 7.3 UK ITL2 areas, 2023 (my calculation)

Excluding real estate, across all 46 ITL2 areas in the workbook downloaded on 29 October 2026:

- range 58.2% (Inner London – West) to 74.7% (Merseyside), median 70.1%, standard deviation 3.3 points;
- lowest: Inner London – West 58.2%, Cheshire 63.2%, Inner London – East 64.1%, Essex 64.7%, North Yorkshire 64.9%, Norfolk 65.2%;
- highest: Merseyside 74.7%, South Yorkshire 74.5%, Devon 73.9%, Northumberland, Durham and Tyne & Wear 73.4%, Tees Valley 73.3%, Kent 73.3%, West Midlands 72.9%;
- the within-industry gap varies more than the industry-mix effect: standard deviations of 2.3 and 1.6 points, with a correlation of 0.40 between them.

Including real estate, the lowest shares are in Essex, outer London and Inner London – West (55% to 56%), where housing income weighs more.

### 7.4 Trends in UK regions (my calculation)

Excluding real estate, method 5:

| Year | London | North East | UK |
|---|---|---|---|
| 1998 | 64.4% | 68.0% | 64.4% |
| 2001 | 71.8% | 72.4% | 69.3% |
| 2007 | 67.3% | 69.8% | 68.4% |
| 2010 | 65.5% | 70.6% | 67.4% |
| 2016 | 63.8% | 69.8% | 66.7% |
| 2019 | 64.2% | 71.3% | 66.9% |
| 2023 | 62.1% | 72.2% | 66.9% |

From 1998 to 2019, the standard deviation across the 12 ITL1 regions was between 1.6 and 2.5 points, and the gap between highest and lowest between 4.6 and 8.4 points. Since 2020 the gap has been above that band every year (8.7 to 10.1 points), and in 2023 the standard deviation reached 2.7 points, its highest in the series. Most of the widening is London's labour share falling. Whether that is real or an artefact of the allocation in section 7.1 can't be told from these data.

### 7.5 A cross-check with the ABS (my calculation)

The repo's ABS file (`data/abs_itl1_long.csv`) gives employment costs and aGVA for the non-financial business economy by ITL1, with standard errors.

- **2023:** employment costs ÷ aGVA ranges from 50.0% (Northern Ireland) to 57.9% (East Midlands). London is 55.0% and the UK 55.2%. Standard errors are about 0.4 to 1.5 points, assuming independent errors, which probably overstates them because the two variables come from the same sample.
- **Rankings move.** London was lowest in 2019 (50.7%) but mid-table in 2023. Scotland was lowest in 2008 (44.6%).
- **The two sources only weakly agree.** I restricted ONS's components to roughly the ABS's industries (A to J, M, N, R, S), with no self-employment adjustment. On that basis, the rank correlation with the ABS across ITL1 regions was 0.48 in 2019 and 0.10 in 2023. Levels differ by about 5 points.

So the regional ordering of labour shares depends on the source and the year. The broad finding that London and the East have lower labour shares in ONS's balanced figures doesn't show up clearly in the ABS. That fits the point that regional profits are hard to place.

### 7.6 Where the profits go: income, not output

Workplace GVA records where pay and profit arise. It doesn't record who receives them.

- **Scotland's primary income account.** In 2021 Scotland had a primary income deficit of £10.1bn, 5.6% of GDP. Its GNI was 94.4% of GDP, and below GDP in every year from 1998, averaging 90.6% in 1998–2007 and 92.5% in 2008–2021. The Scottish Government points to foreign ownership (including North Sea operators), few UK headquarters in Scotland, and a large insurance and pensions sector whose policyholders live elsewhere. Direct investment income was the largest outflow, at 3.2% of GDP ([Scottish Government, primary income accounts 1998–2021](https://gov.scot/publications/primary-income-accounts-and-gni-1998-2021); [Fraser of Allander, 2018](https://fraserofallander.org/gross-national-income-statistics-for-scotland-a-net-outflow-of-scottish-income/)). The series is experimental, and I found no estimate after 2021.
- **Ownership.** At the end of 2024, 58.8% of UK quoted shares were owned overseas (in the modelling_demand incomes note). Foreign-owned businesses were 1.4% of non-financial businesses but produced 28.4% of aGVA in 2020 ([ONS ABS foreign ownership, 2020](https://ons.gov.uk/businessindustryandtrade/business/businessservices/articles/annualbusinesssurvey/2020)).
- **Commuting.** Regional pay is by workplace, while household income (GDHI) is by residence. So a region's labour share says nothing directly about its residents' incomes (in the modelling_demand where-GVA-is-recorded note).

I found no equivalent of Scotland's GNI estimates for English regions or Wales. This is the main quantitative gap on the geography of profits.

### 7.7 US states (my calculation, with published work)

From BEA state GDP by income component (bulk files dated September 2026), labour share = compensation ÷ (compensation + gross operating surplus). BEA's state operating surplus includes proprietors' income, so these are raw shares. I haven't checked how BEA shares out multi-state corporations' surplus.

- **US 2024:** 54.8%, or 61.5% excluding real estate. It was 58.9% in 1997, 61.1% in 2000 and 57.1% in 2019.
- **States and DC, excluding real estate, 2024:** from 46.0% (Delaware) to 72.0% (DC), median 62.4%, standard deviation 5.2 points, about twice the UK ITL1 spread.
  - Lowest: Delaware, Nebraska, South Dakota, North Dakota, Iowa, Texas, Wyoming, Louisiana. My reading, not checked industry by industry: finance and corporate registration (Delaware, South Dakota), farm proprietors (Nebraska, the Dakotas, Iowa) and oil and gas (North Dakota, Texas, Wyoming, Louisiana).
  - Highest: DC (federal government), then Maine, Hawaii, Oregon and Florida.
- **Within industries across states, 2024** (10th to 90th percentile): manufacturing 41% to 65%, mining 22% to 61%, finance 34% to 60%, wholesale 48% to 58%, retail 56% to 61%, health 80% to 85%. So profit-heavy, capital-heavy industries vary most between places.
- **Published work.** Abdih and Danninger find the US decline was broad-based across states but varied a lot in size. It was largest in industries with many routine jobs, falling unionisation, import competition and foreign inputs ([IMF WP 17/167](https://imf.org/-/media/Files/Publications/WP/2017/wp17167.ashx)). Mendieta-Muñoz, Rada, Schiavone and von Arnim find most of the fall in the US payroll share from 1977 to 2017 happened within regions, with Rust Belt states driving the fall in the 1980s ([INET WP 121](https://www.ineteconomics.org/uploads/papers/WP_121-Mendieta-et-al.pdf); published in *Regional Studies*, 2022).

### 7.8 Mechanisms: mostly qualitative evidence

- **Spatial divisions of labour.** Massey's *Spatial Divisions of Labour* (1984) argued that firms put headquarters, research and design in core regions and routine production in peripheral ones. In this note's terms, a region's labour share partly reflects which stage of its firms' value chains it hosts (my link). The smile curve (section 5.4) suggests the high-value-added ends cluster in core cities.
- **Branch plants and external control.** The older UK literature on branch plants (for example Firn, 1975, on Scotland) argued that externally owned plants send profits and decision-making out of the region. Scotland's GNI figures are the clearest modern quantitative trace of this.
- **Head offices and booking.** ONS's statistics share out profits by indicators rather than measuring them by site, and the multi-site problems in the HMRC note apply. For profits, the question of where they "really" arise has no clean answer even in principle. The Webber and Huaccha chain identity shows that relocating a profit can be a matter of transfer prices.
- **Buyer power and rural places.** Webber and Tiwasing argue that rural firms have smaller territories and face stronger buyers, so rural GVA per worker is lower with no change in physical productivity. In majority-rural English authorities, GVA per workforce job was 92% of the England (excluding London) average in 2023, and 82% in the more remote ones (Defra; in the modelling_demand supply-chain note). They don't measure the split between pay and profit directly.
- **Density and the firm labour share.** Mayneris finds that firm-level labour shares rise slightly with local employment density on average, with large differences between industries ([CEPR DP 17678](https://ideas.repec.org/p/cpr/ceprdp/17678.html); I read the abstract only). So the urban pay premium doesn't obviously come with lower or higher labour shares, and London's low labour share is not a general density effect.
- **Monopsony.** UK employer concentration varies by region, and higher concentration goes with lower pay for non-unionised workers (Abel, Tenreyro and Thwaites, section 4). That is a plausible route to higher profit shares in thin local labour markets. I found no UK study that maps it onto regional labour shares.
- **Housing.** Imputed rent was 9% to 11% of UK GVA over 1998–2023, according to SQW citing ONS (in [gva_sources_hmrc_productivity.md](gva_sources_hmrc_productivity.md)). Any regional "profit share" that includes real estate partly measures house prices.

## 8. What this means for RegEconWorks

- **Treat regional profit shares as partly modelled.** Before using ONS's regional components to say anything about the pay–profit split in a place, label each industry by how its profits are shared out. Finance and public services follow pay, and most market industries follow the ABS regional model. This is the same A, B and C distinction as section 7 of the HMRC note.
- **Report labour shares with and without real estate, and with a self-employment adjustment.** Housing and mixed income move regional and industry shares by more than most real differences do.
- **Use the ABS as a sampling-error check, not as truth.** The ABS standard errors in the repo give an error bar on the ABS ratio. But disagreement between the ABS and ONS's balanced figures is larger than either error bar, which points to definitional and allocation differences.
- **Supply-chain shares are a useful second lens.** Whole-chain labour shares from input–output tables compress differences between products and show how property rent and energy feed capital income into service chains. A regional version would need multi-regional input–output tables: Scotland and Wales have their own, and there is academic UK multi-regional work (modelling_demand flows note).
- **Workplace versus ownership.** For living standards, the Scottish GNI approach is the model. A regional primary income account for English regions doesn't exist yet.
- **Firm-level data could test the allocation.** The CenTax Business-to-Worker Register links profits, wage bills and workers' home locations for UK firms (HMRC note, section 4). It could give regional labour shares that don't depend on ONS's indicators, though it places firms by where their workers live, not where they work.

## 9. Things I couldn't check

- How ONS shares out partnership profits regionally now, and whether self-assessment income is still placed by home address. Both affect section 7.2, especially London's professional services.
- How BEA allocates operating surplus to states.
- The full texts of Valenzuela and Richiardi, Mayneris, and the ILO September 2024 report. I worked from abstracts and summaries.
- Why construction's UK labour share fell 21.6 points from 1997 to 2022.
- Whether the September 2026 regional components workbook has been revised since I downloaded it. The dataset page still carries a notice about suppressed ITL2 estimates, but all 46 ITL2 areas have data in the file I downloaded. It runs from 1998 to 2023.
- Any study measuring regional labour shares across EU NUTS2 regions. Eurostat publishes the inputs (compensation of employees and GVA by NUTS2), but I didn't find a comparative paper.

## How the numbers were computed

The R scripts are in [code/wage_profit_shares](../code/wage_profit_shares/). Run them from the project root. They download raw files once into `local/wage_profit_raw/` (gitignored) and print the numbers used here. Shared functions, including the labour share calculation, are in `functions.R`. A rendered summary with charts, which sources the same scripts, is in [docs/chunks/wage_profit_shares](../docs/chunks/wage_profit_shares/wage_profit_shares.qmd).

- **Sections 2 and 3.1** (`01_ons_labour_share_article.R`). CSV downloads of ONS's charts in the November 2024 labour share article.
- **Sections 1, 3.2, 5.2 and 5.3** (`02_io_supply_chain_shares.R`). ONS [input–output analytical tables, 2023](https://www.ons.gov.uk/economy/nationalaccounts/supplyandusetables/datasets/ukinputoutputanalyticaltablesdetailed) (`iot2023product.xlsx`, consistent with Blue Book 2025), sheet "IOT": 105 products, domestic use at basic prices.
  - Coefficients `A = Z / x`, where Z is domestic intermediate use and x is output.
  - Pay and surplus coefficients per £ of output: `d = D1 / x`, `g = (GOS & MI) / x`.
  - Whole-chain content per £ of final demand for each product: `d'(I − A)⁻¹` and `g'(I − A)⁻¹`. Whole-chain labour share = pay content ÷ (pay + surplus content).
  - Summary statistics are weighted by each product's own GVA, excluding owner-occupiers' housing and households as employers.
  - Supplier sources of a chain's surplus: product i's contribution to product j's chain = `g_i × L_ij`, where L is the Leontief inverse. I ran this for food and drink serving, air transport, retail, dairy, bakery and health.
  - Section 5.3 takes shares directly from the "Primary input from final use" sheet of the same workbook.
- **Sections 7.1 to 7.4** (`03_regional_shares.R`). ONS [regional GVA(B) per head and income components](https://www.ons.gov.uk/economy/grossvalueaddedgva/datasets/nominalregionalgrossvalueaddedbalancedperheadandincomecomponents), downloaded 29 October 2026, tables 6 to 16.
  - Factor income = compensation + mixed income + rental income + non-market capital consumption + holding gains (negative) + gross trading profits + gross trading surplus.
  - Labour share = (compensation + α × mixed income) ÷ factor income, where α = compensation ÷ (compensation + other factor income), computed per region and industry group. This mirrors ONS's method 5.
  - "Expected from mix" = Σ over industries of (region's factor-income weight × industry labour share for the UK less Extra-Regio), excluding section L. The overlapping "CD-CF" row was dropped.
  - The industry ranges in section 7.1 are across the 12 regions, also compared with the UK less Extra-Regio.
- **Section 7.5** (`04_abs_crosscheck.R`). `data/abs_itl1_long.csv` in this repo (ABS 2024 edition, made by `code/ABS_direct_dataprep.R`): employment costs ÷ aGVA. Standard errors by the delta method, assuming independent errors.
- **Section 7.7** (`05_us_states.R`). BEA [state GDP bulk download](https://apps.bea.gov/regional/zip/SAGDP.zip), tables SAGDP4 (compensation) and SAGDP7 (gross operating surplus). Real estate is NAICS 531.

## Sources

### UK official statistics

- [Trends in the UK labour share: 1997 to 2023 (ONS, 25 November 2024)](https://www.ons.gov.uk/economy/economicoutputandproductivity/output/articles/trendsintheuklabourshare1997to2023/2024-11-25), with chart data downloaded as CSV
- [Estimating the impact of the self-employed in the labour share (ONS, September 2018)](https://www.ons.gov.uk/economy/economicoutputandproductivity/productivitymeasures/methodologies/estimatingtheimpactoftheselfemployedinthelabourshare)
- [UK input–output analytical tables, 2023 (ONS)](https://www.ons.gov.uk/economy/nationalaccounts/supplyandusetables/datasets/ukinputoutputanalyticaltablesdetailed)
- [Regional gross value added (balanced) per head and income components (ONS dataset)](https://www.ons.gov.uk/economy/grossvalueaddedgva/datasets/nominalregionalgrossvalueaddedbalancedperheadandincomecomponents)
- [Annual Business Survey: foreign-owned businesses, 2020 (ONS)](https://ons.gov.uk/businessindustryandtrade/business/businessservices/articles/annualbusinesssurvey/2020)
- [Primary income accounts and GNI for Scotland, 1998–2021 (Scottish Government)](https://gov.scot/publications/primary-income-accounts-and-gni-1998-2021)
- [Gross national income statistics for Scotland: a net outflow of Scottish income? (Fraser of Allander Institute, May 2018)](https://fraserofallander.org/gross-national-income-statistics-for-scotland-a-net-outflow-of-scottish-income/)

### Labour share: aggregate and cross-country

- [Gutiérrez and Piton, Revisiting the global decline of the (non-housing) labor share (Bank of England Staff WP 811, 2019)](https://www.bankofengland.co.uk/-/media/boe/files/working-paper/2019/revisiting-the-global-decline-of-the-non-housing-labor-share.pdf), and [Bank Underground summary](https://bankunderground.co.uk/2019/08/07/is-there-really-a-global-decline-in-the-non-housing-labour-share/)
- [Karabarbounis and Neiman, The global decline of the labor share (*QJE* 2014)](https://econpapers.repec.org/RePEc:oup:qjecon:v:129:y:2014:i:1:p:61-103), and [Trends in factor shares (NBER Reporter, 2017)](https://www2.nber.org/reporter/2017number4/karabarbounis.html)
- [Gollin, Getting income shares right (*JPE* 2002)](https://econpapers.repec.org/RePEc:ucp:jpolec:v:110:y:2002:i:2:p:458-474)
- [Rognlie, Deciphering the fall and rise in the net capital share (Brookings Papers, 2015)](https://www.brookings.edu/articles/deciphering-the-fall-and-rise-in-the-net-capital-share)
- [Barkai, Declining labor and capital shares (*Journal of Finance* 2020)](https://econpapers.repec.org/RePEc:bla:jfinan:v:75:y:2020:i:5:p:2421-2463)
- [ILO SDG 10.4.1 metadata](https://unstats.un.org/sdgs/metadata/files/Metadata-10-04-01.pdf), and [press report on the ILO's September 2024 update](https://www.wam.ae/en/article/143q2cy-global-labour-income-share-declines-putting-upward)
- [Teichgraeber and Van Reenen, Have productivity and pay decoupled in the UK? (*International Productivity Monitor* 41)](https://csls.ca/ipm-archive/ipm-issue-41/have-productivity-and-pay-decoupled-in-the-uk/)
- [IMF, Drivers of declining labor share of income (blog on WEO April 2017, chapter 3)](https://www.imf.org/en/blogs/articles/2017/04/12/drivers-of-declining-labor-share-of-income)

### Firms

- [Autor, Dorn, Katz, Patterson and Van Reenen, The fall of the labor share and the rise of superstar firms (*QJE* 2020)](https://researchonline.lse.ac.uk/id/eprint/83616)
- [Kehrig and Vincent, The micro-level anatomy of the labor share decline (NBER WP 25275 / CEPR DP 13333)](https://econpapers.repec.org/RePEc:cpr:ceprdp:13333)
- [Richiardi and Valenzuela, Firm heterogeneity and the aggregate labour share (CeMPA WP 9/23)](https://www.microsimulation.ac.uk/publications/publication-568040/)
- [Bell, Bukowski and Machin, The decline in rent sharing (*Journal of Labor Economics* 2024)](https://researchonline.lse.ac.uk/id/eprint/119448)
- [Abel, Tenreyro and Thwaites, Monopsony in the UK (CFM DP 2018-27)](https://www.lse.ac.uk/CFM/assets/pdf/CFM-Discussion-Papers-2018/CFMDP2018-27-Summary.pdf)
- [Schwellnus, Pak, Pionnier and Crivellaro, Labour share developments over the past two decades (OECD Economics WP 1503, 2018)](https://econpapers.repec.org/RePEc:oec:ecoaaa:1503-en)

### Value chains

- [Timmer, Erumban, Los, Stehrer and de Vries, Slicing up global value chains (*JEP* 2014)](https://econpapers.repec.org/RePEc:aea:jecper:v:28:y:2014:i:2:p:99-118); [Timmer, ECB CompNet presentation (2015)](https://www.ecb.de/home/pdf/research/compnet/20150625/1g_Timmer.pdf)
- [Chen, Los and Timmer, Factor incomes in global value chains: the role of intangibles (NBER WP 25242)](https://www.nber.org/papers/w25242); [Chen, Gouma, Los and Timmer (WIPO Economic Research WP 36, 2017)](https://www.wipo.int/edocs/pubdocs/en/wipo_pub_econstat_wp_36.pdf)
- [Rungi and Del Prete, The smile curve at the firm level (*Economics Letters* 2018)](https://econpapers.repec.org/RePEc:eee:ecolet:v:164:y:2018:i:c:p:38-42)
- [USDA ERS Food Dollar Series, summary findings (2024 data)](https://ers.usda.gov/data-products/food-dollar/summary-findings)

### Geography

- [BEA state GDP bulk download (SAGDP)](https://apps.bea.gov/regional/zip/SAGDP.zip)
- [Abdih and Danninger, What explains the decline of the U.S. labor share of income? (IMF WP 17/167)](https://imf.org/-/media/Files/Publications/WP/2017/wp17167.ashx)
- [Mendieta-Muñoz, Rada, Schiavone and von Arnim, payroll share across US states (INET WP 121; *Regional Studies* 56(2), 2022)](https://www.ineteconomics.org/uploads/papers/WP_121-Mendieta-et-al.pdf)
- [Mayneris, Does the urban wage premium imply higher firm-level labor shares in cities? (CEPR DP 17678)](https://ideas.repec.org/p/cpr/ceprdp/17678.html)
- Massey, D. (1984) *Spatial Divisions of Labour: Social Structures and the Geography of Production*. Macmillan.
- Firn, J. (1975) "External control and regional development: the case of Scotland", *Environment and Planning A* 7(4): 393–414.

### Notes in other repos

- [DanOlner/modelling_demand research notes](https://github.com/DanOlner/modelling_demand/tree/master/research/notes): supply chains and buyer power (dairy margins, CMA, Webber and Tiwasing, smile curve); where GVA is recorded (iPhone, Ireland, profit shifting, ONS finance allocation); flows and value added (input–output, vertical integration); productivity, incomes and wealth (Teichgraeber and Van Reenen, share ownership); revenue versus physical productivity (CMA markups); Webber and Huaccha (yoghurt chain ratios)
- [gva_sources_hmrc_productivity.md](gva_sources_hmrc_productivity.md) (this repo): how regional GVA components are allocated
