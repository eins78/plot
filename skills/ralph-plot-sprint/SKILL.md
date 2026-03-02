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
  repo: https://github.com/eins78/skills
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
| Open PRs | `gh pr list --state open` | List or "none" |
| Failing CI | `gh pr checks <n>` per open PR | List or "all green" |
| Unresolved comments | `gh api ...pulls/<n>/comments` per open PR | List or "none" |
| Missing demos | compare sprint code items to `ls docs/demos/` | List or "all present" |
| RC tag | `git tag --list 'v*-rc*'` | Tag or "none" |

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

**After orienting, decide which steps apply this iteration:**
- If open PRs exist → start at Step 1
- If unchecked sprint items exist (no open PR yet) → go to Step 3
- If missing demos → go to Step 5
- If RC not yet tagged → go to Step 6
- Otherwise (no open PRs, no unchecked items, demos present, RC tagged) → output BLOCKED (sprint is complete pending human testing)

---

## Step 1: Fix CI and Unresolved Comments

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

---

## Step 2: Finalize Ready PRs

Finalize PRs that have: green CI + zero unresolved comments + at least one prior review.

**Order matters:** finalize PRs whose base branch is `main` first. For PRs based on other feature branches, wait until that base branch is merged, then rebase.

```bash
# Mark draft → ready
gh pr ready <n>

# If AUTOMERGE=true:
gh pr merge <n> --squash

# After merging a base-branch PR, rebase PRs that depended on it:
git fetch origin
git checkout <dependent-branch>
git rebase origin/main
git push --force-with-lease
```

If AUTOMERGE=false: mark ready and stop — leave merging for the human.

**If AUTOMERGE=false and all open PRs are already READY + green CI + reviewed** (no drafts, no failing CI, no unresolved comments, no new commits since last review): output BLOCKED — no further automation is possible until the human merges.

---

## Step 3: Build One Sprint Task

If work remains in the sprint (unchecked items with no open PR), implement the highest-priority unblocked item.

**Rules:**
- At most ONE new task per iteration (steps 1-2 and 4 apply to all PRs; this step is singular)
- Before implementing: search the codebase — do not assume functionality is missing
- Plan-backed items (`[slug]` notation): check if the plan is approved; if not, run `/plot-approve` or output BLOCKED
- Plan-only items (no implementation needed, just docs): mark complete on main without a PR — NEVER create `feature/*` for plan-only work
- Substantial new tasks with no plan: use `/plot-idea` first
- Small tasks (docs, config, minor fixes): implement directly

Implement → run tests and type-check → create PR with changeset if user-facing.

---

## Step 4: Self-Review Unreviewed Code PRs

Review open PRs that have NO review comments at all. PRs with existing comments (even all resolved) count as already reviewed.

**Skip review if:**
- PR already has any review comments (resolved or open)
- `review_sha` annotation matches current HEAD SHA of the branch (no new commits)
- PR contains only `docs/plans/` files (plan-only — do a single light factual check instead)
- PR status annotation shows `merged`

**For code PRs:** use `/pr-review-toolkit:review-pr`. Post each finding as an individual PR review comment via `gh api`. Be specific and harsh — vague comments waste iterations.

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
| Building a new task when unreviewed PRs exist | Step 4 is skipped; review debt accumulates | Step ordering is strict: fix → finalize → build → review |
| Creating `feature/` branch for plan-only work | Wasted PR, confuses sprint state | Plan-only items commit directly to main |
