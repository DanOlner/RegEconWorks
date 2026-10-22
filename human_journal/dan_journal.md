# Thursday [[22nd-Oct-2026]]: round 2 of trying to work out who's to blame

I'm starting this after the first chunk of the project (grafting ABS uncertainty onto ONS regional GVA) [is online](https://danolner.github.io/RegEconWorks/chunks/uncertainty_in_regionalGVA/), and the second (sticking purely to ABS uncertainty) has a Claude Code draft.

I want to use this - relatively simple, small and contained -  new ABS uncertainty chunk to dig more into how we are working with agentic AI. It's not a sprawling analysis, and should lend itself to prototyping. Specifically I'm asking:

- How to build robust analysis with agentic AI that can be trusted. That isn't just "human in the loop" work, though that's part of it. It's about figuring out, in a very granular/modular way, how to build processes that - as much as possible - reduce the odds of error. We can come back to comparing to other distributed error-correction systems like peer review which, of course, agentic AI is scrambling as well, partly through simple DOS-level text overwhelm. (I'm nabbing many ideas from superbrain [Jon Minton](https://www.linkedin.com/in/jon-minton-09480b13a/), in his [new company guise](https://ktandb.co.uk), here.)
- How to make the human / LLM work division as legible and transparent as possible (using the kind of tracking that github makes relatively painless). That's continuing trying to be as transparent as possible about LLM use in a project ([here's the LLM convo](https://github.com/DanOlner/RegEconWorks/blob/master/llm_convos/2026-10-19_1322_Coming_back_to_this_after_a.md) that built the first ABS uncertainty attempt, for example).
- Increase my own understanding of what meatsack-me is good for, what the machine is good for.

That last point: for those of us who've been immersed in this slightly terrifying new agentic AI world, our work has been turned pretty intensely upside-down and shaken by its legs. As I work on actually prototyping here, I'm hoping it'll become both easier to see:

- Why it's so transformative, and 
- How we can, bit by bit, feel our way to ethical, transparent, human-curiosity-centric ways of working with the machines.

First up is cleanly separating my words from Claude Code's (my LLM poison of choice). There's this journal, but github diffs will/should allow a very clear view of who's added or changed what. 

I'll run through all setup for that on the desktop side too, where the git commits need to be clearly from me or CC for this to work.
