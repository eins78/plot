# ralph-plot-sprint

Automated sprint iteration skill + runner script for the Plot workflow.

## What's in this directory

| File | Purpose |
|------|---------|
| `SKILL.md` | The `/ralph-plot-sprint` skill — one iteration of sprint work |
| `ralph-sprint.sh` | Bash loop that calls the skill N times until COMPLETE/BLOCKED |
| `install.sh` | Symlinks `ralph-sprint.sh` to `~/bin/` |
| `ralph-sprint-monitor.log` | Observations from live sprint runs |

## Skill tier

**Specialized automation** — not a general-purpose skill. The skill is only invoked by `ralph-sprint.sh` (or manually for debugging). The `description:` frontmatter is deliberately narrow to prevent auto-activation.

## Architecture

```
ralph-sprint.sh  (bash loop)
    │
    ├── pre-flight: gh auth check, sprint file exists
    │
    └── for each iteration:
          claude -p "/ralph-plot-sprint <slug>"
               │
               └── SKILL.md (reads state, picks steps, does work)
                        │
                        ├── /plot-sprint (read sprint state)
                        ├── Task agents (parallel CI/review checks)
                        ├── /pr-review-toolkit:review-pr
                        ├── /show-your-work (demos)
                        └── /plot-release rc
```

**Why bash for the loop:** Each iteration starts with a fresh Claude context window. A bash loop is the simplest way to enforce this — no shared state between iterations, crash-resistant (iteration N+1 starts fresh from git state regardless of what N did).

**Why a skill for the body:** The 70-line heredoc that previously lived in `ralph-sprint.sh` was hard to read, update, and reuse. A skill is independently versioned, readable, and can reference other skills. The bash script is now a generic runner.

## Usage

```bash
# Install
./install.sh

# Run (from the sprint project root directory)
ralph-sprint.sh <iterations> <slug>
ralph-sprint.sh 20 steal-features

# Auto-merge mode (merge PRs automatically after finalizing)
RALPH_SPRINT_AUTOMERGE=true ralph-sprint.sh 20 steal-features

# Mid-run steering (inject instructions into next iteration):
echo "Skip PR #38, it is plan-only" > .ralph-state/instructions.md

# Custom iteration skill (override the default /ralph-plot-sprint):
RALPH_SPRINT_SKILL=my-custom-sprint ralph-sprint.sh 10 my-sprint
```

## Environment variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `CLAUDE_NTFY_URL` | Yes | — | ntfy server URL |
| `CLAUDE_NTFY_TOKEN` | Yes | — | ntfy bearer token |
| `RALPH_SPRINT_CLAUDE` | No | `claude --dangerously-skip-permissions` | Claude command |
| `RALPH_SPRINT_SKILL` | No | `ralph-plot-sprint` | Iteration skill name |
| `RALPH_SPRINT_AUTOMERGE` | No | `false` | Auto-merge reviewed PRs |
| `RALPH_SPRINT_TIMEOUT` | No | `1800` | Per-iteration timeout (seconds) |
| `CLAUDE_NTFY_TOPIC` | No | `claude-on-$(hostname -s)` | ntfy topic |

## Promise signals

Each iteration ends with one of:

| Signal | Meaning | Loop behavior |
|--------|---------|---------------|
| `<promise>COMPLETE</promise>` | All sprint work done + DoD satisfied | Exit 0, notify |
| `<promise>BLOCKED</promise>` | Stuck (rebase conflict, RC needs human testing, etc.) | Exit 1, notify |
| *(no signal)* | Did useful work, more to do | Continue to next iteration |

The XML tag format prevents false-positive detection — bare `COMPLETE` or `BLOCKED` keywords appear in analysis text, but the `<promise>` tags won't.

## What the skill does each iteration

The skill reads actual project state before deciding which steps to run:

| Step | Action | Skip condition |
|------|--------|----------------|
| 0. Orient | Read sprint file, PRs, demos, DoD, RC tag | Never skipped |
| 1. Fix | Fix CI failures + unresolved comments | No open PRs |
| 2. Finalize | Merge/ready reviewed green PRs | No finalizable PRs |
| 3. Build | Implement one new sprint task | No unstarted tasks |
| 4. Review | Self-review unreviewed code PRs | All PRs reviewed |
| 5. Demos | Create missing demos via /show-your-work | All demos present |
| 6. RC | Tag release candidate via /plot-release rc | Demos missing |

The Orient step's state-awareness eliminates wasted "check 0 open PRs" passes.

## Compared to the old approach (heredoc in ralph-sprint.sh)

| Before | After |
|--------|-------|
| 70-line heredoc in bash | Dedicated skill file |
| `COMPLETE_CRITERIA` hardcoded in script | Skill reads `docs/definition-of-done.md` from project |
| Steps always ran in fixed order | Skill jumps to first applicable step |
| Script needed editing for project-specific requirements | Edit DoD file in project, not the skill |
| No pre-flight checks | Auth + sprint-exists check before loop starts |
| Notifications only on COMPLETE/BLOCKED | Per-iteration ntfy so human can monitor passively |
| No way to swap iteration logic | `RALPH_SPRINT_SKILL` env var for custom iteration |

## Provenance

Developed by live monitoring the steal-features sprint on qubert (2026-03-01):
- Run 5: 13 review/fix iterations, all 8 PRs merged in 2 iterations with automerge
- Observations documented in `ralph-sprint-monitor.log`
- Key learnings: DoD must live in skill (not bash), pre-flight auth check needed,
  per-iteration ntfy enables unattended operation

## Known gaps

- Ctrl+C doesn't propagate when `claude` is inside `$()` — need `kill <pid>` directly
- No velocity metrics (iterations/PR, time-per-iteration) — intentional, Plot tracks what shipped
- `--output-format stream-json` could enable real-time output but adds jq complexity
