# Releasing Plot

Releases are driven by [changesets](https://github.com/changesets/changesets).

## Release flow

1. **Accumulate changesets** — contributors add `.changeset/*.md` files alongside PRs.
2. **Version** — run `pnpm changeset version` to consume all pending changesets, bump `package.json` / `.claude-plugin/plugin.json` / `.claude-plugin/marketplace.json`, and update `CHANGELOG.md`.
3. **Commit** the version bump (conventional message: `chore: version bump`).
4. **Tag** — run `pnpm changeset tag` (creates a git tag matching `package.json` version).
5. **Push** tag to origin — triggers the GitHub Actions release workflow (`.github/workflows/release.yml`), which publishes to npm and creates a GitHub release.

## Same-repo coupling: keeping plugin/marketplace versions in sync

Plot ships its plugin manifest at `.claude-plugin/plugin.json` and its marketplace registry entry at `.claude-plugin/marketplace.json` (registry name: `plot-marketplace`). **There is no separate `eins78/plot-marketplace` repository** — both files live in this repo, identical structural pattern to `eins78/agent-skills` (registry name: `eins78-marketplace`).

**The gap:** `pnpm changeset version` only updates `package.json` and `CHANGELOG.md`. It does **not** touch `.claude-plugin/plugin.json` or `.claude-plugin/marketplace.json` — neither out of the box nor via the current `.changeset/config.json`. All three files are at `1.0.0-beta.4` today only because they were manually aligned. On the next `changeset version` run, `package.json` will move forward and the two `.claude-plugin/*.json` files will silently fall behind unless something keeps them in sync.

**Step 2 of the release flow above currently overstates what changesets does.** Before the next release, one of these needs to be in place:

1. **Wrap the version script** — `"version": "changeset version && node scripts/sync-plugin-versions.js"` where the script reads `package.json#.version` and writes it into both `.claude-plugin/*.json` files. Lowest friction; deterministic.
2. **Postversion hook** — same effect, plumbed via lifecycle hook instead of script chaining.
3. **Manual checklist** — release template item; lowest tooling, easy to forget, will eventually fail.

**This PR does not implement any of the three options** — the choice and implementation belong in a follow-up release-pipeline PR. Filing this section as the explicit handoff so it isn't lost.
