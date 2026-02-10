# plot-approve

Merge an approved plan and fan out into implementation branches.

## Purpose

Spoke of the Plot workflow. Handles the approval phase — merges the plan PR (landing `docs/plans/<slug>.md` on main), then creates implementation branches and draft PRs for each branch listed in the plan. Each implementation branch carries approval metadata (timestamp, approver) as its initial commit.

## Tier

**Reusable / Publishable** — project-agnostic spoke of the Plot workflow. Adopting projects configure via a `## Plot Config` section in their `CLAUDE.md`.

## Testing

Validated as part of the Plot end-to-end lifecycle tests:

- **test-plot (v1):** Found and fixed empty branch issue on approve (branches need a commit for PR creation). Fixed via approval metadata commit.
- **test-v2:** Full 4-phase lifecycle. Verified plan merge, branch fan-out, and PR linking back to the plan on main.

## Provenance

Originated as part of the Plot workflow in a private project across 5 Claude Code sessions on 2026-02-07. Initially the `/approve` command (session 2), renamed to `/plot-approve` during the v2 refactoring (session 4). Migrated to a standalone skill in this repo.

See [plot/README.md](../plot/README.md) for the full development history and [plot/changelog.md](../plot/changelog.md) for commit-level details.

## Known Gaps

- Relies on `../plot/scripts/plot-pr-state.sh` via relative path — works with symlink installation but may need adjustment for other methods.
- No rollback if branch creation succeeds but PR creation fails partway through a multi-branch fan-out.

## Planned Improvements

- Graceful partial failure handling for multi-branch fan-out.
- Configurable PR template for implementation branches.
