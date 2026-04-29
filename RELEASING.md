# Releasing Plot

Releases are driven by [changesets](https://github.com/changesets/changesets).

## Release flow

1. **Accumulate changesets** — contributors add `.changeset/*.md` files alongside PRs.
2. **Version** — run `pnpm changeset version` to consume all pending changesets, bump `package.json` / `.claude-plugin/plugin.json` / `.claude-plugin/marketplace.json`, and update `CHANGELOG.md`.
3. **Commit** the version bump (conventional message: `chore: version bump`).
4. **Tag** — run `pnpm changeset tag` (creates a git tag matching `package.json` version).
5. **Push** tag to origin — triggers the GitHub Actions release workflow (`.github/workflows/release.yml`), which publishes to npm and creates a GitHub release.

## Downstream: plot-marketplace

> **TODO for the maintainer — needs a decision before the first stable release.**

`eins78/plot-marketplace` is the marketplace counterpart that lists the plot plugin for users to discover and install it.

**Current state:** the release workflow in this repo does NOT automatically update the marketplace repo. After a plot release, the marketplace entry is stale until manually updated.

**What likely needs to happen on each release:**
- Bump the version reference in `eins78/plot-marketplace` to match the new plot version.
- Update any release link or changelog pointer in the marketplace entry.
- Open a PR in `eins78/plot-marketplace` (or push directly if the repo allows it).

**Questions the maintainer should decide:**
1. Should this repo's release workflow open a PR in `eins78/plot-marketplace` automatically? (Requires a cross-repo token and a workflow addition here.)
2. Or is a manual step acceptable — e.g., a checklist item in the GitHub release template?
3. What fields in the marketplace entry actually need updating on each plot release?

Until this is decided, the marketplace update is a **manual post-release step** that is easy to forget. Add a reminder to your release checklist.
