# Updating CRediT for Open, Inclusive Research: Options and Approaches

*Claude-code-drafted markdown. Prompts used:

- "Consider the CRediT author contribution system some are using in academia - link here. In @llm_output/howtoupdate_authorcredit.md please add your response in markdown. What are a range of options (having searched and considered sources, please supply embedded links) for updating the credit author list and approach if we're trying to make more open research that can include feedback and input from anyone, including civil service, public sector etc? Here's the article: https://authorservices.wiley.com/author-resources/Journal-Authors/open-access/credit.html"
- "Add a section at the end of @llm_output/howtoupdate_authorcredit.md that compares the CRediT author categories and the list of contibutor bot emojis. Which ones closely align, which are missing from the other? https://allcontributors.org/emoji-key/"
- "Question about the All Contributors model. You mention it's possible to make a bespoke version of that. How? And also: is it possible for me to add contributors if they don't have a github account (with a holding contributer name and contribution that I've added?)" + "add to markdown"*

----------

## The Problem

The [CRediT (Contributor Roles Taxonomy)](https://authorservices.wiley.com/author-resources/Journal-Authors/open-access/credit.html) system provides 14 well-defined roles for recognising contributions to research outputs. However, as [currently implemented by most publishers](https://en.wikipedia.org/wiki/Contributor_Roles_Taxonomy), CRediT is limited to authors named on the byline of a scholarly article. Non-author contributions -- from civil servants providing domain knowledge, public sector practitioners shaping research questions, or community members participating in data collection -- typically fall outside its scope. If we want genuinely open research that values input from anyone, we need to think about how to extend or complement this system.

## Option 1: Extend CRediT's Existing Roles More Broadly

The [NISO CRediT Standing Committee](https://credit.niso.org/) has been established to consider how CRediT can be "further developed and expanded to support contributions in a wider range of subject areas." The 14 roles are already broad enough to capture many non-academic contributions:

- **Conceptualization** could include a civil servant who helped frame the research question based on policy need
- **Data Curation** could include a local authority analyst who cleaned and prepared administrative datasets
- **Resources** could include a public body that provided access to data or infrastructure
- **Validation** could include practitioners who checked whether findings matched on-the-ground reality
- **Writing -- Review & Editing** could include anyone who gave substantive feedback on drafts

The simplest option is to use [CRediT's existing role descriptors](https://credit.niso.org/contributor-roles-defined/) and apply them to *all* contributors regardless of sector, listing non-academic contributors on the byline alongside academics. CRediT already allows for indicating degree of contribution (lead, equal, or supporting), which helps calibrate recognition without gatekeeping.

**Pros:** Uses established infrastructure; no new system to learn; increasingly recognised by publishers.
**Cons:** Some publishers still tie CRediT to traditional authorship criteria; may require negotiation with journals; the 14 categories may not capture all forms of non-academic contribution (e.g. political facilitation, community trust-building).

## Option 2: Adopt the "All Contributors" Model from Open Source

The [All Contributors specification](https://allcontributors.org/) emerged from open-source software culture with the principle: "recognise all contributors, not just the ones who push code." It provides a much broader set of contribution categories including design, documentation, event organising, financial support, ideas, mentoring, project management, answering questions, reviewing, talks, translation, testing, tutorials, and user testing -- among others.

For a research project hosted on GitHub or a similar platform, All Contributors can sit alongside or replace a traditional author list. Contributors are listed with emoji-coded role indicators, and the [All Contributors bot](https://github.com/all-contributors/allcontributors.org) can automate recognition.

**Pros:** Very inclusive by design; low barrier to recognition; fits naturally with open-source research workflows; easy to add new contribution types.
**Cons:** Not recognised by academic publishers; won't appear in journal metadata; may feel informal for some contributors.

## Option 3: Tiered Contribution Framework (Co-production Model)

Drawing on [research co-production literature](https://academic.oup.com/policyandsociety/article/37/3/277/6403940) and [participatory science taxonomies](https://pmc.ncbi.nlm.nih.gov/articles/PMC9034747/), a tiered model could distinguish levels of involvement:

1. **Co-creators** -- involved throughout, from problem definition to dissemination. Listed as full authors with CRediT roles.
2. **Collaborators** -- contributed substantially to specific phases (e.g. data collection, analysis, policy framing). Named contributors with specified roles.
3. **Contributors** -- provided input at specific points (e.g. feedback at a workshop, review of findings). Acknowledged by name with contribution described.
4. **Community/Institutional acknowledgements** -- organisations or groups that enabled the work (e.g. a local authority that provided data access, a community group that facilitated engagement).

This mirrors the [citizen science participation taxonomies](https://pmc.ncbi.nlm.nih.gov/articles/PMC9236874/) that distinguish between *contributory*, *collaborative*, and *co-created* research. It also aligns with [the practice guide on co-production between academics and NGOs](https://researchonline.lshtm.ac.uk/id/eprint/4660547/1/Lokot_Wake_2021_Co-production_Practice_Guide.pdf), which emphasises that both researchers and practitioners need recognition structures that reflect the reality of collaborative work.

**Pros:** Flexible; can accommodate very different levels of involvement; respects the norms of different sectors.
**Cons:** Requires agreement on tier boundaries; risks recreating hierarchies if not handled carefully.

## Option 4: Align with the UNESCO Open Science Recommendation

The [UNESCO Recommendation on Open Science](https://www.unesco.org/en/open-science/about) (2021, adopted by 194 countries) explicitly calls for:

- "Designing models that allow co-production of knowledge with multiple actors"
- "Establishing guidelines to ensure the recognition of non-scientific collaborations"
- Enhancing "citizen and participatory science as integral parts of open science policies"

Using this as a framing device, a project could adopt a contribution statement that explicitly positions itself within the UNESCO framework, making the case that diverse contributor recognition is not ad hoc but part of an internationally endorsed approach to research.

**Pros:** Powerful institutional backing; aligns with funder and government open science policies; frames inclusivity as standard practice rather than exception.
**Cons:** High-level framework rather than operational specification; still needs a practical system (like CRediT or All Contributors) underneath.

## Option 5: Hybrid Approach (Recommended for Open Policy Research)

Combine elements:

1. **Use CRediT roles for all substantial contributors**, regardless of sector. List civil servants, practitioners, and community members as named contributors with roles specified. Push back on any publisher norm that restricts this to academics only.
2. **Supplement with an expanded contribution statement** that describes contributions CRediT doesn't capture well -- e.g. "facilitated access to policy networks", "provided lived experience context", "brokered institutional relationships."
3. **Host a full contributor list on the project repository** (e.g. GitHub) using the [All Contributors format](https://allcontributors.org/), which can include a broader range of contribution types and doesn't depend on publisher conventions.
4. **Frame the approach** within [UNESCO Open Science principles](https://www.unesco.org/en/legal-affairs/recommendation-open-science) and, where relevant, the [equitable open research recommendations](https://pmc.ncbi.nlm.nih.gov/articles/PMC9890123/) that emphasise stakeholder co-creation.

This gives contributors formal recognition in the academic record *and* a more granular, inclusive acknowledgement in the open project itself.

## Practical Considerations

- **Consent and attribution preferences:** Not all contributors will want to be named -- civil servants in particular may face constraints on public association with research findings. Always ask.
- **Institutional sign-off:** Some public sector organisations require approval before staff are listed as contributors to external research. Build this into your timeline.
- **Contribution agreements up front:** Agree contribution recognition early in a project, not at publication time. The [co-production quality framework](https://pmc.ncbi.nlm.nih.gov/articles/PMC10262138/) emphasises this as essential for equitable collaboration.
- **Living documents:** For ongoing or modular research, treat the contributor list as a living document that grows as new contributions are made -- another reason to maintain it in a version-controlled repository rather than only in a static publication.

## Comparison: CRediT Roles vs All Contributors Emoji Key

The [14 CRediT roles](https://credit.niso.org/contributor-roles-defined/) and the [All Contributors emoji key](https://allcontributors.org/emoji-key/) were designed for different worlds -- academic publishing and open-source software respectively. Comparing them side-by-side reveals where they overlap, and more importantly, what each system is blind to.

### Close Alignments

| CRediT Role | All Contributors Type(s) | Notes |
|---|---|---|
| **Conceptualization** | Ideas | Both cover formulating goals and planning direction |
| **Data Curation** | Data | Both cover managing, producing and maintaining datasets |
| **Formal Analysis** | Code | Partial overlap -- statistical/computational analysis maps loosely to code, but CRediT is technique-agnostic while All Contributors is code-specific |
| **Funding Acquisition** | Financial, Funding Finding | All Contributors actually splits this into two: giving money vs. finding grants -- a useful distinction CRediT lacks |
| **Methodology** | *(no direct match)* | All Contributors has no category for designing research methods or models |
| **Project Administration** | Project Management | Near-identical in intent |
| **Resources** | Infrastructure | Partial -- CRediT's "Resources" is broader (materials, reagents, computing, data access); All Contributors' "Infrastructure" is focused on build/ops/DevOps tooling |
| **Software** | Code, Tool, Plugin | All Contributors is much more granular here, distinguishing core code from tooling from plugins |
| **Supervision** | Mentoring | Partial -- CRediT's "Supervision" includes oversight and leadership responsibility; All Contributors' "Mentoring" focuses on helping individuals learn |
| **Validation** | Test, User Testing | All Contributors splits this: automated test suites vs. human user testing. CRediT treats verification of results as a single activity |
| **Visualization** | Design | Loose overlap -- CRediT means data visualisation (charts, figures); All Contributors means graphic/UI design (logos, icons, visual identity) |
| **Writing -- Original Draft** | Content, Blog | All Contributors splits written output by format (website copy, blog posts) rather than by stage (drafting vs. editing) |
| **Writing -- Review & Editing** | Review | All Contributors' "Review" is focused on pull request review (code review); CRediT means critical review of the manuscript text |
| **Investigation** | Research | Both cover conducting the core research/experimentation work |

### In CRediT but Missing from All Contributors

| CRediT Role | What's missing |
|---|---|
| **Methodology** | No category for designing the *approach* to a problem -- the experimental design, the model specification, the analytical framework. In open source, methodology is implicit in code; in research, it's a distinct intellectual contribution. |
| **Formal Analysis** | No category for applying statistical, mathematical, or computational techniques to study data. All Contributors' "Code" doesn't distinguish between writing analysis code and writing application code. |
| **Investigation** | "Research" in All Contributors covers literature review, but CRediT's "Investigation" specifically means conducting experiments, running surveys, collecting primary data -- the hands-on fieldwork. |
| **Supervision** | Mentoring is the closest match, but it lacks the authority/accountability dimension. A PhD supervisor or PI who takes responsibility for the direction and quality of the work has no clean equivalent. |

### In All Contributors but Missing from CRediT

| All Contributors Type | What's missing from CRediT |
|---|---|
| Bug reports | Reporting problems or errors -- a form of quality assurance distinct from formal validation |
| Event Organising | Organising workshops, conferences, hackathons. CRediT's "Project Administration" is close but doesn't foreground community events. |
| Promotion | Advocacy, social media, public engagement. No CRediT role for making the work visible. |
| Talks | Presenting work at conferences or public events. CRediT captures writing but not oral dissemination. |
| Translation | Translating outputs into other languages -- invisible labour that CRediT ignores entirely. |
| Tutorials | Creating educational materials that teach others to use or understand the work. |
| Community Q&A | Answering questions from users or the public. A significant form of knowledge transfer with no CRediT equivalent. |
| Audio / Video | Creating podcasts, video explainers, multimedia outputs. CRediT's "Visualization" doesn't extend to these. |
| Accessibility | Making outputs usable by people with disabilities. Not addressed by CRediT at all. |
| Security | Identifying and fixing security or privacy issues. Irrelevant for most traditional research but increasingly important for open, code-based research. |
| Business Development | Building partnerships, commercial pathways, or sustainability models. Not in CRediT's scope. |
| Platform / Porting | Making outputs work across different systems or environments. A software-specific concern with no CRediT parallel. |
| Maintenance | Ongoing upkeep after initial creation. CRediT is snapshot-oriented (contributions to *a* paper); All Contributors recognises sustained work over time. |

### What This Tells Us

The two systems reflect fundamentally different models of what a "contribution" is:

- **CRediT is research-phase oriented.** Its 14 roles map to stages of the research lifecycle: conceive, design, execute, analyse, write up, review. It assumes a bounded output (a paper) with a defined endpoint.
- **All Contributors is activity-oriented.** Its 33+ types describe *what someone did* regardless of where it fits in a lifecycle. It assumes an ongoing project with no fixed endpoint.

For open research that wants to include civil servants, public sector practitioners, and community members, the gaps in CRediT are telling. There is no role for someone who:

- Organised a stakeholder workshop (Event Organising)
- Translated findings into a language spoken by the affected community (Translation)
- Answered questions from the public about the research (Community Q&A)
- Made a presentation to a council or government body (Talks)
- Maintained a dataset or codebase long after the paper was published (Maintenance)
- Promoted the work through policy networks (Promotion)

These are exactly the contributions that non-academic collaborators often make. All Contributors captures them; CRediT does not. A hybrid approach -- CRediT for the formal record, All Contributors for the full picture -- is one way to bridge this gap, but the comparison also makes a case for expanding CRediT itself to recognise the broader ecosystem of work that open research depends on.

## Can You Customise All Contributors? Can You Add People Without GitHub Accounts?

### Custom Contribution Types

The All Contributors [specification](https://allcontributors.org/docs/en/specification) *documents* a way to define custom contribution types in the `.all-contributorsrc` config file:

```json
"types": {
  "custom": {
    "symbol": "🔭",
    "description": "A custom contribution type.",
    "link": "..."
  }
}
```

However, as discussed in [this GitHub issue](https://github.com/all-contributors/all-contributors/issues/528), **the custom contribution feature is incomplete** -- the bot doesn't actually recognise custom types via commands. A maintainer confirmed it remains unimplemented. So if you want bespoke categories (e.g. "policy input", "domain expertise", "community facilitation"), you have two practical options:

1. **Manually edit** the `.all-contributorsrc` JSON file and the generated contributor table in your README, bypassing the bot entirely. The `.all-contributorsrc` is just a JSON file in your repo; the rendered table in the README is just markdown. You can write both by hand.
2. **Fork the specification** -- it's [CC-BY licensed](https://allcontributors.org/docs/en/specification) -- and define your own contribution types for your project. Since the rendered output is just a markdown table, you control the format completely.

In practice, option 1 is the realistic one for most projects.

### Contributors Without GitHub Accounts

The bot and CLI are designed around GitHub/GitLab usernames. But the [specification itself](https://allcontributors.org/docs/en/specification) says the contributor table should include a **name**, a **profile link** (described as "chosen at project discretion"), and **contribution categories**. The profile link doesn't have to be a GitHub profile -- it could be anything, or nothing.

You can add someone without a GitHub account by **editing the `.all-contributorsrc` file directly**. Each contributor entry in that JSON file has fields like `name`, `avatar_url`, `profile`, and `contributions`. For example:

```json
{
  "name": "Jane Smith (Scottish Government)",
  "avatar_url": "",
  "profile": "https://their-org-website.gov.uk",
  "contributions": ["ideas", "data", "review"]
}
```

You then manually update the markdown table in your README to match. The bot won't manage these entries for you, but they render the same way.

### The Bottom Line

The All Contributors *tooling* is GitHub-centric, but the *specification* and the *output format* are just JSON + markdown. For a research project where contributors include civil servants and public sector people without GitHub accounts, you'd be maintaining the contributor list manually anyway -- which is fine, and arguably more appropriate than asking non-technical collaborators to create GitHub accounts just to be credited.
