---
"plot": minor
---

`plot-sprint`: optional PR-aware lifecycle for sprint planning.

After the initial skeleton lands on main (unchanged), Planning-phase refinement may now optionally happen on a `sprint/<slug>` branch with a draft PR. Use a PR when multiple stakeholders need to review scope, when readiness/deferral decisions deserve their own commits, or when scope conversations benefit from inline comments.

`/plot-sprint <slug> commit` is now PR-aware:

- If a `sprint/<slug>` PR exists and isn't merged: bump phase to Committed on the PR branch, push, mark ready, and merge with `--merge` (planning history preserved).
- Otherwise: direct main commit, unchanged from before.

Default merge strategy is `--merge` (mirrors `plot-approve` for plan PRs). Squash is explicitly forbidden by default — it collapses readiness/defer/date commits into one and erases reasoning. Adds an entry in the new `## Common Mistakes` section.

Frontmatter `compatibility:` line and intro paragraph updated to reflect the optional PR path. Closes [issue #2](https://github.com/eins78/plot/issues/2) observations 2, 3, 5, and 6 — the "Theme A: Sprint PR lifecycle" bundle from the plot-skills-improvement plan.
