# Review of the IMD uncertainty first-look report, and a plan for the next round

Claude Code review note (Fable 5.2), 10 November 2026. It reviews [docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd](../docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd) and the eight scripts in [code/imd_uncertainty](../code/imd_uncertainty/), which were drafted earlier the same day with Opus 5.5. The background is in the [research note](imd_rank_uncertainty_research.md).

I read the report and every script, then ran quick checks on the points that looked doubtful. Numbers marked "my check" come from those runs. They were scratch runs and aren't saved in the repo, so each one appears in the plan as a task to redo properly.

## Short version

- **The main findings stand.** Nothing I found reverses a result. The rebuild of stages 5 to 7 is sound, and the Monte Carlo does what it says.
- **The "lower bound" is lower than it needs to be.** The Monte Carlo treats Income and Employment errors as independent, and treats people as independent draws. Both assumptions shrink the ranges. Relaxing them moves the median LSOA range from about 1,300 ranks to somewhere between 1,500 and 2,300 (my check).
- **Three statements in the text aren't supported by the analysis.** They are the reason given for intervals under-covering at small counts, the claim that wrong inputs "err on the safe side", and the attribution of the unexplained pull to the 2025 supergroups. The third can be tested with the IoD 2019 files.
- **The report treats "open data" as "what File 8 publishes".** Several indicators can be rebuilt from open source data. The clearest is road casualties: the technical report says it was built from DfT's open data, so its counts don't need reverse engineering at all.
- **Stage 4 hasn't been rebuilt, and everything else depends on it.** Until the published indicators can be turned back into the published domain scores, no indicator-level error can be carried to the IMD for the five domains held fixed so far.
- **Three quick additions are available from files already downloaded.** They are rank ranges for IDACI and IDAOPI, the extent and local concentration measures for local authorities, and formal confidence sets for local authority ranks.

## Progress, 10 November 2026 (second round, Opus 5.5)

Everything in the plan that doesn't need a GeoDS or Stat-Xplore login is done, and the report has been rewritten around it. The whole pipeline, from downloads to the rendered report, runs from `code/imd_uncertainty/00_run_all.R` (about 40 minutes from scratch; the report alone renders in under 2 minutes once the cache exists). The scratch checks in this note have been replaced by scripts in the repo.

| Plan item | Status | What it found |
|---|---|---|
| A1 Correlation and clustering (2.1, 2.2) | Done, `07` | Median LSOA range 1,306 ranks under the Indices' own model, 2,237 with the overlap correlation (median 0.62) and design effect 2; a nine-way grid in between |
| A2 Tied starting values, zero-noise test (2.11) | Done, `07`, `13`, `15` | Ranks come back exactly with no noise, apart from ranks that File 7 itself gives to two LSOAs |
| A3 Separation measure, 2,000 draws (2.4) | Done, `07` | Averaged over 21 neighbours; gaps of 350 (most deprived 10%) to 1,300 (least deprived 40%) under the own model |
| A4 Extent and local concentration (2.10) | Done, `01`, `07` | Both rebuild File 10 exactly; their ranges are 2 to 4 times wider than average score's |
| A5 IDACI, IDAOPI, domain ranks (3.2, 3.3) | Done, `13`, `07` | IDACI median range 4,066 ranks; 85% of LSOAs span two or more IDACI deciles |
| A6 Opposite cases, raw coverage (2.6, 2.7) | Done, `05` | Too-large denominators and too-fine groups understate the error by 5% to 10%; most under-coverage is there before shrinkage |
| A7 Report text (section 6) | Done | All corrections made; report also restructured |
| B1 IoD 2019 rebuild (2.5) | Done, `09` | Income supports the supergroup explanation; 2019 Employment doesn't fit, so the reading is incomplete there. Pooling test mixed |
| B2 GeoDS supergroups | Waiting for login | |
| B3 Coverage test (2.3) | Done, `14` | 89.5% coverage with the right model; 65.8% when the real error is the correlated kind and the analysis assumes the own model |
| B4 Stage 4 rebuild (3.1) | Done, `10` | Every domain rebuilds to within File 8's rounding; normal score is Φ⁻¹(rank / (N + 1)); wider barriers is a sum of re-standardised items |
| C1 Road casualties from STATS19 | Done, `11` | The published indicator matches the *unshrunk* rate; 1,274 of 1,278 published zeros had no casualties |
| C2 Crime from police.uk | Not done | The archive files are large and the categories don't match; left as a next step |
| C3 Overcrowding from Census | Done, `12` | Shrunk; medians of 17 and 27 overcrowded households, so large errors. Adult skills denominator rebuilt too |
| C4 Stat-Xplore | Waiting for login | |
| D Full Monte Carlo | Done, `15` (layers), `16` (csranks) | Median range 1,306 → 1,609 with open-data error in other domains → 2,885 with assumed errors; local authority ranges move only once shared errors are added (3 → 16 ranks) |
| E Questions for the research team | Drafted | [imd_uncertainty_questions_for_iod_team.md](imd_uncertainty_questions_for_iod_team.md), not sent |

Also found along the way: the inversion recovers the published Income, Employment, IDACI and IDAOPI counts to within rounding for 84% to 90% of LSOAs (`08`), a real-data check that this note had asked for implicitly.

A dated work log, covering decisions, dead ends and bugs as well as results, is in [docs/chunks/imd_uncertainty/imd_uncertainty_worklog.md](../docs/chunks/imd_uncertainty/imd_uncertainty_worklog.md).

## 1. What holds up

- **Stages 5 to 7.** The transform, weights, ranks and three local authority measures reproduce the published files. I read `01` closely and found nothing wrong with it (I didn't rerun it on its own).
- **Shrinkage barely moves Income and Employment.** The weights of about 0.99 and 0.98 follow directly from the size of the counts.
- **Rounding doesn't explain the pull gap.** I suspected the benchmark had missed something: File 7 gives the rates to only 3 decimal places (799 distinct Income values and 504 Employment values across 33,755 LSOAs). Adding that rounding to the benchmark moves it from 0.92 and 0.90 to 0.91 and 0.89 (my check). The observed 0.77 and 0.82 are still well short, so the report's statement is right.
- **The simulated ranks are centred properly.** The typical gap between an LSOA's median simulated rank and its published rank is 3 to 21 places, depending on the decile, against ranges hundreds of ranks wide (my check).
- **The crime inversions converge.** Every local authority group converges in `06`.

## 2. Issues with the existing analysis

They are in rough order of how much they could change a reported number.

### 2.1 Income and Employment errors are treated as independent

- **What.** `07` draws the two domains' errors separately. But the two counts share people. Most claimants counted as employment deprived are also in a benefit unit counted as income deprived. When chance adds a claimant to one count, it usually adds them to the other.
- **Why it matters.** Positively correlated errors add up in the IMD score, where independent ones partly cancel.
- **Evidence (my check, 200 draws).**

| Assumed correlation between the two errors | Median 90% range (ranks) | Most deprived 10% | Decile-1 LSOAs under 95% likely to belong |
|---|---|---|---|
| 0 (as in the report) | 1,301 | 446 | 303 |
| 0.5 | 1,538 | 529 | 361 |
| 0.8 | 1,660 | 575 | 392 |

- **What the correlation might be.** England has about 13.2 million income-deprived people and 4.8 million employment-deprived people in the published counts. If the second group sat wholly inside the first, the correlation would be about 0.6 (my rough reasoning: the square root of 4.8 ÷ 13.2).
- **Fix.** Show the range as a band across correlations of 0 to 0.8 now. Then narrow it with Stat-Xplore (section 4).

### 2.2 The error model treats people as independent draws

- **What.** The Appendix C variance is binomial. The Income count is adults and children in benefit units, so people enter and leave it a household at a time. Crime has the same problem in a different form: repeat victims, several offences per incident, and counts scaled to force totals.
- **Why it matters.** Clustered counts vary more than binomial ones. For Income the standard error could plausibly be 1.4 times larger (my rough guess, from typical benefit unit sizes).
- **Evidence (my check).** Multiplying both standard errors by √2 takes the median range from 1,301 to 1,837 ranks. With a 0.8 correlation as well it is 2,341, and 572 decile-1 LSOAs fall under 95%.
- **A point to keep.** The report's errors are still the ones the Indices' own method implies. That is worth reporting as "the Indices' own error model". It shouldn't be presented as the size of chance error without a check against data.
- **Fix.** Measure real month-to-month variation in benefit counts from Stat-Xplore, and year-to-year variation in crime counts from police.uk. Compare each with the binomial figure.

### 2.3 What the 90% range means hasn't been tested

- **What.** Each draw adds noise to the published values and re-ranks. That gives a simulation range around the published rank. Nothing shows it contains the true rank 90% of the time. Ranges built this way are known to misbehave where many units are close together, which is most of the IMD.
- **Fix.** A coverage test with a known answer. Make up true rates, draw counts, run the whole chain, and count how often the 90% range contains the true rank. Report the result by decile. If coverage is poor, widen the ranges or switch method.
- **Also.** Say plainly in the report that "lower bound" means "lower bound under the Indices' own framing of chance error".

### 2.4 The "rank gap needed" figures are noisy

- **What.** For each of 300 probe LSOAs, `07` finds the first gap in a coarse grid at which one specific partner LSOA is beaten in 95% of draws.
- **Evidence (my check).**
  - For 56% of probes, the probability of staying ahead falls at some point as the gap grows, because each gap tests a different partner with its own error.
  - 159 of the 300 answers are exactly 1,000 or 1,250, which is the grid showing through.
- **Fix.** Work from the simulated IMD scores. Take each LSOA's score standard deviation, compute the score gap needed against a typical neighbour, and convert it to ranks using the local crowding of the score scale. Or average over all pairs at each gap. Use more draws (2,000).

### 2.5 The supergroup explanation for the pull gap is untested

- **What.** The report says the unexplained part of the pull "fits the 2025 change to supergroup-within-local-authority parents". That is an inference. A different denominator, or a detail of Appendix C that I've read wrongly, would look the same.
- **Evidence (my check).** The rebuilt rate misses the published one by up to 1.0 percentage points for Income and 1.4 for Employment. Nobody has looked at which LSOAs those are.
- **Fix.**
  - Run the same rebuild on the IoD 2019. It shrank to the local authority, and (from memory, to check) its File 8 also publishes the Income and Employment numerators. If the 2019 pull correlation reaches the rounding-only benchmark, the method is read correctly and the 2025 gap is the supergroups. If it doesn't, the reading of Appendix C is off.
  - Download the GeoDS classification and rerun for 2025.
  - List the 50 worst-fitting LSOAs and look for a pattern, such as prisons, student areas, or counts above the population.

### 2.6 The reason given for under-coverage is wrong, or at best partial

- **What.** Section 3.3 says posterior intervals under-cover at small counts because "the empirical Bayes posterior ignores uncertainty in the group mean and spread".
- **Evidence (my check, from `05`'s own output).** At an expected count of 3, the plain interval with no shrinkage covers 86.6%, and the posterior one covers 84.8%. So most of the shortfall is there before shrinkage. The likelier cause is that a normal interval on the logit scale is a poor fit when counts are 0 to 5.
- **Fix.** Correct the sentence. Add `coverage_raw` to the table. Try an interval made for small counts and see if coverage recovers.

### 2.7 "Errs on the safe side" is only shown in one direction

- **What.** Section 3.5 says mistakes in the denominator or parent group "tend to overstate the error rather than hide it". The test covers a denominator that is too small and groups that are too coarse. A denominator that is too large must understate the error.
- **Fix.** Add the two opposite cases to `05` (denominator 25% too large; groups finer than the true ones). Reword to say the residents-only denominator used for crime errs on the safe side, which is the claim the evidence supports.

### 2.8 Road casualties are pushed through a model that breaks down

- **Evidence (my check).** The recovered count is below 0.5 for 22% of LSOAs under the pooled reading and 59% under the annual one. 3.8% of LSOAs have a published value of exactly zero. The logit and its variance mean little at those sizes. The script also assumes the published figure is an annual rate per 1,000, which the technical report doesn't state.
- **Fix.** Rebuild this indicator from DfT's open casualty records (section 4) and drop the inversion for it.

### 2.9 The data-access grouping overstates what inversion can reach

- **What.** The "shrunk rate published" group is 23.2% of the IMD's weight, and the report says it "can be approximated" by inversion. But energy performance and private outdoor space (4.3 points together) are property-level scores, so they have no count to recover. Adult skills (6.75 points) is a Census rate where the shrinkage weight should be close to 1, so chance error is small and Census processing error matters more.
- **Fix.** Split the group. Add a column for "open at source", as section 4 sets out.

### 2.10 The local authority check covers three measures, and the summary says more

- **What.** `01` checks average score, average rank and the proportion in the most deprived 10%. The summary bullet says "all 296 local authorities' summary measures and ranks exactly".
- **Fix.** Add extent and local concentration to `lad_summaries()`, check them against File 10, and carry them through `07`. Extent is widely used and depends on thresholds, so it should be among the less stable. Until then, reword the bullet.

### 2.11 Smaller points

- **Ties in the starting values.** Because the published rates have 3 decimal places, the Monte Carlo with zero noise doesn't return the published ranks. Tie-breaking alone gives a median range of 41 ranks (my check). That is small beside 1,300, but a zero-noise run should return the published ranks exactly. Spread each group of tied rates across its rounding interval in the order of the published domain rank, and add the zero-noise run as a test.
- **Two confidence levels.** `02` uses 95% intervals and `07` uses 90% ranges. Pick one, or drop `02`'s table from the story now `07` exists.
- **Convergence isn't reported.** In `05`, 99.1% and 99.2% of groups converge in two of the "everything known" cases. Show the column.
- **Unused output.** `04` computes `w_implied` and never uses it. Use it or remove it.
- **Draws.** 500 draws gives usable medians. The 5% and 95% points, and any "95% of draws" test, need more.
- **Suppressed counts.** `07` assumes a count of 5 for the handful of suppressed LSOAs. Fine for the main domains, but IDACI and IDAOPI have over 800 suppressed LSOAs each (section 3.2).

## 3. Analysis that's missing

### 3.1 Rebuild stage 4 from File 8

This is the main gap. File 8 publishes every indicator for Crime, Health, Barriers and Living Environment, and the technical report gives the weights. File 7 publishes the sub-domain scores. So for each domain:

1. Turn each published indicator into a normal score from its rank.
2. Apply the published weights.
3. Compare with the published domain or sub-domain score.

What this would settle:

- whether indicator-level errors can be carried to the IMD at all, and how exactly;
- the formula used for normal scores;
- several open questions in section 3.7 of the research note, by trying both versions and seeing which matches (for example, whether composite items are re-standardised);
- how much the rounding of published indicators (crime rates to 1 decimal place) limits the rebuild.

Education can only be rebuilt from its two sub-domain scores, since the pupil indicators aren't published.

### 3.2 IDACI and IDAOPI

Their numerators are in File 8, their denominators in File 6 and their rates in File 7. Nothing new needs downloading.

- The counts are much smaller than the Income domain's: a median of 85 for IDACI and 60 for IDAOPI, against 310 (my check). The rank ranges will be much wider.
- 815 and 832 LSOAs are suppressed, so the suppression rule needs proper handling here.
- IDACI is used outside the Indices, including in school funding (to check which edition and which bands are in current use). That makes it a good policy example.

### 3.3 Rank ranges for the Income and Employment domains themselves

The domain ranks are published and used on their own. `07` already computes them inside each draw and throws them away.

### 3.4 Outputs people can use

- A file with one row per LSOA: published rank, range, and the probability of being in each decile.
- For any two areas, the share of draws in which one outranks the other.
- A worked example for one local authority, with a map or a ranked chart of its LSOAs.

### 3.5 Formal confidence sets for local authorities

The `csranks` package is practical at 296 authorities (research note section 7.2). It needs the covariance of the summary measures, which the draws supply. It answers "which authorities could be the most deprived?" with a stated error rate. Check first that using a simulated covariance this way is sound.

### 3.6 Already listed in the report, still needed

Shared errors (denominators, police force recording, local-authority-level indicators), assumed errors for modelled indicators, and method choices as a separate layer.

## 4. Extra data

"Open" means free to download. Items marked "to check" are from memory and I haven't confirmed them.

| Data | What it's for | Access |
|---|---|---|
| IoD 2019 Files 6, 7 and 8 | Tests the shrinkage rebuild where the parent group is known (2.5) | Open (to check that File 8 has the numerators) |
| GeoDS 2021/2 LSOA classification | The 2025 shrinkage parent groups (2.5) | Open licence, needs a free login |
| DfT road safety open data (STATS19), 2019 to 2023 | Rebuilds road casualty counts directly, with severity adjustment (2.8). The technical report (4.9.26) says this is the source used | Open |
| DWP Stat-Xplore, LSOA benefit counts by month | Real variation over time against binomial (2.2); overlap between the Income and Employment counts (2.1); a rough rebuild of the illness and disability ratio | Open, free API key (LSOA detail for each benefit to check) |
| police.uk archive, monthly crimes with LSOA codes | Year-by-year crime counts; real variation over time; which of the pooled and annual readings reproduces the published rates. Limits: categories don't match exactly (violence isn't split), locations are anonymised, and one large force has a long gap (to check) | Open |
| Census 2021 occupancy rating tables (rooms, bedrooms) | Overcrowding counts and denominators, so no inversion needed | Open (Nomis) |
| Census 2011 and 2021 workplace population | The non-resident part of the crime and road casualty denominators | To check what exists at LSOA level; BRES employment by LSOA is a fallback |
| ONS small area population estimates for other years | How sensitive rates are to the 2022 denominator under 2024 numerators; denominator error by type of area | Open (to check which years exist for 2021 LSOAs) |
| ONS uncertainty measures for local authority population estimates | A shared denominator error for each local authority | Open |
| Ofcom, Defra, EPC, NHS GP workforce and H-CLIC open data | The source data behind broadband, air quality, energy performance, GP ratio and homelessness. Useful for sizing error in each, later | Open (EPC needs a login) |

Still closed, as the report says: pupil data, hospital and mental health records, deaths, and the raw police records.

## 5. Plan

Each phase ends with something that can go in the report.

### Phase A: tighten what exists (no new data)

1. Add the correlation and clustering sensitivities to `07`, and report the headline as a band (2.1, 2.2).
2. Add the zero-noise test and fix the tied starting values (2.11).
3. Replace the separation measure and raise the draws to 2,000 (2.4).
4. Add extent and local concentration to `01` and `07` (2.10).
5. Add IDACI, IDAOPI and the two domain ranks (3.2, 3.3).
6. Add the opposite cases and the raw coverage column to `05` (2.6, 2.7).
7. Correct the report text (section 6).

### Phase B: test the method

1. Run the shrinkage rebuild on the IoD 2019 (2.5).
2. Rerun 2025 with the GeoDS supergroups, once downloaded.
3. Run the coverage test for the rank ranges (2.3).
4. Rebuild stage 4 for the six domains where it's possible (3.1).

### Phase C: rebuild indicators from open sources

1. Road casualties from STATS19, with an approximate workplace denominator.
2. Crime from police.uk, where categories match.
3. Overcrowding from Census tables.
4. Stat-Xplore: variation over time, the Income and Employment overlap, and the illness and disability ratio.

### Phase D: the full Monte Carlo

1. Carry every indicator that has an error estimate through stages 4 to 7.
2. Add assumed, varied errors for the rest, with shared draws where inputs are shared.
3. Add shared errors for denominators and police forces.
4. Produce the outputs in 3.4 and the confidence sets in 3.5.

### Phase E: ask the research team

Put the open questions to MHCLG and the IoD team in one message: posterior standard errors, at-risk denominators, pooled or annual crime counts, and the section 3.7 gaps in the research note. Phase B makes the questions sharper, so send it after that.

## 6. Corrections to the report text

- **Summary, first bullet.** "all 296 local authorities' summary measures" should say which three measures (2.10).
- **Summary, fourth bullet and section 3.5.** Narrow "the safe direction" to the cases tested (2.7).
- **Section 2.** Split the 23% group and stop saying all of it can be approximated by inversion (2.9). Say that road casualties come from open DfT data.
- **Section 3.2.** Call the supergroup explanation likely but untested, and name the 2019 test (2.5).
- **Section 3.3.** Replace the reason for under-coverage (2.6).
- **Section 3.4.** Flag that the road casualty figures rest on counts below 1 for many LSOAs (2.8).
- **Section 4.** State what the 90% range is and isn't (2.3). State the independence and binomial assumptions next to the headline number, with the band from 2.1 and 2.2.
- **Section 5.** Add the IoD 2019 test, the stage 4 rebuild and the open-source rebuilds to the next steps.

## 7. Decisions for Dan

1. **Logins.** GeoDS and a Stat-Xplore API key both need a free registration. Do you want to do those? The files can go in `local/imd_raw/`.
2. **Fix or supersede.** Should Phase A go into the first-look report, or into a second report that leaves the first as a dated draft? *Suggested: fix the first-look report, since the text corrections belong there.*
3. **IDACI.** Is the children's index worth a section of its own? *Suggested: yes, it's cheap and the ranges will be striking.*
4. **Headline level.** 90% or 95%? *Suggested: 90% throughout, as the research note proposed.*
5. **How to state the headline.** A single lower bound, or a band across the correlation and clustering assumptions? *Suggested: a band, with the Indices' own error model as its lower edge.*

## How the review was done

- Read the `.qmd` and all eight scripts in full.
- Reran `04`, `05`, `06` and `07` unchanged and inspected outputs the report doesn't show (convergence, raw coverage, recovered counts).
- Added one-off variations: rounding the rates to 3 decimal places in the rounding benchmark; correlated and inflated errors in the Monte Carlo (200 draws each); a zero-noise run; diagnostics on the separation measure.
- Checked the technical report text for the road casualty source and denominator (4.9.26 to 4.9.30) and the crime shrinkage steps (4.7.10 to 4.7.13).
- Didn't check: the rendered HTML's layout, anything in section 4's data table marked "to check", or the items already listed under "Things I couldn't check" in the research note.
