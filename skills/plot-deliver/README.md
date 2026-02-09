# plot-deliver

Verify all implementation is done, then deliver the plan.

## Purpose

Spoke of the Plot workflow. Handles the delivery phase: verifies all implementation PRs are merged, performs a completeness check (plan deliverables vs actual PR diffs using parallel subagents), and delivers the plan (moves the symlink from `active/` to `delivered/`, updates the Phase field). Plan files never move — they stay at their date-prefixed path. For features/bugs, `/plot-release` follows; for docs/infra, delivery means the work is live.

## Tier

**Reusable / Publishable** — project-agnostic spoke of the Plot workflow. Adopting projects configure via a `## Plot Config` section in their `CLAUDE.md`.

## Testing

Validated as part of the Plot end-to-end lifecycle tests:

- **test-v2:** Full 4-phase lifecycle (Draft through Released). Verified PR merge checking, plan delivery with dated prefix, and the completeness verification flow.
- Used for real work: delivered BDD test coverage via `/plot-deliver development`.

## Provenance

Originated as part of the Plot workflow in a private project. Created during the v2 refactoring (session 4, 2026-02-07) as a new command splitting delivery from the original ship flow. Migrated to a standalone skill in this repo.

See [plot/README.md](../plot/README.md) for the full development history and [plot/changelog.md](../plot/changelog.md) for commit-level details.

## Known Gaps

- Completeness verification relies on LLM judgment of PR diffs against plan deliverables — may miss subtle gaps.
- Relies on `../plot/scripts/plot-impl-status.sh` via relative path.

## Planned Improvements

- Structured completeness checklist output for easier review.
- Support for partial delivery (deliver completed branches, keep plan active for remaining work).
