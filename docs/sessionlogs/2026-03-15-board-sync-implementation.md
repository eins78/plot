# Implement board-sync: GitHub Projects status sync

**Date:** 2026-03-15
**Scope:** New script + 12 modified files, PR #8 merged
**Plan:** `docs/plans/2026-03-15-board-sync.md`

## What

Implemented the board-sync feature: a helper script (`plot-update-board.sh`) that keeps GitHub Projects board Status fields in sync with Plot phase transitions. Each spoke skill now calls this script after its phase transition instead of the old `gh pr edit --add-project` approach.

Phase-to-status mapping: plot-idea sets "Planning", plot-approve sets "Done" (plan PR) + "Ready" (impl PRs), plot-deliver sets "Done" (all impl PRs). Release and reject don't need board updates.

## Key decisions

- **Config format breaking change:** `<name> (#<number>)` replaced with `owner/number` because `gh project` CLI needs owner + number, not the board name
- **Cache location:** Initially `/tmp` per spec suggestion, moved to `.git/` after AI review flagged symlink vulnerability (CWE-377)
- **Atomic cache writes:** Added tmp+mv pattern after AI review flagged race condition during `/plot-approve` fan-out

## Review findings

**Self-review (4 fixes):**
1. Unguarded `jq` extractions under `set -e` could exit 1 instead of spec'd exit 0 — added `|| true`
2. CLAUDE.md incorrectly claimed all 4 scripts provide "structured JSON output" — reworded (new script is write-only)
3. README Structure table missing `plot-review-status.sh` and `plot-update-board.sh` — added both
4. "What Goes Where" table had stale "Project board name" label — updated to `owner/number`

**AI review / Gemini (2 fixes):**
1. Predictable `/tmp` cache file — symlink vulnerability — moved to `.git/` directory
2. Race condition on concurrent cache writes — atomic write via `tmp.$$` + `mv`

## Commits (feature/board-sync, merged as PR #8)

- `921e55b` plot: add board-sync script and update spoke skills
- `c8da345` plot: fix review findings in board-sync
- `e9fa29e` plot: fix cache security and atomicity in board-sync script

## Pre-existing issue noted

`plot-reject/SKILL.md` step 5 uses `git checkout main` — violates Branch Safety convention. Not fixed in this PR (out of scope).
