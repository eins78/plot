# Releasing Plot

Releases are driven by [changesets](https://github.com/changesets/changesets).

## Release flow

1. **Accumulate changesets** — contributors add `.changeset/*.md` files alongside PRs.
2. **Version** — run `pnpm changeset version` to consume all pending changesets, bump `package.json` / `.claude-plugin/plugin.json` / `.claude-plugin/marketplace.json`, and update `CHANGELOG.md`.
3. **Commit** the version bump (conventional message: `chore: version bump`).
4. **Tag** — run `pnpm changeset tag` (creates a git tag matching `package.json` version).
5. **Push** tag to origin — triggers the GitHub Actions release workflow (`.github/workflows/release.yml`), which publishes to npm and creates a GitHub release.

## Same-repo coupling: keeping `plugin.json` aligned with `package.json`

Plot ships its plugin manifest at `.claude-plugin/plugin.json` and its marketplace registry entry at `.claude-plugin/marketplace.json` (registry name: `plot-marketplace`). **There is no separate `eins78/plot-marketplace` repository** — both files live in this repo, identical structural pattern to `eins78/agent-skills` (registry name: `eins78-marketplace`).

**Marketplace version field removed.** Per the official Claude Code plugin docs, when both `plugin.json` and the marketplace entry carry a `version`, `plugin.json` wins and the marketplace value is informational/redundant. PR #13 dropped the `version` field from this repo's `.claude-plugin/marketplace.json` entirely — one drift surface eliminated.

**Remaining gap.** Two files still carry a `version`:

- `package.json` — auto-bumped by `pnpm changeset version`.
- `.claude-plugin/plugin.json` — **not** touched by changesets out of the box.

`plugin.json` is what users see when listing/installing the plugin (it wins over the marketplace entry), so keeping it in sync with `package.json` is load-bearing. If `package.json` advances on a release and `plugin.json` doesn't, users see a stale version. Step 2 of the release flow above will silently leave `plugin.json` behind unless one of the following is in place:

1. **Wrap the version script** — `"version": "changeset version && node scripts/sync-plugin-version.js"` where the script reads `package.json#.version` and writes it into `.claude-plugin/plugin.json`.
2. **Postversion hook** — same effect, plumbed via lifecycle hook.
3. **Manual checklist item** — release template entry; lowest tooling, easiest to forget.

**This PR does not implement any of the three** — the choice belongs in a separate release-pipeline PR. Filing this section as the explicit handoff so the gap isn't lost.
