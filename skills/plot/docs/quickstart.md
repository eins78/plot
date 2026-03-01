# Plot Quickstart

Get started with Plot in 5 minutes.

## Prerequisites

- **git** — version control
- **gh** — GitHub CLI, authenticated (`gh auth status`)
- **Claude Code** — with skills support

## 1. Install the Skills

Symlink all six Plot skills into your Claude Code skills directory:

```bash
SKILLS_SRC=/path/to/skills  # adjust to your clone location

ln -s "$SKILLS_SRC/plot" ~/.claude/skills/plot
ln -s "$SKILLS_SRC/plot-idea" ~/.claude/skills/plot-idea
ln -s "$SKILLS_SRC/plot-approve" ~/.claude/skills/plot-approve
ln -s "$SKILLS_SRC/plot-deliver" ~/.claude/skills/plot-deliver
ln -s "$SKILLS_SRC/plot-release" ~/.claude/skills/plot-release
ln -s "$SKILLS_SRC/plot-sprint" ~/.claude/skills/plot-sprint
```

## 2. Configure Your Project

Add a Plot Config section to your project's `CLAUDE.md`. Copy from `skills/plot/templates/claude-md-snippet.md`:

```markdown
## Plot Config

- **Branch prefixes:** idea/, feature/, bug/, docs/, infra/
- **Plan directory:** docs/plans/
- **Active index:** docs/plans/active/
- **Delivered index:** docs/plans/delivered/
- **Sprint directory:** docs/sprints/
<!-- - **Project board:** my-project (#1) -->
<!-- - **Output format:** json -->
```

## 3. Create Your First Plan

```
/plot-idea my-feature: Add user authentication
```

This creates:
- Branch `idea/my-feature` from main
- Plan file `docs/plans/YYYY-MM-DD-my-feature.md`
- Symlink in `docs/plans/active/my-feature.md`
- Draft PR titled "Plan: Add user authentication"

## 4. Follow the Workflow

Refine the plan, then mark the PR ready for review:

```bash
gh pr ready <number>
```

After review, approve and create implementation branches:

```
/plot-approve my-feature
```

Implement on the feature branches, merge PRs, then deliver:

```
/plot-deliver my-feature
```

When ready for a versioned release:

```
/plot-release
```

## 5. Check Status Anytime

```
/plot
```

Shows active plans, sprints, open PRs, and suggests the next action.

## 6. Optional: Sprint Planning

Organize work into time-boxed sprints with MoSCoW prioritization:

```
/plot-sprint week-1: Ship auth improvements
```

Add plan-backed items (`[my-feature]`) and lightweight tasks to Must/Should/Could tiers. Commit, start, and close the sprint as the timebox progresses.

## What's Next

- Read the lifecycle diagrams in `skills/plot/SKILL.md` for the full picture
- See `skills/plot/SKILL.md > Troubleshooting` for common issues
- Check `skills/plot/SKILL.md > Flexibility` for natural language overrides
