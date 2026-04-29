# Plot Skills Improvement Plan from Issue #2

**Date:** 2026-04-29
**Source:** Claude Code (worktree `worktree-plot-skills-review`, branch pushed to origin)
**Triggering issue:** [eins78/plot#2](https://github.com/eins78/plot/issues/2) — "plot-sprint: trial run notes"

## Summary

Audited the eight feedback items in plot issue #2 (one issue body with 4 numbered observations + three follow-up comments, each with its own restarted "### 5" / "### 6" numbering). Produced a single deliverable: `docs/plans/plot-skills-improvement.md` (440 lines) — a structured improvement plan with concrete before/after edits, cross-cutting themes, priority ordering, and an explicit "already addressed" subsection. No skill files were modified — the deliverable is plan-only, per the task brief.

## What I read

- `gh issue view 2 --repo eins78/plot --comments` (full body + three comments, no truncation)
- Cross-referenced PRs/issues: `eins78/qubert#28` (sprint planning PR), `eins78/qubert#42` (BDD-first enforcement PR), `eins78/skills#4` (referenced as cross-ref but private/404)
- `skills/plot-sprint/SKILL.md` (full)
- `skills/ralph-plot-sprint/SKILL.md` (full)
- `skills/ralph-plot-sprint/ralph-sprint.sh` (full)
- `skills/plot-deliver/SKILL.md` (full)
- `skills/plot-approve/SKILL.md` (full)
- `skills/plot/SKILL.md` (full)
- `skills/plot/MANIFESTO.md` (full)
- `skills/plot-idea/SKILL.md` (partial — confirmed not impacted by issue)
- `skills/plot/templates/sprint.md` (full)

## What I proposed

Eight items, indexed sequentially in the plan with their original source noted:

| # | Source | Skill | Priority |
|---|--------|-------|----------|
| 1 | issue body | `plot-sprint` | **Now** — explicit phase-transition rule |
| 2 | issue body | `plot-sprint` | Soon — sprint PR lifecycle (bundle) |
| 3 | issue body | `plot-sprint` | Soon — sprint PR lifecycle (bundle) |
| 4 | issue body | `plot-sprint` | Later — multiline slug parse doc |
| 5 | comment 2026-02-14 | `plot-sprint` | Soon — `--merge` not `--squash` for sprint PRs |
| 6 | comment 2026-02-14 | `plot-sprint` | Soon — PR-aware `commit` subcommand |
| 7 | comment 2026-03-01 | `ralph-plot-sprint` | **Already addressed** in current SKILL |
| 8 | comment 2026-03-02 | `plot-sprint` | **Now** — false-positive completeness check |

Three cross-cutting themes were surfaced as their own sections:

- **Theme A: Sprint PR lifecycle** — items 1, 2, 3, 5, 6 should ship as one PR; piecemeal landing leaves the skill in an inconsistent intermediate state.
- **Theme B: Checked checkbox ≠ delivered** — `plot-deliver` already has hard delivery gates; the same discipline should apply at sprint close (item 8).
- **Theme C: Phase transitions live in named subcommands** — directly reinforces manifesto Principle 7.

Concrete before/after edits with file:line citations were given for each actionable item. The plan also calls out exactly what was *not* changed and why.

## Decisions

- **No skill edits** — task is plan-only, per brief. All proposed code changes are quoted as before/after blocks in the plan, not applied.
- **Item 7 logged as "Already addressed"** rather than padded into the actionable list. The DoD Compliance Checklist now in `ralph-plot-sprint/SKILL.md:30-53,232-240` covers exactly what the original comment requested (BDD-first as a hard step in the implementation sequence). Recommendation: post a follow-up comment on issue #2 with line citations.
- **Bundle items 2/3/5/6 into one PR**, not four — they form Theme A and have shared shape. Splitting them creates worse confusion than landing none of them.
- **Item 8's gate is a hard stop with safety valve** — "do NOT proceed to close" with three options (run `/plot-deliver`, uncheck, or override-with-reason). The override-with-reason mirrors the existing scope-change log convention in the sprint file's `## Notes` section.

## Open questions

These were flagged in the plan; the user can resolve before implementation:

- **Branch prefix for sprint refinement PRs:** proposed `sprint/<slug>` — should it instead be `idea/sprint-<slug>` to reuse the `idea/` prefix? Recommendation: `sprint/`, as it parallels `feature/`, `bug/`, etc.
- **Item 8 override mechanism:** simple `AskUserQuestion` confirmation, or require a written `## Notes` entry explaining why the discrepancy was accepted? Recommendation: written entry — leaves an audit trail consistent with scope-change logging.
- **Item 7 follow-up:** should the BDD checklist comment be posted by Max himself or by an agent? Either works; the plan flags it as worth doing for audit-trail clarity.
- **Multiline goal context (item 4) destination:** proposed treating subsequent lines as the body of the `## Sprint Goal` section. Could alternatively be dropped into a `## Notes` block. The proposal picks the more useful default but isn't strongly opinionated.

## Pushed branch / deliverable

- Branch: `worktree-plot-skills-review`
- File: `docs/plans/plot-skills-improvement.md`
- URL: <https://github.com/eins78/plot/tree/worktree-plot-skills-review/docs/plans/plot-skills-improvement.md>
- Commit: `3bd8ddc — Add plot skills improvement plan from issue #2 feedback`

No PR was opened (per task brief).
