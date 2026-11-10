# Draft questions for MHCLG and the IoD 2025 research team

Claude Code draft, 10 November 2026, for Dan to edit and send if he wants to. Nothing has been sent.

The questions come out of the work in [imd_rank_uncertainty_research.md](imd_rank_uncertainty_research.md) and the report [docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd](../docs/chunks/imd_uncertainty/imd_uncertainty_firstlook.qmd). Each says what was found from the published files and what would help. The draft message below could go to the IoD contact address given on the statistics page, or to the research team (Deprivation.org and OCSI).

## Draft message

Subject: Questions about shrinkage and uncertainty in the English Indices of Deprivation 2025

Hello,

I'm working on how much uncertainty in the underlying data carries through to IMD 2025 ranks, using only the published files: how far apart LSOAs and local authorities need to be before their ranks can be told apart. I've been able to rebuild stages 4 to 7 of the Indices from Files 6 to 10, and to run the shrinkage step forwards and backwards for the indicators whose counts are published. A few points I can't settle from the technical report or the files, and I'd be very grateful for any help with them.

**Shrinkage and its inputs**

1. **Posterior standard errors.** For each shrunk indicator, the shrinkage step computes each LSOA's raw variance and shrinkage weight. Would it be possible to publish the resulting standard error of each published rate, rounded as the rates are? That would let users carry chance error through the whole index without any access to the underlying data.
2. **Parent groups.** Could the lookup from each LSOA to its shrinkage parent group (LSOA classification supergroup within local authority) be published, with a flag for the LSOAs that weren't shrunk because they were alone in their group?
3. **At-risk denominators.** Could the at-risk denominators for the crime and road casualty indicators, and the property counts for burglary, be published at LSOA level?
4. **Pooled or average counts.** For indicators built from several time points (the six years of recorded crime, two of anti-social behaviour, five of road casualties, and the 12 monthly Employment counts), was shrinkage applied to the average annual (or monthly) count or to the counts pooled over all the time points? The two give the same published rates but imply errors that differ by about two times. Rebuilding the 2025 Employment shrinkage from the published counts fits the average-count reading better, but the 2019 Employment rebuild fits the pooled reading.
5. **Road casualties.** Rebuilt from DfT's open STATS19 data, the published road casualty indicator matches the *unshrunk* rate closely (rank correlation about 0.98), and almost all of the LSOAs published at exactly 0 (1,274 of 1,278 in my rebuild) had no casualties at all. Shrinkage as Appendix C describes would move those LSOAs above zero. Was shrinkage applied to this indicator, as paragraph 4.9.30 says? If so, how do the zeros arise?
6. **The 2019 Employment domain.** Rebuilding the IoD 2019 shrinkage from the published 2019 counts, with local authority parents, reproduces the Income domain's pull as closely as rounding allows, but explains little of the Employment domain's. Was the 2019 Employment domain shrunk differently, for example by shrinking each benefit count separately before adding them?
7. **Standard errors for indicators that aren't proportions.** How was the variance in the shrinkage formula formed for the Key Stage 2 and 4 point scores, the age-sex standardised ratios (illness and disability, years of life lost, acute morbidity), and the property-level scores (energy performance, outdoor space)?

**Construction details**

8. **Normal scores.** Is the rank-based normal score the inverse normal of rank ÷ (N + 1), with tied values given their average rank? That formula rebuilds the published Health domain score to within its rounding.
9. **Wider barriers.** Is the wider barriers sub-domain the sum of its five items, with each composite item (housing affordability, overcrowding, homelessness) re-standardised to a normal score before it is added? That rebuilds the published sub-domain score with coefficients of 1, but the report says only "equal weights".
10. **Overcrowding.** Paragraph 4.8.13 describes ranking to normal scores and then shrinkage, but File 8 publishes overcrowding as proportions that look shrunk. Was shrinkage applied to the proportions before standardising?

**Uncertainty more generally**

11. Has any work been done, inside the project or elsewhere, on intervals for IMD ranks or decile membership that allow for data error? I couldn't find any published, and wouldn't want to duplicate it.

Many thanks,

Dan Olner

## Notes for Dan

- The figures in questions 4 to 6 and 8 to 9 come from the scripts `09`, `10` and `11` in [code/imd_uncertainty](../code/imd_uncertainty/), and are shown in the report. It's worth checking the numbers against the latest render before sending.
- Question 1 is the one that would change most for users. Questions 2 and 3 are the cheap ones to say yes to.
- Questions 5 and 6 point out possible differences between the report and the files. They're phrased as questions, since there may be an explanation I've missed.
