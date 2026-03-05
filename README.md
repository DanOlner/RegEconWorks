# RegEconWorks
<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->
[![All Contributors](https://img.shields.io/badge/all_contributors-1-orange.svg?style=flat-square)](#contributors-)
<!-- ALL-CONTRIBUTORS-BADGE:END -->

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.XXXXXXX.svg)](https://doi.org/10.5281/zenodo.XXXXXXX)

**RegEconWorks** is a **modular research repository** (prototype) focused on thinking through some key regional economic ideas for UK regional policy.

- **Modular research repo?** Yup - the idea is to produce smaller, self-contained **chunks** of work (e.g. [this](https://danolner.github.io/RegEconWorks/chunks/uncertainty_in_regionalGVA/), written in the [](docs/chunks/) folder) that are *smaller than pre-prints* (those are [meant to be](https://www.ntu.ac.uk/media/documents/library/preprints_faq.pdf) "a complete (full draft version) manuscript shared with a public audience without peer review"). The idea: increase the granularity of open feedback opportunities, but have something chunky enough to have its own DOI, so there's a permanent record.
- **Err. Why?** To try and increase the odds of conversations/work across institutional boundaries, while keeping it reproducible, iterative and able to acknowledge contributions from *any source*. (See the [feedback doc here](FEEDBACK.md) for ways to input - any feedback, however big or small, will end up below in the contributor list). Hopefully it can grow into other, larger work (including academic papers if that's useful), but chunks don't need to.

A couple of other goals:

- Make explicit where LLM output has been used in words and code. That includes back-and-forths with any LLM being used for the project locally (see the [](llm_convos/) folder).
- Make sure everyone who contributes (inside and outside academia) is acknowledged.


## What's in this repo?

What's here so far, and the roadmap for things to add (which will update and change as the direction of travel changes).

- [ ] Paper 1: Why introducing uncertainty into regional GVA is a good thing and what it means for industrial policy.
  - [x] Chunk 1: Applying Annual Business Survey uncertainty data to regional GVA and looking at the results; asking some questions about implications; discussing a top Lost Boys scene that helps with type I / II errors. Online draft [here](https://danolner.github.io/RegEconWorks/chunks/uncertainty_in_regionalGVA/), made in [this folder](docs/chunks/).
  - [ ] Chunk 2 (not started): What chunk 1 - trying to separate economic signal and noise - might imply for regional decionmaking. Chunk 1 discusses this a bit in its closing section.

## Other national-accounts related chunks that may be useful:

- [ ] Public sector output: understanding the potential impact of lack of actual productivity measures on regional output
- [ ] Imputed rent: necessary for comparative national accounts, what effect on measures of regional output? (It's left out of some productivity measures but not all).
- [ ] Tradeable vs foundational, how to think about difference given the above (also ties to other work on intermediate region trade flows).
- [ ] Wild deflators: what changes in telecomes does to regional productivity, implications.
- [ ] Reflections on national accounts: can we have both worlds, top down accounting certainty and bottom-up data uncertainty?


## How to Cite

If you use this software or analysis, please cite it via the DOI above or see the [CITATION.cff](CITATION.cff) file.


## How to Give Feedback

See the [feedback doc here](FEEDBACK.md) for ways to input/comment - any feedback, however big or small, will end up below in the contributor list.

## Related links

- **Blog**: [coveredinbees.org](https://coveredinbees.org/)
- **Exobrain**: [exobrain.coveredinbees.org](https://exobrain.coveredinbees.org/)
- **Working papers**: See [papers/](papers/) folder - none completed

## Licence

- **Code**: [MIT](LICENSE)
- **Text/narrative**: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- **Data**: See [data/README.md](data/README.md) for data-specific terms

## Reproducibility

This project uses [`renv`](https://rstudio.github.io/renv/) to lock R package versions. After cloning, run:

```r
renv::restore()
```

You may need to make sure you're running the approriate R version.

## LLM

*This is a human/LLM smush. Initial draft by Claude Code, additions by me. See [blame here](https://github.com/DanOlner/RegEconWorks/blame/master/README.md) for who did what (Claude Code made the file, I edited).*

## Contributors

Via the [All Contributors bot](https://allcontributors.org) and manual addition to the list for people without github accounts.
<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="http://danolner.net"><img src="https://avatars.githubusercontent.com/u/5830743?v=4?s=100" width="100px;" alt="Dan Olner"/><br /><sub><b>Dan Olner</b></sub></a><br /><a href="#design-DanOlner" title="Design">🎨</a> <a href="https://github.com/DanOlner/RegEconWorks/commits?author=DanOlner" title="Code">💻</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->