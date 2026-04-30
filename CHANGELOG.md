# plot

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
