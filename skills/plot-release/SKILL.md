---
name: plot-release
description: >-
  Create a versioned release from delivered plans.
  Part of the Plot workflow. Use on /plot-release.
globs: []
license: MIT
metadata:
  author: eins78
  repo: https://github.com/eins78/skills
  version: 1.0.0-beta.1
compatibility: Designed for Claude Code and Cursor. Requires git. Currently uses gh CLI for forge operations, but the workflow works with any git host that supports pull request review.
---

# Plot: Cut a Release

Create a versioned release from delivered plans. This workflow can be run manually (using git and forge CLI), by an AI agent interpreting this skill, or via a workflow script (once available).

**Input:** `$ARGUMENTS` is optional. Can be:
- `rc` — cut a release candidate tag and generate a verification checklist
- A version number (e.g., `1.2.0`) or bump type (`major`, `minor`, `patch`) — cut the final release

Examples: `/plot-release rc`, `/plot-release minor`, `/plot-release 1.2.0`

## Setup

Add a `## Plot Config` section to the adopting project's `CLAUDE.md`:

    ## Plot Config
    - **Project board:** <your-project-name> (#<number>)  <!-- optional, for `gh pr edit --add-project` -->
    - **Branch prefixes:** idea/, feature/, bug/, docs/, infra/
    - **Plan directory:** docs/plans/
    - **Archive directory:** docs/archive/

### 1. Determine Version

Check for the latest git tag:

```bash
git tag --sort=-v:refname | head -1
```

If `$ARGUMENTS` is `rc`:
- Determine the target version (same rules as below — check delivered plans, suggest bump type)
- Check for existing RC tags for this version: `git tag --list "v<version>-rc.*"`
- Next RC number: if no existing RCs, use `rc.1`; otherwise increment
- Proceed to **step 2A (RC path)**

If `$ARGUMENTS` specifies a version (e.g., `1.2.0`):
- Use it directly (validate it's valid semver)
- Proceed to **step 2B (final release path)**

If `$ARGUMENTS` specifies a bump type (`major`, `minor`, `patch`):
- Calculate the new version from the latest tag
- Proceed to **step 2B (final release path)**

If `$ARGUMENTS` is empty:
- Check if there's an open RC checklist (`docs/releases/v*-checklist.md`) with all items checked
- If yes: propose cutting the final release for that version
- If no: look at delivered plans since the last release to suggest a bump type:
  - Any features → suggest `minor`
  - Only bug fixes → suggest `patch`
  - Breaking changes noted in changelogs → suggest `major`
- Propose the version and confirm with the user

### 2A. RC Path — Cut Release Candidate

**Tag the RC:**

```bash
git tag -a v<version>-rc.<n> -m "Release candidate v<version>-rc.<n>"
git push origin v<version>-rc.<n>
```

**Generate verification checklist:**

Collect all archived plans since the last release (same discovery as step 2B). For each delivered feature or bug plan, extract the `## Changelog` section and create a checklist item.

```bash
mkdir -p docs/releases
```

Write `docs/releases/v<version>-checklist.md`:

```markdown
# Release Checklist — v<version>

RC: v<version>-rc.<n> (YYYY-MM-DD)

## Verification

- [ ] <feature/bug slug> — <changelog summary>
- [ ] <feature/bug slug> — <changelog summary>

## Automated Tests

- [ ] CI passes on RC tag

## Sign-off

- [ ] All items verified by: ___
- [ ] Final release approved by: ___
```

```bash
git add docs/releases/v<version>-checklist.md
git commit -m "release: v<version>-rc.<n> checklist"
git push
```

**Summary (RC):**
- RC tag: `v<version>-rc.<n>`
- Checklist: `docs/releases/v<version>-checklist.md`
- Plans included: list of slugs
- Next: test against checklist. If bugs found, fix via normal `bug/` branches, merge, then run `/plot-release rc` again for next RC. When all items pass, run `/plot-release` to cut the final release.

### 2B. Final Release Path — Generate Release Notes

Check for project-specific release note tooling, then either run it or fall back to manual collection.

**Discover tooling** — check in this order:

1. **Changesets:** Does `.changeset/config.json` exist? If so, the project uses `@changesets/cli`.
2. **Project rules:** Read `CLAUDE.md` and `AGENTS.md` for release note instructions (e.g., custom scripts, specific commands).
3. **Custom scripts:** Check `package.json` for release-related scripts (e.g., `release`, `version`, `changelog`).

**If tooling is found:** run it to generate/update the changelog and bump the version. For changesets: `pnpm exec changeset version` (consumes `.changeset/*.md` files, updates `CHANGELOG.md`, bumps `package.json`). Then skip ahead to step 3 (cross-check).

**If no tooling is found:** collect changelog entries manually from delivered plans:

```bash
# Get the date of the last release tag (exclude RC tags)
LAST_TAG=$(git tag --sort=-v:refname | grep -v '\-rc\.' | head -1)
if [ -n "$LAST_TAG" ]; then
  LAST_RELEASE_DATE=$(git log -1 --format=%ai "$LAST_TAG" | cut -d' ' -f1)
else
  LAST_RELEASE_DATE="1970-01-01"
fi

# Find archived plans newer than the last release
# (archived plans have date prefix: YYYY-MM-DD-<slug>.md)
ls docs/archive/*.md
```

For each archived plan since the last release:
1. Read the `## Changelog` section
2. Read the `## Status` section for the **Type** (feature/bug/docs/infra)
3. Collect the changelog entries

Only include feature and bug plans in the release notes (docs/infra are live when merged — they don't need release).

Write or update `CHANGELOG.md` with the new version entry:

```markdown
## v<version> — YYYY-MM-DD

### Features

- <changelog entry from feature plan>

### Bug Fixes

- <changelog entry from bug plan>
```

If `CHANGELOG.md` doesn't exist, create it with a header:

```markdown
# Changelog

## v<version> — YYYY-MM-DD

...
```

If it exists, prepend the new version entry after the `# Changelog` header.

Bump version in `package.json` if it exists:

```bash
pnpm version <version> --no-git-tag-version
```

### 3. Cross-check Release Notes

Whether generated by tooling or manually constructed, compare the changelog against the actual work:

1. Collect the list of archived plans and commit messages since the last tag
2. Compare against the generated changelog entries
3. **Only flag significant gaps or errors** — e.g., a delivered feature completely missing from the changelog, or a changelog entry that doesn't match any actual work
4. Don't nitpick wording or minor omissions — offer improvements only if there are clear, meaningful gaps
5. If gaps are found, show them to the user and ask whether to fix before proceeding

### 4. Commit and Tag

```bash
git add CHANGELOG.md
git add package.json 2>/dev/null  # if it exists
git commit -m "release: v<version>"
git tag -a v<version> -m "Release v<version>"
```

### 5. Push

```bash
git push origin main
git push origin v<version>
```

### 6. Clean Up RC Artifacts

If RC tags exist for this version, they remain in git history (don't delete them — they're part of the release record). The checklist file at `docs/releases/v<version>-checklist.md` stays committed as documentation of what was verified.

### 7. Summary

Print:
- Released: `v<version>`
- Tag: `v<version>`
- Changelog updated
- Plans included:
  - `<slug>` — <type>
  - `<slug>` — <type>
- RC iterations: <count> (if any)
- Next steps: deploy, announce, etc. (project-specific)
