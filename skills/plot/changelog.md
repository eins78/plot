# Plot Changelog

Complete evolution history of the Plot workflow system.

**Date:** 2026-02-07 (all sessions)
**Source project:** Private project (Slack bot running Claude Code sessions)
**Sessions:** 5 Claude Code sessions
**Key PRs:** #1 (workflow setup), #8 (plot v1), #9/#11/#12 (test-plot v1), #16 (plot v2), #17/#18 (test-plot v2)

---

## Session 1 — GitHub Workflow Setup

**Session ID:** b65c7972
**Commit:** `1b8371b`

Started from the user's question: "I like to have several ideas at once planned and implemented after refinement. I also want to read those plans as formatted text."

The user proposed using draft PRs with plan markdown files on branches instead of GitHub Issues.

### Created

- GitHub Projects v2 board with 3-column Kanban (Todo / In Progress / Done)
- `/idea` slash command — bootstraps new ideas (branch + plan file + draft PR + board entry)
- `.github/pull_request_template.md` — PR template for ready-for-review PRs
- Repo config: auto-delete branches on merge, squash merge enabled

### Decisions

- **No GitHub Issues** — draft PRs are the single unit of work
- **Plan files at `docs/plans/<slug>.md`** — on feature branches
- **Branch naming:** `idea/<slug>`
- **Board columns:** kept GitHub defaults (Todo / In Progress / Done)
- **Board automations:** defaults enabled, auto-archive set to 1 month

---

## Session 2 — Plot Redesign

**Session ID:** 9e498b8f
**Commits:** `7596ff7`, `be94bef` (merged as PR #8)

User identified a critical flaw in the Session 1 approach: "We can't merge the idea until it's fully implemented. That makes it harder to track planned work and how it fits together."

### Three Options Evaluated

- **A) Create issues after all** — rejected (too much ceremony, everything starts in Claude Code)
- **B) Prepare implementation draft PRs as soon as plan is approved (merged)** — chosen
- **C) Keep current approach with labels** — rejected (doesn't solve the merge timing problem)

User chose B as most elegant: "An idea could also spawn multiple draft PRs if parallel work is possible. This keeps most of the actual planning in plain git and the board is just a PR viewer."

### Key Design Decisions

- **Three commands with a common prefix** — needed a name for the system. Settled on "Plot" for the lean git-focused planning mode.
- **Branch prefixes** — `idea/` for plans, `feature/`, `bug/`, `docs/`, `infra/` for implementation.
- **Plan must list branches** — the `## Branches` section is parsed by `/plot-approve` to create implementation PRs automatically.
- **Ship, not archive** — user: "archive is a side effect. Should happen when stable version with feature is released, or in the case of infra, docs etc tasks whenever they are merged to main. In essence an idea is delivered once it's live."

### Created

- `.claude/commands/plot-idea.md` — create plan (renamed from `/idea`)
- `.claude/commands/plot-approve.md` — merge plan, fan out impl PRs
- `.claude/commands/plot-ship.md` — verify all merged, archive plan

---

## Session 3 — End-to-End Test v1

**Session ID:** 507ecfe3
**Commits:** `2480a51`, `00ba65c`, `69a4d1a`
**Test PRs:** #9 (plan), #11 (re-test plan), #12 (impl)

Ran the full lifecycle as a push test (`test-plot`). Found and fixed four issues:

### Fix 1: Meaningful First Commit on Impl Branches

**Problem:** `gh pr create` fails with "No commits between main and branch" because `/plot-approve` pushed empty branches.

**Solution:** Instead of `--allow-empty`, the approve step updates the plan file on each impl branch:
- Phase change: `Plan` to `Implementation`
- New `## Approval` section with timestamp, approver, and assignee (from `gh api user`)
- `--assignee @me` on the draft PR

### Fix 2: Dated Archive Filenames

**Problem:** `docs/archive/<slug>.md` gives no indication of when an idea shipped.

**Solution:** Archive files use `docs/archive/YYYY-MM-DD-<slug>.md`. The ship command uses `date -u +%Y-%m-%d` at archive time.

### Fix 3: Graceful Input Handling

**Problem:** Running a plot command without arguments gave no guidance.

**Solution:** All three commands handle missing/invalid input:
- `/plot-idea` — proposes from conversation context if obvious, otherwise explains the expected format
- `/plot-approve` — lists open `idea/*` PRs, proposes if only one exists
- `/plot-ship` — lists active plans in `docs/plans/`, proposes if only one exists

### Fix 4: Draft PR Merge Handling

**Problem:** `gh pr merge` fails on draft PRs. During the test, we had to manually run `gh pr ready` before merging.

**Solution:** `/plot-ship` now detects open draft PRs and offers to mark them ready and merge, rather than just failing.

### Test Lifecycle

```
/plot-idea test-plot: Test the full plot workflow end-to-end
  -> idea/test-plot branch, docs/plans/test-plot.md, PR #9

Refined plan with concrete branches and success criteria

/plot-approve test-plot
  -> Merged PR #9 to main
  -> Created feature/test-plot with approval metadata commit
  -> Draft PR #12, assigned to eins78

gh pr ready 12 && gh pr merge 12 --squash --delete-branch
  -> Impl PR merged

/plot-ship test-plot
  -> Verified PR #12 merged
  -> Archived to docs/archive/2026-02-07-test-plot.md
```

---

## Session 4 — Plot v2 Refactoring

**Commits:** `b96f4b9`, `06994ae`, `57dc630` (merged as PR #16)

Major refactoring that evolved Plot from 3 commands to a 5-skill system with lifecycle phases.

### Structural Changes

- **Migrated from `.claude/commands/` to `.claude/skills/`** — skills format with `SKILL.md` in named directories, enabling the skills CLI
- **Each command becomes its own skill directory** — `plot/`, `plot-idea/`, `plot-approve/`, `plot-deliver/`, `plot-release/`

### New Commands

- **`/plot` (Smart Dispatcher)** — analyzes current git state (branch, open PRs, active plans) and suggests the next action. Includes a Mermaid decision tree diagram. Detects orphan branches, phase mismatches, and stale drafts.

- **`/plot-release [version|major|minor|patch]`** — cuts versioned releases from delivered plans. Collects `## Changelog` entries from archived plans, composes `CHANGELOG.md`, bumps `package.json` version, creates annotated git tag.

### Renamed Command

- **`/plot-ship` renamed to `/plot-deliver`** — "ship" implied the final act, but for features/bugs a release step follows. "Deliver" means implementation is complete and verified; "release" means it's live.

### Lifecycle Phases

Added a 4-phase lifecycle tracked in the plan file's `## Status` section:

| Phase | Meaning | Trigger |
|-------|---------|---------|
| Draft | Plan being written/refined | `/plot-idea` |
| Approved | Plan merged, impl branches created | `/plot-approve` |
| Delivered | All impl PRs merged, plan archived | `/plot-deliver` |
| Released | Included in a versioned release | `/plot-release` |

### Plan Template Additions

- **`## Changelog` section** — release note entry written during planning, refined during implementation. Collected by `/plot-release` for `CHANGELOG.md`.
- **`## Type` field** — `feature | bug | docs | infra`. Determines lifecycle path (features/bugs get full lifecycle; docs/infra are live when merged).

### Infrastructure

- **Helper scripts** — `plot-pr-state.sh` (query plan PR state) and `plot-impl-status.sh` (query impl PR states). Used by dispatcher and deliver commands.
- **Mermaid lifecycle diagrams** — added to CLAUDE.md for visual reference. Three diagrams: feature/bug lifecycle, docs/infra lifecycle, dispatcher decision tree.

### Guardrails

- `/plot-approve` requires plan PR to be non-draft or already merged — no approving unreviewed plans
- `/plot-deliver` requires all impl PRs merged — no premature delivery
- `/plot-release` requires delivered (archived) plans — cannot release undelivered work
- `/plot` detects orphan impl branches — prevents coding without context
- Phase field is machine-readable — every command checks current phase before acting

### Setup Section

All skills now include a `## Setup` section pointing to the `## Plot Config` block that adopting projects add to their `CLAUDE.md`. Project board name is read from config (optional).

---

## Session 5 — End-to-End Test v2

**Commits:** `a3851b6` through `31fbba9`
**Test PRs:** #17 (plan), #18 (impl)
**Release:** v0.1.1

Ran the full 4-phase lifecycle to verify the v2 refactoring: Draft through Released.

### Test Lifecycle

```
/plot-idea test-v2: Test Plot v2 lifecycle
  -> idea/test-v2 branch, PR #17 (draft)
  -> Marked ready, approved

/plot-approve test-v2
  -> Merged PR #17 to main
  -> Created feature/test-v2 with approval metadata
  -> Draft PR #18

Trivial change on feature/test-v2, merged PR #18

/plot-deliver test-v2
  -> Verified PR #18 merged
  -> Archived to docs/archive/2026-02-07-test-v2.md

/plot-release patch
  -> v0.1.1, CHANGELOG.md updated, tag created
```

### Fixes Applied

- **`plot-impl-status.sh`** — reads plan from `origin/main` (not CWD). On impl branches the local copy is stale; it lacks the `-> #N` annotations that `/plot-approve` adds to main after creating impl PRs.
- **Release tag creation** — repository requires annotated tags (`git tag -a -m`), not lightweight tags.

---

## Design Decisions Summary

| Decision | Rationale |
|----------|-----------|
| Commands not code | Markdown instructions adapt to edge cases; shell scripts fail on unexpected state |
| Plans merge before implementation | All impl branches reference a stable document on main |
| One plan, many branches | Enables parallel work by different team members or agents |
| No GitHub Issues | Everything starts in Claude Code; PRs are the tracking mechanism |
| Board is just a PR viewer | Minimal ceremony; GitHub Projects reflects PR state automatically |
| Approval metadata on branches | Meaningful first commit + traceability (timestamp, approver, assignee) |
| Dated archive filenames | `YYYY-MM-DD-slug.md` — chronological sorting, instant shipping date |
| Smart defaults | Discover context rather than demanding exact input |
| Phase guardrails | Prevent common workflow errors at the command level |
| Draft → ready → approved flow | Plan PRs start as drafts (being refined), go through review before approval |
| Deliver vs release | Deliver = implementation complete; release = live with version tag |
| Changelog in plan | Release notes written during planning, refined during implementation |

---

## Migration to Standalone Skill

**Date:** 2026-02-07
**Source:** `.claude/skills/plot*` in originating project
**Target:** `skills/plot/` in the skills repo

### Structural Changes

In the originating project, each command was its own skill directory (`plot/`, `plot-idea/`, `plot-approve/`, `plot-deliver/`, `plot-release/`). In the skills repo, consolidated into a single `plot/` skill with hub-and-spoke structure:

- `SKILL.md` — hub with YAML frontmatter, lifecycle diagrams, dispatcher instructions
- `plot-idea.md`, `plot-approve.md`, `plot-deliver.md`, `plot-release.md` — spoke files
- `scripts/` — helper scripts

### Generalization

- Stripped duplicate `## Setup` sections from spokes (now in hub only)
- Updated script paths from `.claude/skills/plot/scripts/` to `./scripts/`
- All project-specific references were already eliminated in the v2 refactoring (project board name comes from `## Plot Config` in adopting project's CLAUDE.md)
