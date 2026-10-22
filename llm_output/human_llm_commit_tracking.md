# Tracking human and Claude work in research repos

Notes for prototyping one or two more open research builds where it's clear who, or what, wrote each part. RegEconWorks switched everything on at once. The aim here is a kit of separate pieces that can each be switched on alone.

## The pieces

| Piece | What it gives you | Status |
|---|---|---|
| Conversation export (`export_all_convos`) | Readable copies of Claude sessions, each one published only if you choose to | Exists |
| Split commits | Every commit is either yours or Claude's, so diffs and `git blame` show who wrote each line | New (below) |
| Session links | Each Claude commit names the conversation that produced it | New, small |
| Authorship report | Share of lines by you vs Claude per file, linked to conversations | New, built on the two above |
| README "LLM" note with a blame link | The plain statement readers actually see | Exists |

Each piece works without the others. Session links are only useful if you also export conversations.

## Where things stand

In RegEconWorks, every commit apart from the bots' is authored by you. The README line "Claude Code made the file, I edited" is true because you committed Claude's draft before you edited it. That's a manual step and easy to forget.

Claude Code's `Co-Authored-By: Claude` line doesn't solve this. It marks the whole commit as joint work, but `git blame` still names you as the author of every line.

## Splitting commits: commit at every handoff

The files only change hands at two moments: when you send a prompt, and when Claude finishes replying. Commit at both moments, with a different author each time. Claude Code hooks can do this automatically:

1. **When you send a prompt** (`UserPromptSubmit` hook): commit anything that changed since Claude last finished, authored as you. These are your edits.
2. **When Claude finishes its turn** (`Stop` hook): commit everything that changed, authored as Claude. These are Claude's edits.

If nothing has changed, skip the commit. The second hook comes down to one git command:

```bash
git add -A
git commit --author="Claude <noreply@anthropic.com>" \
  -m "Claude: edits in session a8a153fa" \
  --trailer "LLM-Session: a8a153fa-8c3e-4bfe-85f0-a3d1dcd3c035" \
  --trailer "LLM-Model: claude-opus-5-5"
```

Some details:

- **Author and committer.** Git records both. Claude is the author and you stay the committer, taken from your normal git config. GitHub shows "Claude authored and Dan Olner committed". That's accurate, because you accepted the change. The email is the one Claude Code already uses in its own Co-Authored-By lines.
- **Session link.** Claude Code gives each hook the session ID. That ID is also the transcript's filename, and the transcript path is already in the `Source:` line at the top of every exported `llm_convos` file. So you can find the conversation behind a commit with a text search, and the export script needs no changes.
- **Model.** The hook isn't told which model ran, but it can read the model name from the transcript.
- **Keep your prompt out of the commit message by default.** Putting it in would make the log easy to read. But commits become public when you push, and the export tool deliberately keeps conversations private until you choose to publish them. Make prompt-in-message a separate opt-in.
- **Claude shouldn't make its own commits while this is on.** If it did, they would carry your name. A line in the project's CLAUDE.md asks it not to. A hook that blocks `git commit` while tracking is on is more reliable.

## Switching it on and off

Leave the hooks in the project's `.claude/settings.json` permanently, and have each hook start by checking for a switch file, `.claude/track_authorship`. If the file isn't there, the hook does nothing and Claude Code behaves exactly as it does now.

A small script flips the switch:

```bash
scripts/authorship.sh on      # creates the switch file
scripts/authorship.sh off     # removes it
scripts/authorship.sh status
```

Why use a file instead of adding and removing the hooks? Claude Code takes a snapshot of its hook settings when a session starts, so editing hooks mid-session isn't a reliable switch. A file check takes effect from your next prompt and survives restarts, and you can see at a glance whether tracking is on.

When you switch it on, the script should first commit any uncommitted changes, asking whose they are, so the record starts clean. If tracking is a choice for this machine only, keep the switch file out of git. Commit it if you want cloud sessions to track too, since they clone from GitHub.

## Things that will trip it up

- **Editing while Claude is working.** Anything you change during Claude's turn is committed as Claude's. Wait for the turn to finish.
- **Squash merges.** Squashing merges every author's commits into one. Normal merges and rebases keep authors.
- **Generated files.** If Claude runs a script that writes data or figures, those are committed as Claude's too. Check `.gitignore` before switching on.
- **Reformatting.** Saving in the Quarto visual editor rewraps whole paragraphs, which makes you the blame author of lines Claude wrote. Commit those saves on their own and list them in `.git-blame-ignore-revs`, which GitHub's blame view respects. This only partly helps where several lines are joined into one.
- **Two sessions in one folder.** Their edits get mixed together. Give each session its own git worktree.
- **Lots of small commits.** That's the point: the history is the record. Don't tidy it away.

## What blame can and can't tell you

Blame shows who last typed a line, not whose idea it was. A line Claude wrote to your detailed spec shows as Claude's. A line you typed from Claude's suggestion shows as yours. The conversation export fills that gap, which is why the session link is worth having.

## Tools you could build on top

Once commits are split, most of these are a few lines of shell or R:

- `git log --author=Claude` and `git log --author="Dan Olner"` show each side's changes separately.
- `git blame --line-porcelain FILE | grep '^author ' | sort | uniq -c` counts lines by author for one file. Loop over files for a whole-repo table.
- `git log --format='%h %(trailers:key=LLM-Session,valueonly)'` lists each commit with its session ID, which you can match to files in `llm_convos/`.
- A Quarto page in `docs/` could show the per-file split and link each Claude commit to its published conversation, or say "not published".

## Suggested first prototype

Try it in a fresh copy of `modularproject_template` with only two pieces switched on: split commits and the conversation export. Do a week of normal work, then read through `git log` and GitHub's blame view. If they give an honest picture of who did what, add the pieces to the template.
