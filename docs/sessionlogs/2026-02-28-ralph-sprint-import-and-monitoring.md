# ralph-sprint: Import, Fix, and First Full Run

**Date:** 2026-02-28
**Source:** Claude Code
**Session:** Reconstructed from 1 compaction · ~174k input / ~59k output tokens

## Summary

Imported `ralph-sprint.sh` from `~/OPS/home-workspace/scripts/` into the `skills/plot-sprint/` skill directory. Fixed 7 bugs found during deep logic review, stripped hardcoded credentials, made the claude command configurable. Then monitored a full 13-iteration autonomous sprint run against the qubert project's `steal-features` sprint — all 8 PRs reviewed, 63 review comments addressed, COMPLETE signal fired correctly.

## Key Accomplishments

- Imported ralph-sprint.sh with 7 bug fixes (critical: restored `<promise>` tag signal detection)
- Created install.sh symlink installer
- Updated README.md with architecture docs, bug history, design decisions
- Discovered and fixed signal semantics issue ("no signal" = continue, not BLOCKED)
- Monitored 13 iterations (~130 min) of autonomous sprint work to completion
- All script mechanisms validated end-to-end: signal detection, rebase step, wrap-up session

## Bug Investigation

The most important discovery: **signal detection false-positives**. The script had degraded from `<promise>` XML tags to bare `grep '^COMPLETE'`, which matches echoed prompt text (the prompt contains `COMPLETE — all sprint tasks done...` at line start). Restored the unforgeable `<promise>COMPLETE</promise>` tag format.

Second key fix: **signal semantics**. The agent was outputting BLOCKED after posting review comments, when it should have continued (next iteration picks up the comments). Fixed by clarifying in the prompt that BLOCKED means "truly stuck" and that no signal = continue.

## Changes Made

- Created: `skills/plot-sprint/ralph-sprint.sh` (automated sprint runner)
- Created: `skills/plot-sprint/install.sh` (symlink installer)
- Created: `skills/plot-sprint/ralph-sprint-monitor.log` (monitoring observations)
- Modified: `skills/plot-sprint/README.md` (added ralph-sprint docs)
- Modified: `README.md` (updated skills table)

## Decisions

- **Credential handling:** Environment variables only, no defaults for secrets
- **Signal format:** `<promise>` XML tags prevent false positives from agent prose
- **Two signals only:** COMPLETE and BLOCKED. REVIEW signal removed — if agent can't progress, that's BLOCKED regardless of reason. No signal = continue.
- **Name:** Kept "ralph-sprint" as-is

## Lessons Learned

- **Kill safety:** Must verify PIDs carefully before killing processes — killed own claude session by mistake. Check ppid and command args to distinguish target from self.
- **Re-review loop risk:** Agent re-reviewed PR #38 twice (iter 5 and 6), but converged by iter 7. The fix-then-review cycle naturally decreases issue count each round.
- **Plan-only PRs:** PR #38 (worktree-isolation) has no code, just a plan doc. Agent kept finding documentation issues but eventually converged after 3 iterations.
- **`-p` mode buffering:** Each iteration's output appears in full when the agent finishes. No incremental streaming.

## Pending

- [ ] Push 3 commits to origin/main (skills repo)
- [ ] Human review and merge all 8 qubert feature PRs (#33-#40) in dependency order
- [ ] Clean up worktree `.claude/worktrees/sprint-steal-features`
