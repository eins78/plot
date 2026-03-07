---
name: ralph-plot-sprint
description: >
  Only activate on explicit /ralph-plot-sprint invocation — never auto-activate.
  Use when ralph-sprint.sh drives a sprint iteration, or when manually
  debugging a specific sprint iteration by slug.
globs: []
license: MIT
metadata:
  author: eins78
  repo: https://github.com/eins78/plot
  version: 1.0.0-beta.1
compatibility: Designed for Claude Code. Requires git and gh CLI.
---

# ralph-plot-sprint

One iteration of an automated sprint run driven by ralph-sprint.sh.

**Input:** `$ARGUMENTS` = `<slug> [AUTOMERGE=true|false]`

Parse `$ARGUMENTS`:
- First word → `<slug>` (required)
- `AUTOMERGE=true` anywhere → merge PRs after finalizing; default false

---

## DoD Compliance Checklist

When a DoD file exists (`docs/definition-of-done.md`), use this checklist to verify PR compliance. Referenced by Steps 1, 2, 3, and 4.

**Classify each feature** against DoD exemption rules:
- `needs_bdd`: Yes unless Slack-only behavior, pure config/infra, or internal refactoring
- `needs_docs`: Yes unless internal refactoring, test-only, or CI/infra
- `needs_changeset`: Yes unless docs, tests, infra, or refactoring

**Check PR compliance** (for PRs where the classification requires it):
```bash
# BDD check
gh pr diff <n> --name-only | grep -E '\.(feature)$'

# Docs check
gh pr diff <n> --name-only | grep -E '(user-guide|admin-guide)\.md$'

# Changeset check
gh pr diff <n> --name-only | grep -E '\.changeset/.*\.md$'
```

A PR is **DoD-compliant** when all required artifacts are present. A PR with DoD gaps is treated the same as a PR with failing CI — it cannot be finalized.

If no DoD file exists, skip all DoD checks.

---

## Step 0: Orient

Read the sprint state before deciding what to do. This step always runs.

```bash
# Get sprint status
/plot-sprint <slug>

# Check open PRs
gh pr list --state open --json number,title,headRefName,baseRefName,isDraft \
  --jq '.[] | "\(.number) \(if .isDraft then "DRAFT" else "READY" end) \(.headRefName) \(.title)"'
```

**Read the project's Definition of Done** if it exists:
```bash
cat docs/definition-of-done.md 2>/dev/null || echo "(no DoD file)"
```

**Build a state summary:**

| Check | Command | Result |
|-------|---------|--------|
| Unchecked items | grep `- [ ]` in sprint file | List or "none" |
| Plan branch progress | For each unchecked `[slug]` item: read plan file, find heading containing "Branches", cross-reference with `gh pr list --state all` | e.g., "prod-config: 1/7 branches merged" or "no branches section" |
| Open PRs | `gh pr list --state open` | List or "none" |
| Failing CI | `gh pr checks <n>` per open PR | List or "all green" |
| Unresolved comments | `gh api ...pulls/<n>/comments` per open PR | List or "none" |
| DoD compliance | Run DoD Compliance Checklist for each open PR | Gaps or "all compliant" |
| Missing demos | compare sprint code items to `ls docs/demos/` | List or "all present" |
| RC tag | `git tag --list 'v*-rc*'` | Tag or "none" |

**Reading plan branches:** Find the plan file via `docs/plans/active/<slug>.md` or `docs/plans/delivered/<slug>.md` (resolve symlink). Search for a heading containing "Branches" (matches `## Branches`, `## Implementation Branches`, `### Implementation Branches`). Parse branch names from lines starting with `- ` followed by a backtick-quoted branch name. For each branch, check if a PR exists and its state (MERGED/OPEN/CLOSED) via `gh pr list --state all --head <branch-name>`.

**For sprints with more than 3 open PRs:** use parallel subagents to gather CI and review status. Launch one Task agent per PR with the prompt below, collect all results before proceeding:

```
Check PR #<N> in repo <owner/repo>:
1. Run: gh pr checks <N> --repo <owner/repo>
   Return: "CI: pass" or "CI: fail — <failing check names>"
2. Run: gh api repos/<owner/repo>/pulls/<N>/reviews
   and: gh api repos/<owner/repo>/pulls/<N>/comments
   Return: "reviewed: yes" or "reviewed: no", "unresolved: <count>"
3. Check sprint item annotation for review_sha:
   Return: "SHA changed since review: yes/no"
```

**After orienting, pick ONE step for this iteration — the first match wins:**
- If open PRs have failing CI, unresolved comments, **or DoD compliance gaps** → **Step 1 only**
- If open PRs are ready to finalize (green CI, reviewed, no unresolved, **DoD-compliant**) → **Step 2 only**
- If unchecked sprint items have undelivered plan branches (or no open PR yet) → **Step 3 only**
- If open code PRs have no review comments → **Step 4 only**
- If missing demos for merged features → **Step 5 only**
- If RC tagged but commits exist after latest RC tag (`git log $(git tag -l 'v*-rc*' --sort=-v:refname | head -1)..HEAD --oneline | head -1`) → **Step 6 only** (re-tag)
- If RC not yet tagged and all demos present → **Step 6 only**
- Otherwise (no open PRs, no unchecked items, demos present, RC tagged, no post-RC commits) → output BLOCKED (sprint is complete pending human testing)

**CRITICAL: Do exactly ONE step per iteration.** Do not cascade into subsequent steps. Each iteration is cheap — doing less per iteration keeps work focused, reviewable, and recoverable. After completing your one step, write the iteration summary and exit.

---

## Step 1: Fix CI, Unresolved Comments, and DoD Gaps

For each open PR with failing CI or unresolved review comments:

**Failing CI:**
1. `gh pr checks <n>` to identify failing checks
2. `gh pr diff <n>` + read error output to understand the failure
3. Fix the underlying code issue, push
4. Reply to any related review comments explaining the fix

**Unresolved comments:**
1. `gh api repos/<owner>/pulls/<n>/comments` to list open threads
2. For each: read the comment, fix the underlying issue in code
3. Push the fix
4. Reply to the comment explaining what was done
5. Resolve the thread: `gh api repos/<owner>/pulls/<n>/comments/<id> --method PATCH -f body="Resolved in <sha>"`

Retry transient failures (network, flaky tests) up to 3 times before marking as blocked.

**DoD gaps** (from Step 0 compliance check — see DoD Compliance Checklist):

*Missing BDD scenarios* (`needs_bdd` but no `.feature` files in PR):
1. Read the feature's behavior from PR diff and linked plan
2. Write Gherkin scenarios in `tests/e2e/features/`
3. Write step definitions (playwright-bdd)
4. Run tests — verify scenarios fail (red) then pass after existing code (green)
5. Push to the PR branch

*Missing documentation* (`needs_docs` but no guide updates in PR):
1. Determine whether user guide, admin guide, or both need updates
2. Add the relevant section(s)
3. Push to the PR branch

*Missing changeset* (`needs_changeset` but no `.changeset/*.md` in PR):
1. Write `.changeset/<name>.md` with appropriate bump level
2. Push to the PR branch

---

## Step 2: Finalize Ready PRs

Finalize PRs that have: green CI + zero unresolved comments + at least one prior review + **no DoD compliance gaps** (see DoD Compliance Checklist).

**Do NOT merge any PR with DoD gaps.** If a PR is missing BDD scenarios, documentation, or changesets required by the DoD, it is not ready — route it to Step 1 in the next iteration.

**Order matters:** finalize PRs whose base branch is `main` first. For PRs based on other feature branches, wait until that base branch is merged, then rebase.

```bash
# Mark draft → ready
gh pr ready <n>

# If AUTOMERGE=true:
gh pr merge <n> --squash

# After merging a base-branch PR, rebase PRs that depended on it:
git fetch origin
git checkout -b <dependent-branch> origin/<dependent-branch>
git rebase origin/main
git push --force-with-lease
```

If AUTOMERGE=false: mark ready and stop — leave merging for the human.

**If AUTOMERGE=false and all open PRs are already READY + green CI + reviewed** (no drafts, no failing CI, no unresolved comments, no new commits since last review): output BLOCKED — no further automation is possible until the human merges.

---

## Step 3: Build One Sprint Task

If work remains in the sprint (unchecked items with undelivered plan branches or no open PR), implement one unit of work.

**Rules:**
- At most ONE branch per iteration
- Before implementing: search the codebase — do not assume functionality is missing
- Plan-only items (no implementation needed, just docs): mark complete on main without a PR — NEVER create `feature/*` for plan-only work
- Substantial new tasks with no plan: use `/plot-idea` first
- Small tasks (docs, config, minor fixes): implement directly

**For plan-backed items (`[slug]` notation):**

1. Check if the plan is approved; if not, run `/plot-approve` or output BLOCKED
2. **Read the plan's branches section** (find heading containing "Branches"). Parse branch names and descriptions.
3. **Cross-reference with GitHub** to find which branches already have merged PRs:
   ```bash
   gh pr list --state all --json headRefName,state --jq '.[] | select(.headRefName | startswith("feature/"))'
   ```
4. **Pick the NEXT undelivered branch** — the first branch in the list without a merged PR. If ALL branches are delivered, do not build — instead run `/plot-deliver <slug>` to formally deliver the plan and check the sprint item.
5. If the plan has **no branches section** (lightweight plan): treat as single-scope, implement as `feature/<slug>`.

**Implementation sequence** (follows project DoD if present):

1. **Classify** against DoD Compliance Checklist: does this branch need BDD? docs? changeset?
2. **If BDD required** — write Gherkin scenarios FIRST (red-green discipline). Run tests, confirm they fail.
3. **Implement** the feature (green phase). Inner TDD loop: unit test → implement → refactor.
4. **If docs required** — update user/admin guide in the same PR.
5. **Add changeset** if required.
6. **Run full test suite.** All tests must pass.
7. **Create PR** with all artifacts in a single PR.

**NEVER check a sprint item `[x]` in this step.** Only `/plot-deliver` marks sprint items complete — after ALL plan branches are delivered.

---

## Step 4: Self-Review Unreviewed Code PRs

Review open PRs that have NO review comments at all. PRs with existing comments (even all resolved) count as already reviewed.

**Skip review if:**
- PR already has any review comments (resolved or open)
- `review_sha` annotation matches current HEAD SHA of the branch (no new commits)
- PR contains only `docs/plans/` files (plan-only — do a single light factual check instead)
- PR status annotation shows `merged`

**For code PRs:** use `/pr-review-toolkit:review-pr`. Post each finding as an individual PR review comment via `gh api`. Be specific and harsh — vague comments waste iterations.

**DoD compliance review** (in addition to code quality):
If a DoD file exists, check each PR against the DoD Compliance Checklist and post findings as review comments:
- Missing BDD scenarios → comment: "DoD: Missing BDD scenarios for this feature."
- Missing docs → comment: "DoD: Missing documentation updates."
- Missing changeset → comment: "DoD: Missing changeset."
These become Step 1 work in the next iteration.

**Do NOT fix findings in this step** — post only. Fixing is Step 1 of the next iteration.

**After reviewing:** update the sprint item annotation with `review_sha` and `reviewed_at`.

---

## Step 5: Create Missing Demos

For each merged code feature without a demo in `docs/demos/`:

**Identify plan-only items** — these do NOT need demos:
- Sprint items annotated `status: merged` with a `docs/plans/` PR (no implementation code)
- Items explicitly marked plan-only in the sprint file

**For each code feature needing a demo:**
1. Use `/show-your-work` to create the demo
2. The demo must include:
   - What the feature does
   - Evidence it works (test output, command output, config snippet)
   - If `docs/definition-of-done.md` has specific requirements for this feature type, follow them
3. Commit to main with message `D demo: <feature-name>`

Up to **2 demos per iteration** — avoids context overload for complex features.

Check after creating: are all code features now covered? If yes, proceed to Step 6.

---

## Step 6: Tag RC Release

When all code features have demos (verify by comparing sprint items to `docs/demos/`):

```bash
/plot-release rc
```

This determines the version bump, tags the RC, creates a verification checklist in `docs/releases/`, and pushes.

After `/plot-release rc` completes:

```
<promise>BLOCKED</promise>
```

The sprint is BLOCKED because the RC requires human testing. Do not output COMPLETE.

---

## Promise Signals

Write a one-paragraph summary of what you accomplished this iteration, then output exactly one signal on its own line:

| Signal | When | Loop effect |
|--------|------|-------------|
| `<promise>COMPLETE</promise>` | All sprint tasks done, all PRs finalized, all demos created, RC tagged | Loop exits, notifies human |
| `<promise>BLOCKED</promise>` | Truly stuck: unresolvable rebase conflict, RC tagged (awaiting human testing), needs human decision | Loop exits, notifies human |
| *(no signal)* | Did useful work, more to do | Loop continues to next iteration |

**Do NOT output BLOCKED just because you posted review comments** — fixing those is the next iteration's job.

**Output COMPLETE only when** the project's DoD is fully satisfied:
- If `docs/definition-of-done.md` exists: check every criterion in it
- If no DoD file: all PRs finalized per the AUTOMERGE setting, all CI green

---

## Common Mistakes

| Mistake | Effect | Prevention |
|---------|--------|------------|
| Running against a sprint in `Phase: Draft` | No items to work on; loop exhausts iterations | Check `Phase:` field in Step 0; output BLOCKED if not started |
| Outputting BLOCKED after posting review comments | Loop exits; human must restart | BLOCKED only when truly stuck — review comments are normal iteration work |
| Doing multiple steps in one iteration | Work is unfocused, harder to review, riskier to recover from | ONE step per iteration — the first matching step wins, then exit |
| Building a new task when unreviewed PRs exist | Step 4 is skipped; review debt accumulates | Step ordering is strict: fix → finalize → build → review |
| Creating `feature/` branch for plan-only work | Wasted PR, confuses sprint state | Plan-only items commit directly to main |
| Working in a stale worktree | New sprint items/merged PRs invisible to agent | ralph-sprint.sh now refreshes worktrees before the loop; if running manually, `git worktree remove` first |
| Declaring BLOCKED with existing RC when new commits exist | RC is stale, needs re-tagging | Step 0 checks for commits after latest RC tag |
| Checking `[x]` on a sprint item from ralph-plot-sprint | Plan branches left undelivered | NEVER check `[x]` — only `/plot-deliver` marks items complete |
| Implementing "the whole plan" in one PR | Monolithic PR, misses plan's branch decomposition | Implement ONE branch per iteration — plans decompose for a reason |
| Merging a PR with DoD gaps | BDD/docs permanently missing from the codebase | Step 2 gates on DoD compliance; Step 4 flags gaps as review comments |
| Skipping BDD for a non-exempt feature | DoD violation | Classify against DoD exemptions in Step 3 before implementing |
