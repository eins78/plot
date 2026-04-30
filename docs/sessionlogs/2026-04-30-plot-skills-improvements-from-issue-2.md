# Implement plot-skills improvements from issue #2

**Date:** 2026-04-30
**Source:** Claude Code (worktree: `.claude/worktrees/plot-skills-impl/`)
**Session:** Reconstructed from 3 compaction(s) · ~696k input / ~217k output tokens
**Plan:** `docs/plans/plot-skills-improvement.md` (on `worktree-plot-skills-review` — not on main)

## What

Executed the plot-skills-improvement plan — three PRs opened against `main` from the `plot-skills-impl` worktree:

| PR | Items | Branch |
|----|-------|--------|
| [#9](https://github.com/eins78/plot/pull/9) | **8** — close/status false-positive completeness gate | `feature/sprint-completeness-check-from-issue-2` |
| [#10](https://github.com/eins78/plot/pull/10) | **1, 4** — explicit phase-transition rule + multiline create note | `feature/explicit-phase-transition-rule-from-issue-2` |
| [#11](https://github.com/eins78/plot/pull/11) | **2, 3, 5, 6** (Theme A) — sprint PR-aware lifecycle | `feature/sprint-pr-lifecycle-from-issue-2` |

All three target `plot-sprint/SKILL.md` only. Each PR includes a changeset and a manual `1.0.0-beta.3 → 1.0.0-beta.4` bump in `package.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`.

## Plan-vs-reality delta

The plan grouped Item 4 as "Round 3: Later" and left it open whether it rides on Item 1's PR or the Theme A bundle. **Chose to bundle Item 4 with Item 1 (PR #10).** Both are pure-doc nudges in the same skill; keeping the Theme A bundle scoped to the sprint-PR lifecycle (no documentation-only riders) made it more reviewable. Flagged in the PR description as a deviation.

Everything else followed the plan as written.

## Defaults chosen for open questions

The plan flagged five open questions; defaults picked per the plan's recommendations and noted as flippable in each PR:

| Question | Default | Reasoning |
|----------|---------|-----------|
| Item 8: override-with-Notes vs `AskUserQuestion`? | Notes entry | Mirrors existing scope-change log convention (`## Notes > ### Scope Changes`) |
| Item 8: where does override entry live? | `## Notes > ### Scope Changes` | Same |
| Item 4: where does multiline context land? | `## Sprint Goal` body | Most useful default per plan |
| Theme A: branch prefix? | `sprint/<slug>` | Parallels `feature/`, `bug/` |
| Theme A: PR rider for Item 4? | PR #10 (not Theme A) | Reviewability |

## Item 7 — confirmed already addressed

Plan said "no edits needed" — `skills/ralph-plot-sprint/SKILL.md` already covers the BDD gate at lines 30–53 (DoD Compliance Checklist), 233–234 (Step 3 BDD-first), and 350 (Common Mistakes). **Did NOT post the closing comment on issue #2** — deferred to Max because GitHub comments are public/shared state.

## Known follow-ups Max needs to handle

1. **Changesets vs manual version bumps interaction.** The repo has changesets configured (`pnpm version` runs `changeset version`) but is NOT in pre-release mode (`.changeset/pre.json` absent). All three PRs both bumped versions manually (per CLAUDE.md instruction) and added changesets. When changesets runs after merge, the `minor` entry from PR #11 will likely re-bump and lose the `beta` tag (`beta.4 → 1.1.0`). Resolution paths: (a) `pnpm changeset pre enter beta` before merging, (b) drop manual bumps, (c) drop changesets and stick with manual. Worth deciding before the first merge.

2. **PR #9 ↔ PR #11 `## Common Mistakes` table conflict.** Both PRs add the section with one row each. Whichever lands second conflicts cleanly on the table — resolution is "keep both rows." Same goes for the `1.0.0-beta.3 → 1.0.0-beta.4` bumps (second-merger rebases to `beta.5`).

3. **Item 7 closing comment.** Should be posted on issue #2 once Round 1 + Round 2 land — text suggested by the plan in its "Already addressed" section.

## Repository state

- **Worktree:** `.claude/worktrees/plot-skills-impl/`
- **Branch:** `worktree-plot-skills-impl` (clean — work is on three sub-branches)
- **Sub-branches pushed:** `feature/sprint-completeness-check-from-issue-2`, `feature/explicit-phase-transition-rule-from-issue-2`, `feature/sprint-pr-lifecycle-from-issue-2`
- **PRs:** #9, #10, #11 (all open, not merged)
- **Tests:** `pnpm test` passing on each branch
