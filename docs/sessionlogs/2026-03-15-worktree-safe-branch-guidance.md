# Worktree-safe branch guidance

**Date:** 2026-03-15
**PR:** https://github.com/eins78/plot/pull/4 (merged)

## Context

During real sprint automation runs with `claude --worktree`, agents following plot skill instructions would hit errors or conflicts when running `git checkout main` — the main branch is already checked out in the primary working tree.

## Decisions

- **Principle:** Plot skills should never check out `main` locally. All work happens on topic branches.
- **Reading from main:** Use `git show origin/main:<path>` after `git fetch origin main`.
- **Writing to main:** Create a disposable branch (`plot/<action>-<slug>`) from `origin/main`, commit there, then `git push origin <branch>:main` (or create+merge a PR if branch protection requires it).
- **Creating new branches:** `git checkout -b <name> origin/main` was already safe — it creates without checking out main.

## Files changed

- `skills/plot/SKILL.md` — Added "Branch Safety" section, fixed troubleshooting commands
- `skills/plot-approve/SKILL.md` — Steps 4, 7, 8
- `skills/plot-deliver/SKILL.md` — Step 7
- `skills/ralph-plot-sprint/SKILL.md` — Step 2
- `skills/plot-idea/SKILL.md` — Clarifying note (already safe)
- `CLAUDE.md` — Added install-deps-first rule to Testing section

## Follow-up correction

User flagged that agent should always install dependencies before running tests, not dismiss missing `node_modules`. Added to `CLAUDE.md` Testing section as a project rule.
