# plot-sprint

Sprint management for the Plot planning system.

## Purpose

Adds time-boxed coordination to Plot. Sprints group work by schedule (start date, end date, MoSCoW priorities) while plans group work by scope. Sprint files live in `docs/sprints/` and are committed directly to main — no PR workflow.

## Structure

```
skills/plot-sprint/
├── SKILL.md           # Sprint lifecycle: create, commit, start, close, status
├── ralph-sprint.sh    # Automated sprint runner (loops claude -p iterations)
├── install.sh         # Symlinks ralph-sprint.sh to ~/bin/
└── README.md          # This file
```

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

## ralph-sprint.sh

Automated sprint runner. Loops `claude -p` iterations against an active sprint, each iteration following a strict 3-phase workflow:

1. **Fix first** — check open PRs for CI failures and unresolved review comments, fix them
2. **Build second** — pick the next highest-priority unblocked task, implement it, create a PR
3. **Review third** — self-review with `/pr-review-toolkit:review-pr`, post findings as PR comments (deliberately NOT fixing them in the same iteration)

The separation of review from fix forces the agent to commit its critique as real PR comments before addressing them — preventing softening of its own review.

### Promise signals

Each iteration ends with one of two `<promise>` signals:

| Signal | Meaning | Loop behavior |
|--------|---------|---------------|
| `<promise>COMPLETE</promise>` | All tasks done, all PRs green and clean | Exit, notify |
| `<promise>BLOCKED</promise>` | Cannot make further progress (blocked tasks, needs human review, etc.) | Exit, notify |

If the agent doesn't output a signal, the loop continues to the next iteration. The `<promise>` XML tags prevent false-positive detection — bare keywords like `COMPLETE` can appear in agent analysis text, but the tag format won't.

Earlier versions had a third `REVIEW` signal that continued the loop when PRs needed human review. This was removed — if the agent can't make progress, that's BLOCKED regardless of the reason.

### Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `RALPH_SPRINT_CLAUDE` | No | `claude --dangerously-skip-permissions` | Claude command to run |
| `CLAUDE_NTFY_URL` | Yes | — | ntfy server URL |
| `CLAUDE_NTFY_TOKEN` | Yes | — | ntfy bearer token |
| `CLAUDE_NTFY_TOPIC` | No | `claude-on-$(hostname -s)` | ntfy topic |

### Installation

```bash
cd skills/plot-sprint && ./install.sh
```

Or manually: `ln -sf $(pwd)/ralph-sprint.sh ~/bin/ralph-sprint.sh`

### Usage

```bash
ralph-sprint.sh <iterations> <slug>
# Example: ralph-sprint.sh 100 steal-features
```

### Design decisions

- **`-p` mode buffers output** — `claude -p` with text output doesn't stream incrementally. Each iteration's output appears in full when the agent finishes. `--output-format stream-json` exists but outputs JSON, adding parsing complexity.
- **EXIT trap instead of INT/TERM** — Earlier versions used `trap cleanup INT TERM`, which missed `set -e` failures (no wrapup, no notification). EXIT trap catches all exits.
- **`--worktree` per sprint** — Each iteration runs in `sprint-$SLUG` worktree for isolation from main.
- **Wrap-up via `/bye`** — On exit, collects all session IDs and runs a final session that resumes each transcript to create a combined sessionlog.

### Bug fixes applied during import

| Bug | Severity | Fix |
|-----|----------|-----|
| Signal detection false-positives | Critical | Restored `<promise>` tags (was bare `grep '^COMPLETE'` matching echoed prompt text) |
| `set -e` bypassed cleanup | High | Changed to EXIT trap with `EXITING_NORMALLY` flag |
| `jq` on malformed JSON crashed script | High | Added `2>/dev/null \|\| result=""` guards |
| `$i` undefined in cleanup before loop | Medium | Initialized `i=0` at script start |
| Cleanup→wrapup signature mismatch | Medium | Cleanup now calls notify() then wrapup() with correct args |
| Dead `tmpfile` variable | Low | Removed |
| Signal checks used `if/if/if` not `elif` | Low | Changed to `if/elif/elif/else` |

### Provenance

Developed in `~/OPS/home-workspace/scripts/` over 14 commits (1faa701..9e0d007). Live-tested against the qubert project — iteration 1 implemented a seatbelt sandbox feature, created PR #37, and sent an ntfy notification.

### Open questions

- Could add `--output-format stream-json` with a jq pipeline for real-time text output (adds complexity)
- No timeout/watchdog for hung `claude` processes
- Self-review loop not yet fully validated end-to-end across multiple iterations

## Known Gaps

- No cross-sprint item tracking (items can't span multiple sprints automatically)
- No velocity metrics (intentional — Plot tracks what shipped, not how long it took)
- No automated sprint creation cadence (manual trigger only)
