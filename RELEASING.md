# Releasing Plot

Plot uses [Changesets](https://github.com/changesets/changesets) for versioning, with a per-skill version bumping layer on top. The pipeline runs in GitHub Actions on push to `main`.

## TL;DR — adding a changeset

```bash
pnpm changeset
# edit the created .changeset/<timestamp>.md
```

Each PR that touches skills should include a changeset. The CI workflow warns if a PR has no changeset and errors if a `bumps:` block references a non-existent skill directory.

## Changeset format

```markdown
---
"plot": minor
---

Brief description of the change

<!--
bumps:
  skills:
    plot-idea: patch
    plot-approve: minor
-->
```

- The frontmatter block (`"plot": minor`) drives the **plugin-level** version bump (writes to `package.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`).
- The HTML-comment `bumps:` block drives **per-skill** SKILL.md version bumps. Use the directory name under `skills/` (e.g. `plot-idea`, not `idea`).
- If a change touches no skills, the `bumps:` block can be omitted entirely.

Per `CLAUDE.md`: skill patch → plugin patch (at minimum), skill minor → plugin minor (at minimum), skill major → plugin major.

## Pipeline

```
pnpm run version (run by changesets/action)
  bump-skill-versions.sh → changeset version → sync-versions.sh
  (read bumps: blocks)     (consume changesets)  (sync plugin.json + marketplace.json)
```

On push to `main`:

1. **`release.yml`** runs `changesets/action`.
2. If pending changesets exist, the action opens a `release: X.Y.Z` PR that contains the bumped versions and updated `CHANGELOG.md`.
3. When that PR merges, the action's `publish` step runs `create-release.sh`, which tags the commit (`vX.Y.Z` plus `<skill>@<version>` for each skill) and creates a GitHub Release with the changelog.

## Local commands

| Command | Purpose |
|---------|---------|
| `pnpm changeset` | Create a new changeset file from the template |
| `pnpm run validate` | Validate SKILL.md frontmatter (CI runs this on every PR) |
| `pnpm test` | Verify all skills parse |
| `pnpm run version` | Apply pending changesets locally (bump skill versions, run `changeset version`, sync plugin metadata) |
| `pnpm run release` | Manual escape hatch: run `version`, commit, and tag locally (use only if Actions is broken) |
