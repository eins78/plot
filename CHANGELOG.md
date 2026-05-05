# plot

## 1.2.0

### Minor Changes

- [#18](https://github.com/eins78/plot/pull/18) [`adc77c7`](https://github.com/eins78/plot/commit/adc77c782ab238822513bb5def9c3d3c0cb48c59) - Add local Kanban status board (`pnpm board`) to the plot skill

  <!--
  bumps:
    skills:
      plot: minor
  -->

## 1.0.1

### Patch Changes

- [#15](https://github.com/eins78/plot/pull/15) [`66c6d6c`](https://github.com/eins78/plot/commit/66c6d6ca6555c80c8114345a8581fb1dee689aca) - Add a narrative tutorial for new users, and clarify how Plot relates to GitHub Issues.

  `skills/plot/intro-to-using-plot.md` is a new second-person walkthrough of the lifecycle (Draft → Approved → Delivered → Released), modeled on [changesets' `intro-to-using-changesets.md`](https://github.com/changesets/changesets/blob/main/docs/intro-to-using-changesets.md). It closes the gap between the high-level `README.md` and the AI-facing reference manual in `SKILL.md`. Linked from both.

  The MANIFESTO's "Not an issue tracker" bullet is reframed to match. Previously it said GitHub Issues "overlap and conflict" with Plot. The updated wording keeps the strong stance that Plot replaces issue trackers for _planned implementation work_, while acknowledging that issues remain useful **upstream** of the workflow — as the inbox for external feedback (bug reports, user-submitted feature requests, high-level user stories or business goals) that may eventually become plans. The boundary: issues are signals; plans are commitments.

  <!--
  bumps:
    skills:
      plot: patch
  -->

## 1.0.0

### Minor Changes

- [#9](https://github.com/eins78/plot/pull/9) [`230a981`](https://github.com/eins78/plot/commit/230a98185ac5c7d0d70ee2acb9f4ea5b2d7a9ccb) - `plot-sprint`: detect false-positive completions at close. Step 2 of `/plot-sprint <slug> close` now verifies, for each `[x] [slug]` item, that the referenced plan lives in `docs/plans/delivered/` (not `active/`). If any are still in `active/` or missing, close is blocked until resolved via `/plot-deliver`, unchecking the box, or an explicit override that logs a one-liner reason in `## Notes > ### Scope Changes`. The same flag also surfaces in `/plot-sprint status` so the discrepancy is visible during routine checks. Adds a `## Common Mistakes` section. Closes the gap surfaced in [issue #2 / observation 5](https://github.com/eins78/plot/issues/2#issuecomment-4057881195).

- [#11](https://github.com/eins78/plot/pull/11) [`2da3da9`](https://github.com/eins78/plot/commit/2da3da9fde1ba95e130c49359ea54c08514ce851) - `plot-sprint`: optional PR-aware lifecycle for sprint planning.

  After the initial skeleton lands on main (unchanged), Planning-phase refinement may now optionally happen on a `sprint/<slug>` branch with a draft PR. Use a PR when multiple stakeholders need to review scope, when readiness/deferral decisions deserve their own commits, or when scope conversations benefit from inline comments.

  `/plot-sprint <slug> commit` is now PR-aware:

  - If a `sprint/<slug>` PR exists and isn't merged: bump phase to Committed on the PR branch, push, mark ready, and merge with `--merge` (planning history preserved).
  - Otherwise: direct main commit, unchanged from before.

  Default merge strategy is `--merge` (mirrors `plot-approve` for plan PRs). Squash is explicitly forbidden by default — it collapses readiness/defer/date commits into one and erases reasoning. Adds an entry in the new `## Common Mistakes` section.

  Frontmatter `compatibility:` line and intro paragraph updated to reflect the optional PR path. Closes [issue #2](https://github.com/eins78/plot/issues/2) observations 2, 3, 5, and 6 — the "Theme A: Sprint PR lifecycle" bundle from the plot-skills-improvement plan.

### Patch Changes

- [#10](https://github.com/eins78/plot/pull/10) [`c4a9b6c`](https://github.com/eins78/plot/commit/c4a9b6c47bcee44ae5d66ed28a38a5b8cdf74f71) - `plot-sprint`: make the phase-transition rule explicit, and document multiline create input.

  Renames `## Guardrail` → `## Guardrails` and adds a `### Phase Transitions` sub-section stating that the `Phase` field is updated only by named subcommands (`commit`, `start`, `close`). All other actions — opening a PR, refining items, fixing typos — leave the phase unchanged. Closes the gap behind [issue #2 / observation 1](https://github.com/eins78/plot/issues/2) where "start a PR for the sprint" was misread as `/plot-sprint <slug> start`.

  Also adds a one-paragraph note on multiline `$ARGUMENTS` to the Create step 1 (Parse Input): subsequent lines after the first become the body of `## Sprint Goal`, not the one-line headline. Closes [issue #2 / observation 4](https://github.com/eins78/plot/issues/2).

- [#13](https://github.com/eins78/plot/pull/13) [`93152ad`](https://github.com/eins78/plot/commit/93152adaf631fdc00b20d4765136ac8b987baefc) - Release pipeline cleanups:

  - **CHANGELOG.md**: rename `## 1.0.0` heading to `## 1.0.0 — Initial release (pre-changeset history)` to prevent a duplicate heading when changesets generates the real `## 1.0.0` stable-release entry in the future.
  - **ralph-plot-sprint version drift**: bump `skills/ralph-plot-sprint/SKILL.md` from `1.0.0-beta.2` → `1.0.0-beta.3` to align with the rest of the skill versions (pre-existing drift; no content change).
  - **RELEASING.md**: create release guide with a `## Downstream: plot-marketplace` section documenting the manual post-release step and open questions for the maintainer.

## 1.0.0 — Initial release (pre-changeset history)

### Features

- Add Plot skill: git-native planning workflow with hub-and-spoke architecture
- Add `plot-idea`: create plan branches with plan files and draft PRs
- Add `plot-approve`: merge approved plans and fan out implementation branches
- Add `plot-deliver`: verify implementation PRs and deliver plans
- Add `plot-release`: cut versioned releases with changelogs
- Add `plot-sprint`: time-boxed sprint management with MoSCoW prioritization
- Add `ralph-plot-sprint`: automated sprint runner with shell loop wrapper
- Add `tracer-bullets`: standalone thin-vertical-slice skill with plot integration
- Add MANIFESTO.md: founding principles and design boundaries
- Add helper scripts (`plot-pr-state.sh`, `plot-impl-status.sh`, `plot-review-status.sh`) for structured JSON output
- Add model tier guidance (Haiku/Sonnet/Opus) to all skills and scripts
- Add batch mode, automation output mode, and sprint item annotations
- Add quickstart guide and troubleshooting section
- Externalize plan, sprint, and retrospective templates
- Add review tracking with SHA comparison
- Add self-improvement rules to technical skills

### Bug Fixes

- Fix phase mismatch in `plot-approve` — update phase to Approved on main
- Fix `ralph-sprint` worktree staleness and RC re-tag detection
- Fix CSO violation handling and AUTOMERGE=false stall case in `ralph-plot-sprint`

### Refactoring

- Split plot skills into standalone repo from eins78/skills
- Rewrite CLAUDE.md as Plot-specific contributor guide
- Standardize tooling discovery format, third-person voice, and sync comments
