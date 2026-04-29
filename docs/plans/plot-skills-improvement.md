# Plot skills improvement plan

Source: [eins78/plot#2](https://github.com/eins78/plot/issues/2) (read 2026-04-29)

## Summary

Eight distinct feedback items across one issue body and three follow-up comments, all originating from real-world `/plot-sprint` runs against `eins78/qubert`. Seven are actionable; one (BDD gate in `ralph-plot-sprint` Step 3) was filed early and is now already covered by the current skill text. The two skills most affected are `plot-sprint` (six items) and `ralph-plot-sprint` (one item, already addressed). Two broad themes emerge: (1) sprints don't have a PR-aware lifecycle even though Max naturally wants to review sprint plans on a PR before committing scope; (2) phase guardrails leak — "checked checkbox" and "PR merged" both get treated as proxies for delivery without the underlying check, and phase transitions happen via informal git work instead of through the named subcommands. Both themes map directly to manifesto Principle 7 ("Phase guardrails").

## Feedback items

Numbered sequentially. Original numbering in the issue restarts in each comment — `Source` notes the comment URL or "issue body".

### 1. Sprint create immediately jumped to Active (skipped Committed)

- **Source**: issue body, observation 1
- **Affected skill(s)**: `plot-sprint`
- **What Max observed**: After `/plot-sprint go-live: Go-Live` created the sprint on main (correct), the user said "start a PR" — and the agent set the phase to Active and created the active symlink, skipping the Committed phase entirely. The agent conflated "open a draft PR" with `/plot-sprint <slug> start`.
- **Why it matters**: Manifesto Principle 7 — phase guardrails. The lifecycle (Planning → Committed → Active → Closed) is explicit in the skill, but nothing in the skill *forbids* phase transitions outside the named subcommands. This is a silent guardrail leak: the skill describes what should happen, but doesn't say "only `commit`, `start`, and `close` may move the phase."
- **Proposed change**: Add an explicit "Phase Transition Rule" section to `skills/plot-sprint/SKILL.md`, immediately under the existing `## Guardrail` block at line 75–77. Promote the rule from implicit to explicit.

  Current text — `skills/plot-sprint/SKILL.md:75-77`:
  ```markdown
  ## Guardrail

  Sprint files must not contain `## Design` or `## Approach` sections. If detected, warn: "This looks like a plan, not a sprint. Use `/plot-idea` for plans."
  ```

  Proposed text:
  ```markdown
  ## Guardrails

  ### Plan vs Sprint

  Sprint files must not contain `## Design` or `## Approach` sections. If detected, warn: "This looks like a plan, not a sprint. Use `/plot-idea` for plans."

  ### Phase Transitions

  The `Phase` field is only updated by named subcommands: `commit`, `start`, `close`. Any other action — opening a PR for review, refining items, adjusting dates, fixing typos — leaves the phase unchanged. If the user says "start a PR for the sprint", that means open a draft PR for plan review, not `/plot-sprint <slug> start`. When in doubt, ask which subcommand the user means.
  ```

  Also update the `## Sprint Lifecycle` mermaid block (line 65–73) labels to underscore that the named subcommand is the *only* trigger — already true, but the explicit rule above makes the diagram self-enforcing.

- **Risk / open question**: This is purely a guidance addition; no behavior change. The only risk is verbosity — guardrails are most effective when they're easy to find. The proposed wording places the rule one section above the subcommands, where readers will hit it before reading any specific subcommand.

### 2. Sprint file committed to main, but PR needs a diff

- **Source**: issue body, observation 2
- **Affected skill(s)**: `plot-sprint`
- **What Max observed**: The skill instructs creating the sprint file directly on main (Step 7 of Create). After commit, when the user wanted a draft PR for review, the feature branch was identical to main — no diff, GitHub rejected the PR. The skill says "commit directly to main" *and* the user wants a PR; those two instructions conflict.
- **Why it matters**: This is the operational evidence behind themes A (Sprint PR lifecycle) and the manifesto's "Plans merge before implementation" — sprint planning has the same dynamic as plan refinement (multiple revisions, decisions to defer items, dates negotiated) and benefits from the same git-native review surface, but the skill currently treats sprints as one-shot commits.
- **Proposed change**: Adopt option (b) from Max's writeup: keep the skeleton on main, route the *Planning* refinements through a draft PR. This preserves "sprints commit directly to main" for the initial creation but adds a recognized review step. Concretely:

  Current text — `skills/plot-sprint/SKILL.md:174-182` (Create step 7):
  ```markdown
  #### 7. Commit to Main

  Sprint files are committed directly to main (include any updated plan files):

  \`\`\`bash
  git add docs/sprints/${WEEK_PREFIX}-<slug>.md docs/plans/
  git commit -m "sprint: create <slug>"
  git push
  \`\`\`
  ```

  Proposed text:
  ```markdown
  #### 7. Commit Skeleton to Main

  Commit the initial sprint skeleton directly to main:

  \`\`\`bash
  git add docs/sprints/${WEEK_PREFIX}-<slug>.md docs/plans/
  git commit -m "sprint: create <slug>"
  git push
  \`\`\`

  Refinement (fleshing out items, readiness assessments, deferrals) happens optionally on a `sprint/<slug>` branch with a draft PR — see "Refine via PR (optional)" below.
  ```

  Add a new subsection between Create and Commit:
  ```markdown
  ### Refine via PR (optional)

  Once the skeleton is on main, sprint refinement can move to a `sprint/<slug>` feature branch with a draft PR. This is optional — small or solo sprints can stay on main. Use a PR when:

  - Multiple stakeholders need to review scope before locking
  - Readiness assessments or deferral decisions deserve their own commits in history
  - The sprint is large enough that scope conversations benefit from inline comments

  Workflow:

  1. `git checkout -b sprint/<slug> origin/main`
  2. Refine the sprint file on the branch (one commit per substantive change — readiness, defer X, set dates)
  3. `gh pr create --draft --title "Sprint: <goal>" --body "..."` — keep as draft while in Planning phase
  4. Phase stays `Planning` throughout. Do NOT change the phase here.
  5. When the team agrees: run `/plot-sprint <slug> commit` (see Commit subcommand for PR-aware behavior).
  ```

  This is paired with item 6 below — the `commit` subcommand becomes PR-aware so the merge itself is the phase transition.

- **Risk / open question**: Adding a branch+PR path makes the skill's lifecycle slightly more complex. Counter-balanced by being optional. Open question: should the refinement branch be `sprint/<slug>` or `idea/sprint-<slug>` (re-using the idea/ prefix)? `sprint/` is clearer and parallels `feature/`, `bug/`, etc. Recommend adding `sprint/` to the branch-prefix list in `## Plot Config` if Max prefers explicitness, but prefix-discipline isn't strictly required by Plot's hub.

### 3. No guidance on PR workflow for sprints

- **Source**: issue body, observation 3
- **Affected skill(s)**: `plot-sprint`
- **What Max observed**: The skill covers create/commit/start/close subcommands but says nothing about PRs. In practice a draft PR is the natural way to get feedback on a sprint plan.
- **Why it matters**: Same root as item 2 — sprints have a planning step that benefits from review, and the skill currently has no documented surface for it. Without guidance, agents improvise (badly, per item 1). With guidance, behavior is predictable.
- **Proposed change**: This is mostly satisfied by the new "Refine via PR (optional)" subsection proposed in item 2. In addition, add a one-line acknowledgement at the top of `skills/plot-sprint/SKILL.md` that the "no PR workflow" promise in the frontmatter is now refined.

  Current text — `skills/plot-sprint/SKILL.md:12`:
  ```markdown
  compatibility: Designed for Claude Code and Cursor. Requires git. Sprint files are committed directly to main — no PR workflow.
  ```

  Proposed text:
  ```markdown
  compatibility: Designed for Claude Code and Cursor. Requires git. Sprint skeletons commit directly to main; planning refinement may optionally go through a draft PR (see "Refine via PR").
  ```

  Also update the explanation paragraph at line 17:

  Current — `skills/plot-sprint/SKILL.md:17`:
  ```markdown
  Sprints are **not plans**. Plans track *what* to build; sprints track *when* to ship it. Sprint files live in `docs/sprints/`, committed directly to main — no PR, no review gate. Principle 2 ("Plans merge before implementation") does not apply to sprints.
  ```

  Proposed:
  ```markdown
  Sprints are **not plans**. Plans track *what* to build; sprints track *when* to ship it. Sprint files live in `docs/sprints/`. The initial skeleton commits directly to main; subsequent Planning-phase refinement may optionally happen on a `sprint/<slug>` branch with a draft PR for review. Principle 2 ("Plans merge before implementation") does not apply to sprints — sprints don't spawn implementation branches — but the *refinement* benefits from the same review surface.
  ```

- **Risk / open question**: None significant. Items 2 + 3 + 5 + 6 form a coherent unit and should ship together; landing them piecemeal would leave the skill in a confusing intermediate state.

### 4. Slug parsing edge case with multiline input

- **Source**: issue body, observation 4
- **Affected skill(s)**: `plot-sprint`
- **What Max observed**: Input was `go-live: Go-Live\nlet's get ready...` — slug=`go-live` and goal=`Go-Live` parsed correctly, but the long description after the first line was treated as part of goal context rather than handled explicitly. Max calls this "Minor" — works fine in practice.
- **Why it matters**: Low-stakes documentation gap. The skill's parse rules at `skills/plot-sprint/SKILL.md:88-94` only describe the single-line form.
- **Proposed change**: Add one paragraph to the Parse Input step describing multiline behavior.

  Current text — `skills/plot-sprint/SKILL.md:87-94`:
  ```markdown
  #### 1. Parse Input

  Extract `<slug>` (before the colon) and `<goal>` (after the colon). Both are required.

  - Slug: trimmed, lowercase, hyphens only
  - Goal: the sprint goal as a sentence

  If no colon or missing parts: "Usage: `/plot-sprint <slug>: <goal>`"
  ```

  Proposed addition immediately after:
  ```markdown
  **Multiline input:** If `$ARGUMENTS` contains newlines, the first line is parsed for slug + goal as above. Any subsequent lines are treated as **context for the goal** (e.g., motivation, scope hints) and become the body of the `## Sprint Goal` section in the new sprint file — not the one-line `> <sprint goal>` headline.
  ```

- **Risk / open question**: This is a documentation-only nudge. No code path changes. The only judgment call is whether multi-line context becomes the `## Sprint Goal` section body or shows up as a comment block; the proposal picks the more useful default.

### 5. Squash merge loses sprint planning history

- **Source**: [comment dated 2026-02-14, observation 5](https://github.com/eins78/plot/issues/2#issuecomment-4057881078)
- **Affected skill(s)**: `plot-sprint` (new), `plot-approve` (cross-reference confirmation)
- **What Max observed**: When merging the sprint planning PR (`eins78/qubert#28`), the agent used `--squash`, collapsing all planning commits (readiness assessment, deferral of slack-buttons, date fixes) into one commit. Same root as `eins78/skills#4` for plan PRs.
- **Why it matters**: Planning commits are *meaningful history*. The squash collapses the trail of "what was considered, what was deferred and why." `plot-approve` already explicitly defaults to merge commits for plan PRs (`skills/plot-approve/SKILL.md:112`); sprint PRs need the same defaulting once they exist (item 2/3).
- **Proposed change**: When the new "Refine via PR (optional)" subsection is added (per item 2), make merge strategy explicit and copy the wording already proven in `plot-approve`. Inside the new Commit subcommand behavior (see also item 6):

  Proposed text in the new commit-subcommand wording (replaces / extends `skills/plot-sprint/SKILL.md:222-227`):
  ```markdown
  When a `sprint/<slug>` PR exists for this sprint, prefer:

  \`\`\`bash
  gh pr merge <number> --merge --delete-branch
  \`\`\`

  Default to **merge commits** to preserve granular planning history (readiness, deferrals, scope changes are valuable context). If the project's `CLAUDE.md` specifies a different merge strategy, follow that instead. Do NOT default to `--squash` — it collapses the planning trail.
  ```

  Also add a one-line "Common Mistakes" entry at the bottom of `skills/plot-sprint/SKILL.md` (matching the pattern in `ralph-plot-sprint/SKILL.md:339-353`):

  ```markdown
  ## Common Mistakes

  | Mistake | Effect | Prevention |
  |---------|--------|------------|
  | Squash-merging a sprint planning PR | Readiness/defer/dates collapse into one commit; reasoning lost | Default to `--merge` (matches `plot-approve` for plan PRs) — squash is for messy WIP, not planning |
  ```

- **Risk / open question**: Adding a Common Mistakes table to `plot-sprint` introduces a new section. Worth the 4 lines — it's the same convention `ralph-plot-sprint` already uses, and item 1 + this entry are both "guardrail discipline" notes.

### 6. Phase transition to Committed should happen in the PR

- **Source**: [comment dated 2026-02-14, observation 6](https://github.com/eins78/plot/issues/2#issuecomment-4057881078)
- **Affected skill(s)**: `plot-sprint`
- **What Max observed**: The sprint planning PR was merged while still in `Planning`; a separate commit on main then bumped to `Committed`. Two operations where one would do.
- **Why it matters**: One round-trip vs two for the same conceptual transition (scope-locked). Also tightens the rule from item 1: "PR merge = scope locked = Committed phase" is exactly the kind of named transition Plot wants. Currently the agent has to do the phase bump in a follow-up commit — exactly the kind of out-of-band phase change item 1 forbids.
- **Proposed change**: Make `/plot-sprint <slug> commit` PR-aware. If a `sprint/<slug>` PR is open, the commit subcommand updates the phase **on the PR branch** then merges; if not, behavior is unchanged.

  Current text — `skills/plot-sprint/SKILL.md:218-227` (Commit subcommand steps 3–4):
  ```markdown
  #### 3. Update Phase

  Change `**Phase:** Planning` → `**Phase:** Committed`

  #### 4. Commit

  \`\`\`bash
  git add docs/sprints/*-<slug>.md
  git commit -m "sprint: commit <slug>"
  git push
  \`\`\`
  ```

  Proposed text:
  ```markdown
  #### 3. Detect Sprint PR

  Run `gh pr list --head sprint/<slug> --json number,state,isDraft --jq '.[]'`.

  - **PR exists and not merged:** proceed to step 4a (PR-aware commit)
  - **No PR / PR already merged:** proceed to step 4b (direct main commit)

  #### 4a. PR-Aware Commit

  Update phase **on the PR branch**, push, mark ready, merge:

  \`\`\`bash
  # Should already be on sprint/<slug> branch — confirm with: git branch --show-current
  # If not, check it out worktree-safe: git checkout -b sprint/<slug> origin/sprint/<slug>

  # Bump phase in the sprint file
  # **Phase:** Planning → **Phase:** Committed
  git add docs/sprints/*-<slug>.md
  git commit -m "sprint: commit <slug>"
  git push

  gh pr ready <number>          # if currently draft
  gh pr merge <number> --merge  # NOT --squash; preserves history per item 5
  \`\`\`

  The merge itself is the "scope locked" transition. No follow-up commit on main needed.

  #### 4b. Direct Main Commit (no PR)

  \`\`\`bash
  # Bump phase in the sprint file
  # **Phase:** Planning → **Phase:** Committed
  git add docs/sprints/*-<slug>.md
  git commit -m "sprint: commit <slug>"
  git push
  \`\`\`
  ```

  Renumber existing step 5 (Summary) accordingly.

- **Risk / open question**: This is the largest single edit in the plan. It is the natural pairing with items 2/3/5: once a PR path exists, the phase update belongs in the PR. Splitting items 2, 3, 5, 6 across separate edits would leave a confusing half-state — they should land together.

### 7. Step 3 doesn't mention BDD gate (`ralph-plot-sprint`)

- **Source**: [comment dated 2026-03-01, observation 5](https://github.com/eins78/plot/issues/2#issuecomment-4057881109)
- **Affected skill(s)**: `ralph-plot-sprint`
- **What Max observed**: At the time of writing (2026-03-01), `ralph-plot-sprint` Step 3 said "Implement → run tests → create PR with changeset" without mentioning BDD-first scenarios, so the agent would hit the `bdd-check.yml` CI gate retroactively.
- **Status**: **Already addressed.** The current `skills/ralph-plot-sprint/SKILL.md` (version 1.0.0-beta.2) has:

  - Step 0 reads `docs/definition-of-done.md` (line 70–73)
  - A full DoD Compliance Checklist (line 30–53) that classifies `needs_bdd` and gates Step 1, 2, 3, and 4
  - Step 3 implementation sequence (line 232–240) with item 2: *"If BDD required — write Gherkin scenarios FIRST (red-green discipline). Run tests, confirm they fail."*
  - "Skipping BDD for a non-exempt feature" entry in the Common Mistakes table (line 350)

  No new edits proposed for this item — flag it as resolved when triaging the issue, perhaps with a comment linking to the relevant lines.

- **Proposed change**: None. Recommend posting a follow-up comment on issue #2 noting the resolution and citing `skills/ralph-plot-sprint/SKILL.md:30-53,232-240` so the audit trail is clear.
- **Risk / open question**: Worth verifying with Max that the current DoD Compliance Checklist matches what he had in mind. The current text covers BDD, docs, and changesets uniformly, which is broader than the original "BDD-first" suggestion — that's an improvement, not a regression.

### 8. Sprint close doesn't detect plan-backed items that aren't actually delivered

- **Source**: [comment dated 2026-03-02, observation 5](https://github.com/eins78/plot/issues/2#issuecomment-4057881195)
- **Affected skill(s)**: `plot-sprint` (primary), `plot-deliver` (referenced for vocabulary)
- **What Max observed**: During `steal-features` sprint close, `worktree-isolation` was marked `[x]` because its plan PR (#38) merged. But `/plot-deliver` showed no implementation existed — only the plan file had merged. Plan was reverted to Draft. The MoSCoW completeness check counts `[x]` checkboxes only; for plan-backed items it should also check `docs/plans/delivered/<slug>.md` and surface mismatches.
- **Why it matters**: This is the highest-correctness-impact item. A green close hides undelivered work. The skill text already mentions checking delivery status (`skills/plot-sprint/SKILL.md:295`), but only as part of "counting completions" — there is no step that **flags the discrepancy** of `[x] but not delivered`.
- **Proposed change**: Promote the existing implicit check to an explicit gate in step 2 of `/plot-sprint <slug> close`. Also surface it in `/plot-sprint status` so users see it before they ever run `close`.

  Current text — `skills/plot-sprint/SKILL.md:290-308` (Close step 2):
  ```markdown
  #### 2. MoSCoW Completeness Check

  Parse the sprint file for checkbox items in each tier:

  - Count checked `- [x]` vs unchecked `- [ ]` items per tier
  - For plan-backed items (`[slug]`), check if the referenced plan is delivered (exists in `docs/plans/delivered/`)

  Present results:

  \`\`\`
  Must Have:  2/4 complete
  Should Have: 1/2 complete
  Could Have:  0/1 complete
  \`\`\`

  If must-haves are incomplete, present three options:
  1. Close anyway (must-haves stay unchecked in place)
  2. Move incomplete must-haves to Deferred — move each unchecked `- [ ]` line from `### Must Have` to `### Deferred`, preserving the original text
  3. Hold off (don't close yet)
  ```

  Proposed text:
  ```markdown
  #### 2. MoSCoW Completeness Check

  Parse the sprint file for checkbox items in each tier:

  - Count checked `- [x]` vs unchecked `- [ ]` items per tier
  - **For each `[x]` item with a `[slug]` reference, verify the plan is actually delivered:**
    - Check `docs/plans/delivered/<slug>.md` (file or symlink) exists
    - If the plan is in `docs/plans/active/<slug>.md` or missing entirely, this is a **false-positive completion**

  Present results, listing any false positives **before** the totals:

  \`\`\`
  ⚠ False-positive completions detected:
    - [slug] — checked but plan is in active/ (not delivered)
    - [slug] — checked but plan file not found

  Must Have:  2/4 complete (1 false positive)
  Should Have: 1/2 complete
  Could Have:  0/1 complete
  \`\`\`

  **If false positives exist, do NOT proceed to close until the user resolves them.** Present three options:
  1. **Run `/plot-deliver <slug>`** for each false-positive item (preferred — actually delivers the plan)
  2. **Uncheck the box** in the sprint file (acknowledges it's not really done)
  3. **Override and close anyway** (last resort; must include a `## Notes` entry explaining why)

  After false positives are resolved, continue with the regular Must-Have completeness flow:

  If must-haves are incomplete, present three options:
  1. Close anyway (must-haves stay unchecked in place)
  2. Move incomplete must-haves to Deferred — move each unchecked `- [ ]` line from `### Must Have` to `### Deferred`, preserving the original text
  3. Hold off (don't close yet)
  ```

  Mirror the false-positive detection in the Status subcommand. Current text — `skills/plot-sprint/SKILL.md:386-393`:
  ```markdown
  #### 2. For Each Sprint

  Read the sprint file and display:
  - Sprint name and goal
  - Phase
  - Time remaining (days until end date; "ended N days ago" if past)
  - MoSCoW progress: Must N/M, Should N/M, Could N/M
  - For plan-backed items with annotations: show PR number, status, and branch
  ```

  Proposed addition (new bullet):
  ```markdown
  - **False-positive flag:** for `[x]` items with `[slug]` refs, if the plan is not in `docs/plans/delivered/`, prefix the line with `⚠ ` and note `(plan not delivered)`. This makes the discrepancy visible during routine status checks, not just at close time.
  ```

  Update the Model Guidance table — `skills/plot-sprint/SKILL.md:54-58`:

  Current:
  ```markdown
  | Steps | Min. Tier | Notes |
  |-------|-----------|-------|
  | Create, commit, start, status | Small | Git commands, templates, file ops |
  | Close | Mid | Checkbox parsing + reading plan files to check delivery status of `[slug]` refs |
  ```

  Proposed:
  ```markdown
  | Steps | Min. Tier | Notes |
  |-------|-----------|-------|
  | Create, commit, start | Small | Git commands, templates, file ops |
  | Status | Small | File existence checks for delivery state are mechanical; no judgment needed |
  | Close | Mid | False-positive detection (cross-reference `[x]` against `docs/plans/delivered/`) plus existing checkbox parsing |
  ```

  Add to the new Common Mistakes table (introduced in item 5):
  ```markdown
  | Closing a sprint with `[x] [slug]` items whose plans are still in `active/` | Sprint reads as complete but plans remain undelivered; `/plot-deliver` later reverts the plan to Draft | Step 2 of close runs a false-positive check; resolve via `/plot-deliver` or uncheck before closing |
  ```

- **Risk / open question**: The proposed gate is a hard stop ("do NOT proceed to close until the user resolves them"). Per Plot's flexibility-vs-guardrail rule (`skills/plot/SKILL.md:179-184`: *"Guardrails protect ... Flexibility serves ... If an override would violate a guardrail, confirm with the user"*), the third option ("override and close anyway") is the safety valve. Open question: should the override require a one-liner reason that lands in the sprint file's `## Notes`, or just an `AskUserQuestion` confirmation? Recommend the former — leaves a written trail of why the discrepancy was accepted, mirroring the scope-change log convention already in the skill (line 348–364).

## Cross-cutting themes

### Theme A: Sprint PR lifecycle

Items 1, 2, 3, 5, 6 all converge on a single design gap: sprints don't have a PR-aware lifecycle even though Max naturally treats sprint planning as something that benefits from review. The current "commits directly to main" model handles single-author, simple sprints fine, but breaks the moment readiness assessments and deferral discussions enter the picture. The fix is coherent only when applied as a unit:

- **Skeleton on main** stays (initial creation), preserving the simple path
- **Refinement on `sprint/<slug>` branch + draft PR** is added as optional (items 2 + 3)
- **Phase stays `Planning` throughout the PR** (item 1's explicit rule covers this)
- **`/plot-sprint <slug> commit` becomes PR-aware**: detects the open PR, bumps phase on the branch, pushes, marks ready, merges with `--merge` (items 5 + 6)
- **Squash is forbidden for sprint PRs** by default, mirroring `plot-approve`'s already-shipped rule (item 5)

Landing one of these in isolation creates worse confusion than landing none. Recommend bundling 1, 2, 3, 5, 6 into one PR to `eins78/plot`.

### Theme B: Checked checkbox ≠ delivered

Item 8, plus the broader pattern: Plot already has hard delivery gates in `plot-deliver` (`skills/plot-deliver/SKILL.md:102-120`, "verify all plan branches accounted for"). The sprint side never inherited the same discipline — checkbox state is treated as ground truth. The fix is to teach `plot-sprint` close (and status) to **never trust the checkbox alone for `[slug]` items** — always cross-reference `docs/plans/delivered/`. This is the same conceptual move that `plot-deliver` already made, just applied one layer up.

### Theme C: Phase transitions live in the named subcommands

Items 1, 6, and (less directly) 8 all share an underlying rule that's currently implicit: **named subcommands are the only legitimate phase-transition surface**. Item 1 makes this explicit in skill text. Item 6 makes it explicit in workflow (the merge IS the phase-change, atomic with the commit subcommand). Item 8's gate prevents `[x]` (which looks like a phase-bump for the sprint item) from being trusted without the underlying delivery confirmation.

This theme maps directly to manifesto Principle 7. Strengthening it is *cheap* (mostly text and small workflow tweaks) and prevents recurring guardrail leaks.

## Priority ordering

1. **Now** — items that prevent correct behavior right now:
   - **Item 8** — false-positive completeness check. This silently allowed a closed sprint to claim work was delivered when it wasn't. Highest correctness impact, lowest disruption (the change is additive — a new gate plus a status flag).
   - **Item 1** — explicit phase-transition rule. Two-line addition; eliminates the "start a PR" → "Active" agent confusion observed in the very first trial run.

2. **Soon** — workflow improvements that go together:
   - **Items 2 + 3 + 5 + 6** — the sprint PR lifecycle bundle. Should ship as one PR per Theme A. Each on its own would leave the skill in a confusing intermediate state. Concrete shape is fully sketched above; bundling them is mechanical, not architectural.

3. **Later** — nice-to-have:
   - **Item 4** — multiline slug parse documentation. Max marked it "Minor". One-paragraph addition. Land alongside any future `plot-sprint` edit.

## What I did NOT change

### Already addressed

- **Item 7** — BDD gate in `ralph-plot-sprint` Step 3. The current `skills/ralph-plot-sprint/SKILL.md` (version 1.0.0-beta.2) has a full DoD Compliance Checklist (line 30–53) that classifies `needs_bdd` and gates Step 1, 2, 3, and 4. Step 3's implementation sequence (line 232–240) explicitly says: *"If BDD required — write Gherkin scenarios FIRST (red-green discipline). Run tests, confirm they fail."* The Common Mistakes table also has *"Skipping BDD for a non-exempt feature"* (line 350). This evolved between the comment date (2026-03-01) and the current revision. Recommendation: post a comment on issue #2 noting the resolution with line citations so the audit trail is preserved, then close that thread when the rest of the items merge.

- **Squash-merge rule already exists for plan PRs.** Item 5's recommendation extends to sprint PRs the rule already shipped in `skills/plot-approve/SKILL.md:112` (*"Default to merge commits to preserve granular commit history"*). No change needed in `plot-approve`; just mirror the wording into `plot-sprint`'s new Commit subcommand text.

### Out of scope

- **`plot-idea`, `plot-release`, `plot-reject`, `plot-approve` skills.** None of issue #2's feedback items target these. They are mentioned only via cross-reference (the squash issue from `eins78/skills#4` is the same pattern, already fixed in `plot-approve`). No edits proposed.

- **Hub `plot/SKILL.md` and `MANIFESTO.md`.** The improvements above are all internal to `plot-sprint`; the hub describes phases at a high level (Planning → Committed → Active → Closed) and that description doesn't need to change. The manifesto's Principle 7 ("Phase guardrails") is already strong and is exactly what items 1 and 8 reinforce.

- **Helper scripts** (`scripts/plot-pr-state.sh`, `plot-impl-status.sh`, `plot-review-status.sh`, `plot-update-board.sh`). The proposed changes use these read-only — no new script is required. If item 8's false-positive detection becomes hot enough to deserve its own script, that's a follow-up; the per-item check in `/plot-sprint <slug> close` is straightforward (`ls docs/plans/delivered/<slug>.md`).

- **Sprint template** (`skills/plot/templates/sprint.md`). No changes needed — the template already has `## Notes / ### Scope Changes`, which is where item 8's "override-with-reason" entry would land.
