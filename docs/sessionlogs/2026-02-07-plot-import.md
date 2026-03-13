# Add Plot skill: git-native planning workflow

**Date:** 2026-02-07
**Source:** Claude Code
**PR:** #1

## Summary

Imported the Plot workflow system — a lean, git-native planning system with 5 commands and 4 lifecycle phases — from a private project. Each command is its own skill directory with proper `SKILL.md` and frontmatter, so the skills CLI discovers all 5 as invocable commands. Added a `postinstall` script for automatic skill installation.

## Key Accomplishments

- Imported 5 plot skills + 2 helper scripts (771 lines of instructions)
- Each command in its own skill directory: `plot/`, `plot-idea/`, `plot-approve/`, `plot-deliver/`, `plot-release/`
- Added 3 Mermaid lifecycle diagrams (render natively on GitHub)
- Wrote README.md with 8 design principles, provenance, testing history
- Wrote changelog.md documenting all 5 development sessions with commit references
- Removed all project-specific references (project name, hardcoded paths)
- Added `postinstall` script for Claude Code skill installation

## Changes Made

- Created: `skills/plot/SKILL.md` (dispatcher: overview, diagrams, setup)
- Created: `skills/plot-idea/SKILL.md` (create plan command)
- Created: `skills/plot-approve/SKILL.md` (approve and fan out command)
- Created: `skills/plot-deliver/SKILL.md` (verify and archive command)
- Created: `skills/plot-release/SKILL.md` (version bump and tag command)
- Created: `skills/plot/scripts/plot-pr-state.sh` (plan PR state helper)
- Created: `skills/plot/scripts/plot-impl-status.sh` (impl PR states helper)
- Created: `skills/plot/README.md` (development docs)
- Created: `skills/plot/changelog.md` (evolution history)
- Modified: `package.json` (added postinstall script)

## Decisions

- **Mermaid over Graphviz/dot**: Renders natively on GitHub (no build step), better LLM training coverage.
- **Separate skill directories**: Skills CLI requires YAML frontmatter in `SKILL.md` to discover commands. One directory per command ensures all 5 are invocable.
- **Scripts stay in `plot/`**: Helper scripts are shared by approve and deliver, referenced via `../plot/scripts/`.
- **README/changelog stay in `plot/`**: Cover the whole system, not a single command.
- **Claude Code only for postinstall**: No need to install to all 39 agents.

## Next Steps

- [ ] Verify Mermaid diagrams render on GitHub
- [ ] Install skill in a project and test full lifecycle
