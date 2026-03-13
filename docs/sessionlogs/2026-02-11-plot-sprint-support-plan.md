# Sprint Support Plan (Rebased, Refined, Approved)

**Date:** 2026-02-11
**Source:** Claude Code

## Summary

Rewrote the sprint support plan to fit the current Plot system after PR #4, refined it with 8 improvements, then approved and created the implementation branch.

## Key Accomplishments

### Session 1: Plan creation (rebased onto PR #4)
- Adapted all 7 conflict areas from the original plan (manifesto principle slot, non-goals wording, model guidance, pacing, RC verification, third-person voice, directory structure)
- Key design shift: dedicated `/plot-sprint` command instead of extending every existing spoke
- Key design shift: sprints commit directly to main — coordination artifacts, not implementation plans

### Session 2: Refinement and approval
- Applied 8 refinements to the plan document:
  1. ISO week prefix for sprint files (`YYYY-Www-<slug>.md`)
  2. Dropped `closed/` symlink directory — closed sprints identified by Phase field
  3. Resolved auto-discover plans question (creation step lists active plans)
  4. Resolved dispatcher countdown question (remaining days + progress)
  5. Added testing strategy (test-sprint E2E scenario + spoke awareness tests)
  6. Strengthened direct-to-main justification (Principle 2 rationale + guardrail)
  7. Added Windows symlink compatibility note
  8. Removed Open Questions section (all resolved)
- Rebased `idea/plot-sprint-support` onto main (post-PR#4 merge)
- Marked PR #5 ready for review
- Merged plan PR #5 to main
- Created implementation branch `feature/plot-sprint-support` with PR #7 (draft)
- Updated plan on main with PR link (`→ #7`)

## Changes Made

- Modified: `docs/plans/2026-02-11-plot-sprint-support.md` (refinements, then PR link)
- Created: `feature/plot-sprint-support` branch with Phase: Approved
- Merged: PR #5 (`idea/plot-sprint-support`)
- Created: PR #7 (`feature/plot-sprint-support`, draft)

## Decisions

- Dedicated `/plot-sprint` skill: sprints have different lifecycle, directory, and no branch fan-out
- No new manifesto principle: sprints get a `## Sprints` section instead
- Sprint files use ISO week prefix for disambiguation across weeks
- Single symlink directory (`active/` only) — closed sprints not operationally queried
- Sprint creation auto-discovers active plans and offers to include them
- Dispatcher shows countdown and progress for active sprints

## Plan Reference

- Plan: `~/.claude/plans/merry-hugging-simon.md`
- Planned: Mark PR ready, merge, create impl branch, link PRs
- Executed: All steps completed successfully

## Next Steps

- [ ] Implement sprint support on `feature/plot-sprint-support` (PR #7)
  - New `skills/plot-sprint/` skill directory
  - MANIFESTO.md `## Sprints` section
  - Spoke modifications (plot, plot-approve, plot-deliver, plot-release, plan-idea)
  - Documentation updates

## Repository State

- Committed: f141388 - plot: link implementation PRs for plot-sprint-support
- Branch: main (implementation on feature/plot-sprint-support → PR #7)
