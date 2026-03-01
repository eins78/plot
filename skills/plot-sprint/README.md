# plot-sprint

Sprint management for the Plot planning system.

## Purpose

Adds time-boxed coordination to Plot. Sprints group work by schedule (start date, end date, MoSCoW priorities) while plans group work by scope. Sprint files live in `docs/sprints/` and are committed directly to main — no PR workflow.

## Structure

```
skills/plot-sprint/
├── SKILL.md    # Sprint lifecycle: create, commit, start, close, status
└── README.md   # This file
```

> **Automated runner:** `ralph-sprint.sh` and the `/ralph-plot-sprint` iteration skill have moved to [`skills/ralph-plot-sprint/`](../ralph-plot-sprint/). Install from there.

## Tier

Reusable/publishable. Project-agnostic — works with any repo that adopts Plot conventions.

## Testing

E2E test scenario:

```
Test scenario: test-sprint
1. /plot-sprint week-1: Ship authentication improvements
2. Add items: 1 plan-backed [slug] reference + 2 lightweight tasks across MoSCoW tiers
3. /plot-sprint commit week-1 — verify end date required
4. /plot-sprint start week-1 — verify active/ symlink created
5. Complete one must-have, leave one should-have incomplete
6. /plot-sprint close week-1 — verify MoSCoW completeness check, deferred handling
7. Verify retrospective prompting works
8. Run /plot on main — verify sprint appears with countdown/progress
9. Verify plan-backed [slug] cross-references resolve correctly
10. Verify active/ symlink removed on close
```

Spoke awareness tests:
- Run a plan lifecycle with `Sprint: week-1` field populated
- Verify `/plot-approve` mentions sprint membership
- Verify `/plot-deliver` shows sprint progress

## Provenance

Designed as part of the sprint support plan (`docs/plans/2026-02-11-plot-sprint-support.md`). Key design decisions:
- Dedicated command rather than conditional paths in existing spokes
- Direct-to-main commits (sprints are coordination artifacts, not implementation plans)
- MoSCoW priority tiers with adaptation-not-deletion principle
- Single `active/` symlink directory (no `closed/` — identified by Phase field)

## Known Gaps

- No cross-sprint item tracking (items can't span multiple sprints automatically)
- No velocity metrics (intentional — Plot tracks what shipped, not how long it took)
- No automated sprint creation cadence (manual trigger only)
