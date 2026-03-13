# Plot manifesto, generic release notes, and review polish

**Date:** 2026-02-08 through 2026-02-10
**Branch:** `feature/generic-release-notes` (PR #4)
**Source:** Claude Code (6 sessions)

## Summary

Made plot skills discover release note tooling generically instead of hardcoding any specific tool. Created MANIFESTO.md codifying Plot's founding principles. Refined Plot's identity from "AI-assisted planning" to "git-native planning for any team." Added model tier guidance, pacing model, RC verification loop, and small-model support across all skills. Addressed real-world feedback from issue #2. Polished prose and structure across a full code review pass.

## Sessions

### 1. Generic release note discovery (2026-02-08)

- Made plot-release discover release tooling generically (changeset configs, CLAUDE.md rules, package.json scripts)
- Added release note awareness to plot-approve (reminder) and plot-deliver (non-blocking check)
- Created MANIFESTO.md codifying 8 principles, lifecycle, non-goals, and decision framework
- Collected 6 real-world issues in GitHub issue #2

Commits: `2949bba`, `1105589`

### 2. Review fixes (2026-02-09)

Code review identified 5 issues, all fixed:
- Merged plot-release steps 2/2b into single step with clear if/else
- Standardized tooling discovery order across all 3 spokes
- Added conditional release note reminder to plot-approve summary template
- Trimmed stale PR description
- Updated README counts

Commit: `c431e4e`

### 3. Conceptual refinement (2026-02-09)

Rewrote MANIFESTO.md and aligned all skills:
- Removed "AI-assisted" framing — plans belong in git; AI is the designed-for sweet spot, not a requirement
- Three roles: human decision-makers, AI/human facilitators, AI/human implementers
- Added transparency paragraph to Principle 1
- Expanded lifecycle with RC verification loop (RC tags, generated checklists, endgame testing, human sign-off)
- Added Pacing section: automate ASAP, natural pause, human-paced
- Added "Could a human execute this manually?" to decision framework
- Restructured plot-release into RC path (2A) and final release path (2B)
- Softened `gh` CLI from requirement to implementation detail

Commits: `4484593`, `80ce013`

### 4. Small models and issue #2 feedback (2026-02-09)

- New Principle 9: facilitator tasks must work with Sonnet/Haiku, not just frontier models
- Three capability tiers (Small/Mid/Frontier) with Model Guidance tables in all skills
- Addressed 6 real-world issues from GitHub issue #2: type reference table, draft PR marking, merge commit default, duplicate detection, release restructuring, date-prefixed plan layout

Commits: `36da107`, `365e713`

### 5. PR review fixes (2026-02-10)

Full code review (18 items). Fixed 15, decided 3 as no-action:
- Resolved Principle 3 tension — clarified skills-vs-scripts distinction, removed editorial note
- Standardized all plot skills to third-person voice (6 instances)
- Standardized tooling discovery format in plot-deliver (pseudocode to numbered list)
- Fixed changelog diffstats, stripped invented severity ratings
- Prose polish: passive voice, needless words, colon splices
- Added sync comments to 4 spoke Setup sections
- Added missing "helper script" to plot-approve Model Guidance table
- Removed drifting line counts from README Structure table

Commits: `3221be2`, `b81b087`, `09a95be`, `69fc88c`, `f640986`, `58815a7`, `5e7c267`

## Decisions

- **Skills stay project-agnostic**: discover conventions at runtime, no hardcoded tool references
- **Plot is a release participant, not driver**: bookkeeping only, actual release mechanics belong to project tooling
- **Release note checks are non-blocking**: missing entries produce warnings, not errors
- **Manifesto vague language (B4):** Keep — principles can be aspirational
- **Emoji in Mermaid (B7):** Keep — functional legend symbols, not decorative
- **Setup duplication (C2):** Keep for standalone use, sync comments added
- **Commit message cosmetics (A1/A3/D1):** Not worth rewriting pushed history

## Changes Made

- Created: `skills/plot/MANIFESTO.md`
- Modified: `skills/plot/SKILL.md`, `skills/plot/README.md`
- Modified: `skills/plot-approve/SKILL.md`, `skills/plot-approve/README.md`
- Modified: `skills/plot-deliver/SKILL.md`, `skills/plot-deliver/README.md`
- Modified: `skills/plot-idea/SKILL.md`
- Modified: `skills/plot-release/SKILL.md`, `skills/plot-release/README.md`
- Modified: `skills/plot/scripts/plot-impl-status.sh`, `skills/plot/scripts/plot-pr-state.sh`

## Repository State

- Branch: `feature/generic-release-notes`
- PR: #4 — ready for review
- 14 files changed, +674/−164 lines (full branch diff)
