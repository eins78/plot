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

Automated sprint runner. Loops `claude -p` iterations against an active sprint, each iteration following a strict 5-phase workflow:

0. **Rebase** — `git fetch origin && git rebase origin/HEAD` (abort and BLOCKED on conflicts)
1. **Fix first** — check open PRs for CI failures and unresolved review comments, fix them
2. **Finalize** — mark reviewed PRs ready (`gh pr ready`), optionally merge (`gh pr merge --squash`)
3. **Build** — pick the next highest-priority unblocked task, plan-aware (checks plan phase, uses `/plot-idea` for new plans), implement it, create a PR
4. **Review** — self-review with `/pr-review-toolkit:review-pr`, post findings as PR comments (deliberately NOT fixing them in the same iteration)

The separation of review from fix forces the agent to commit its critique as real PR comments before addressing them — preventing softening of its own review.

Key prompt rules:
- **Plan-awareness:** Tasks referencing unapproved plans trigger `/plot-approve` or BLOCKED. Substantial new tasks get `/plot-idea` first. Never `feature/*` branches for plan-only changes.
- **"Reviewed" definition:** A PR with ANY prior review comments (even if resolved) counts as reviewed. Only re-review if new commits exist since last review.
- **Plan-only PRs:** Single light review for factual errors only — no iterating on prose quality.
- **Single task:** Means step 3 only. Steps 0-2 and 4 apply to all relevant PRs each iteration.

### Promise signals

Each iteration ends with one of two `<promise>` signals:

| Signal | Meaning | Loop behavior |
|--------|---------|---------------|
| `<promise>COMPLETE</promise>` | All tasks done, all PRs finalized (merged or ready depending on `RALPH_SPRINT_AUTOMERGE`) | Exit, notify |
| `<promise>BLOCKED</promise>` | Cannot make further progress (blocked tasks, rebase conflicts, needs human action) | Exit, notify |

If the agent doesn't output a signal, the loop continues to the next iteration. The `<promise>` XML tags prevent false-positive detection — bare keywords like `COMPLETE` can appear in agent analysis text, but the tag format won't.

Earlier versions had a third `REVIEW` signal that continued the loop when PRs needed human review. This was removed — if the agent can't make progress, that's BLOCKED regardless of the reason.

### Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `RALPH_SPRINT_CLAUDE` | No | `claude --dangerously-skip-permissions` | Claude command to run |
| `RALPH_SPRINT_AUTOMERGE` | No | `false` | Auto-merge reviewed PRs (`true`/`false`) |
| `RALPH_SPRINT_TIMEOUT` | No | `1800` | Per-iteration timeout in seconds (30 min) |
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

# Auto-merge reviewed PRs:
RALPH_SPRINT_AUTOMERGE=true ralph-sprint.sh 100 steal-features

# Mid-run steering (inject instructions into next iteration):
echo "Skip PR #38, it is plan-only" > .ralph-state/instructions.md
```

### Design decisions

- **`-p` mode buffers output** — `claude -p` with text output doesn't stream incrementally. Each iteration's output appears in full when the agent finishes. `--output-format stream-json` exists but outputs JSON, adding parsing complexity.
- **EXIT trap instead of INT/TERM** — Earlier versions used `trap cleanup INT TERM`, which missed `set -e` failures (no wrapup, no notification). EXIT trap catches all exits.
- **`--worktree` per sprint** — Each iteration runs in `sprint-$SLUG` worktree for isolation from main.
- **Wrap-up via `/bye`** — On exit, collects all session IDs and runs a final session that resumes each transcript to create a combined sessionlog.
- **Configurable auto-merge** — Default `false` leaves PRs ready for human review. Set `true` for fully autonomous execution. Learned from the steal-features sprint where all 8 PRs ended up as unmerged drafts despite COMPLETE signal.
- **Plan-awareness** — The prompt distinguishes plan-backed tasks from direct work, preventing orphan `feature/*` branches for plan-only changes (as happened with PR #38 in the steal-features sprint).
- **Mid-run instruction injection** — Write to `.ralph-state/instructions.md` to steer the next iteration without killing the loop. The file is consumed and deleted after injection.
- **Per-iteration timeout** — Prevents hung `claude` processes from blocking the sprint indefinitely. On timeout, the iteration result is empty, no signal detected, loop continues.

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

### Prompt improvements after steal-features sprint retro

| Change | Motivation |
|--------|-----------|
| Added FINALIZE step (step 2) | 8 PRs ended as unmerged drafts despite COMPLETE — prompt never said to merge |
| Configurable auto-merge via `RALPH_SPRINT_AUTOMERGE` | Default: ready-but-don't-merge. Human can opt into full autonomy |
| Plan-aware task picking (step 3) | PR #38 was a plan doc on a `feature/*` branch — violates Plot conventions |
| Ban on `feature/*` for plan-only changes | Plans belong on main via `/plot-idea`, not feature branches |
| Precise "reviewed" definition (step 4) | Iteration 6 re-reviewed PR #38 already reviewed in iteration 5 |
| Plan-only PR lighter review | 3 iterations wasted on prose quality reviews of plan doc |
| Rebase conflict → BLOCKED | No guidance for unresolvable conflicts |
| "Search before assuming" | Ralph article: LLMs produce false negatives from code search |
| Retry cap (3 times) | "A reasonable number of times" was vague |
| Configurable COMPLETE criteria | Old criteria let agent declare victory with everything in draft |
| Mid-run instruction injection | No way to steer without killing and restarting |
| Per-iteration timeout (30 min) | No watchdog for hung processes |

### Open questions

- Could add `--output-format stream-json` with a jq pipeline for real-time text output (adds complexity)
- Ctrl+C doesn't propagate when claude is inside command substitution `$()` — must `kill <pid>` directly

## Known Gaps

- No cross-sprint item tracking (items can't span multiple sprints automatically)
- No velocity metrics (intentional — Plot tracks what shipped, not how long it took)
- No automated sprint creation cadence (manual trigger only)
