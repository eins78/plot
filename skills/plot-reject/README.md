# plot-reject

Reverse a premature delivery — move plan from Delivered back to Approved.

## Purpose

Spoke of the Plot workflow. Handles delivery rejection — the inverse of `/plot-deliver`. When a plan was delivered prematurely (e.g., not all branches were built), this skill moves the symlink back from `delivered/` to `active/`, reverts the Phase field to Approved, unchecks the sprint item, and adds rejection metadata. RC tags are preserved as historical records.

Only supports the Delivered→Approved transition. For reversing other phases (Approved→Draft), a separate skill would be needed.

## Tier

**Reusable / Publishable** — project-agnostic spoke of the Plot workflow. Adopting projects configure via a `## Plot Config` section in their `CLAUDE.md`.

## Testing

- **Dry-run:** Validated against the W10 sprint do-over prod-config rejection (qubert commit `696bcd6`). The skill's output should produce equivalent changes to the manual rejection.
- **Edge cases:** Plan not delivered (error), fully-built plan (warning + confirmation), plan without sprint reference (skip sprint update).

## Provenance

Created after the W10 sprint do-over retro revealed that `prod-config` was delivered with only 2/7 branches built. The manual rejection (commit `696bcd6` in qubert) established the pattern that this skill codifies.

See [the retro report](../../docs/retros/W10-doover-retro.md) and [plot/README.md](../plot/README.md) for context.

## Known Gaps

- Only supports Delivered→Approved. Approved→Draft (abandon/rethink) is a different operation not yet codified.
- Does not close any open PRs (there shouldn't be any for a delivered plan, but edge cases may exist).
- Does not interact with project boards (delivered items may need manual board column updates).

## Planned Improvements

- Consider adding Approved→Draft support if the need arises (separate from reject — more like "abandon").
