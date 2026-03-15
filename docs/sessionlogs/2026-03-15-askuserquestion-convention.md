# Add AskUserQuestion convention to all skills

**Date:** 2026-03-15
**Scope:** All 8 SKILL.md files, CLAUDE.md, plugin metadata

## What

Added explicit `AskUserQuestion` (Claude Code) / `ask_question` (Cursor) tool guidance across all Plot skills. Previously, skills said "ask the user" without specifying the tool, so agents might continue with assumptions instead of pausing.

## Approach decided

- **Hub skill** (`plot/SKILL.md`): Full convention bullet in `## Conventions` — explains trigger words and rationale
- **7 spoke skills**: Compact blockquote one-liner after Model Guidance table
- **CLAUDE.md**: Project-level fallback one-liner in Skill Authoring section
- User chose "Hub + each spoke" over "hub only" or "full section everywhere"

## Review finding

Code review caught a missed version bump in CLAUDE.md's `## Status` section (still said `1.0.0-beta.1`). Fixed in a follow-up commit before merge.

## Commits

- `ad4015b` — plot: add AskUserQuestion tool convention for user interaction
- `5220701` — fix: bump version in CLAUDE.md Status section to 1.0.0-beta.2

## PR

- #7 — merged to main
