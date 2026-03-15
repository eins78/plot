# Sync plan phase transitions to GitHub Projects board columns

> Keep GitHub Projects board status in sync with Plot phase transitions via a shared helper script.

## Status

- **Phase:** Draft
- **Type:** feature

## Changelog

- Plot spoke commands now update the GitHub Projects board Status field when plans transition phases (idea → approve → deliver)

## Motivation

Plot's 4-phase lifecycle (Draft → Approved → Delivered → Released) doesn't map to GitHub Projects' built-in PR automations. GitHub only auto-handles "PR added → Todo" and "PR merged → Done", but Plot has intermediate phases (Planning, Ready, In Progress) that require explicit Status field updates.

Currently Plot only adds PRs to a board via `gh pr edit --add-project`. After that, items sit in whatever default column GitHub assigns. Users must manually drag items between columns — defeating the purpose of the board.

## Design

### Approach

**One script, short references from each spoke.**

Add `scripts/plot-update-board.sh` to the main plot skill. Each spoke skill adds a one-liner calling this script after its phase transition. The script:

1. Accepts: PR URL, target status name, project owner, project number
2. Adds the PR to the board if not already present (`gh project item-add`)
3. Looks up the item on the board by PR URL
4. Finds the Status field and the matching option
5. Calls `gh project item-edit` to set it
6. Exits silently (exit 0) if: no board configured, token lacks `project` scope, PR URL invalid

This **replaces** the old `gh pr edit --add-project` approach entirely. One script handles both adding and status-setting. Skills just say "set this PR to this status" — they don't need to know field IDs, GraphQL, or whether the item is already on the board.

### Phase-to-Status Mapping

Based on the GitHub Projects "Kanban" board template (adapted):

| Plot event | Spoke skill | Board Status | Which PR(s) |
|---|---|---|---|
| `/plot-idea` | plot-idea | **Planning** | Plan PR (draft) |
| `/plot-approve` | plot-approve | **Done** | Plan PR (now merged) |
| `/plot-approve` | plot-approve | **Ready** | New implementation PRs |
| impl work starts | (manual — agent calls script) | **In Progress** | Implementation PR being worked on |
| `/plot-deliver` | plot-deliver | **Done** | All implementation PRs |

Note: `/plot-release` doesn't need board updates — items are already Done.

### Config Changes

The `## Plot Config` template and `claude-md-snippet.md` need updating:

```markdown
<!-- Optional: uncomment if using a GitHub Projects board -->
<!-- - **Project board:** owner/number (e.g. eins78/5) -->
```

The format changes from `<name> (#<number>)` to `<owner>/<number>` because `gh project` commands need owner + number, not the board name.

### Script Design: `plot-update-board.sh`

```
Usage: plot-update-board.sh <pr-url> <status> <owner> <project-number>

Arguments:
  pr-url          Full PR URL (e.g. https://github.com/eins78/slideshow-app/pull/17)
  status          Target status name (e.g. "Planning", "Ready", "In progress", "Done")
  owner           GitHub user or org that owns the project (e.g. "eins78")
  project-number  Project number (e.g. "5")

Exit codes:
  0  Success, or gracefully skipped (no board, no scope, item not found)
  1  Usage error (missing arguments)
```

Internally:
1. `gh project item-add <number> --owner <owner> --url <pr-url>` — add to board (idempotent, no-op if already present)
2. `gh project item-list <number> --owner <owner> --format json` — find item ID by PR URL
3. `gh project field-list <number> --owner <owner> --format json` — find Status field ID + option ID
4. `gh project item-edit --project-id <id> --id <item-id> --field-id <field-id> --single-select-option-id <option-id>` — set status

### Spoke Skill Changes

Each spoke adds a short section referencing the script. Example for plot-idea:

```markdown
### N. Update Board Status

If `## Plot Config` includes a project board, update the plan PR status:

    ../plot/scripts/plot-update-board.sh <pr-url> "Planning" <owner> <number>

If no project board is configured, skip this step.
```

### Open Questions

- [x] Board column names — confirmed from real board: Planning, Ready, In progress, Done
- [x] **Consolidate add+update:** Yes. The script handles both adding PRs to the board (`gh project item-add`) and setting status in one call. This replaces `gh pr edit --add-project` everywhere, eliminating the old board name config format. One script, one config format (`owner/number`).
- [x] **"In Progress" handling:** Manual. The agent calls the script when starting work on an impl branch. No new infrastructure (GitHub Actions, hooks). Consistent with Manifesto — board is a convenience, not source of truth. If the agent forgets, items stay in "Ready" until delivered.

## Branches

- `feature/board-sync` — Add `plot-update-board.sh` script, update spoke skills with board sync references, update config template

## Notes

- Real board structure from eins78's project #5: Status field has Planning, Ready, In progress, Done
- Also has Priority (P0/P1/P2) and Size (XS/S/M/L/XL) fields — not in scope for this plan but could be useful for sprint integration later
- The `gh project` CLI requires `project` scope on the token — add via `gh auth refresh -s project`
