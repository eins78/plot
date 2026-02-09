# Plot Manifesto

Plot is a git-native planning system for software development. It is designed for teams where humans make decisions and AI agents help plan and implement, but requires nothing more than git, a forge with pull request review, and markdown. It is experimental, still taking shape through real-world usage, and currently in alpha.

## Core Belief

Plans belong in git. Not in a separate issue tracker, not in a project management tool, not in a spreadsheet. Plans are markdown files — written, reviewed, and versioned just like source code. They live on branches, merge through pull requests, and stay in place forever with date-prefixed filenames. Anyone with repo access can `ls docs/plans/active/` and see exactly what's in flight. No dashboard logins, no access tiers, no sync problems.

Plot works for any team composition, but it is especially designed for a specific one: **human decision-makers** working with **AI facilitators** (for refining ideas, planning, and process administration) and **AI coding agents** (implementing plans as autonomously as current models allow). In this model, humans always own the decisions — approval, prioritization, release, verification. Agents surface information, suggest actions, and do implementation work. But every step of the workflow can also be done by a human with basic git knowledge. The AI is the designed-for sweet spot, not a hard requirement.

## Principles

These are the founding beliefs that guide Plot's design. When a proposed change conflicts with these principles, the principles win.

### 1. Git is the database

Plans are markdown files committed to git. Pull requests are workflow metadata. A project board (if used) is a read-only reflection of PR state — useful to glance at, but never the source of truth. There is no external tracker, no database, no API to sync with. If it's not in git, it doesn't exist.

This also makes plans transparent. Plans-as-files are more visible than backlog items in a tracker. Anyone with repo access can browse `docs/plans/active/` and `docs/plans/delivered/` without needing credentials for a separate tool. The full history of every plan — drafts, revisions, approvals — is in the git log.

### 2. Plans merge before implementation

This is the key design insight that makes everything else work. The plan file lands on main *before* any implementation branch is created. Every implementation branch references a stable, approved document. This means you always know what was promised, and you can compare it to what was delivered.

### 3. Commands, not code

Plot's commands are markdown instructions that an AI agent interprets — not shell scripts or compiled programs. This makes them resilient: when a PR is already merged, when arguments are missing, when local state is stale, the agent adapts rather than crashing. The trade-off is that behavior isn't perfectly deterministic, but in practice the flexibility matters more than the precision.

> **Editorial note:** This principle is under active discussion. Plot now includes shell helper scripts (`scripts/plot-pr-state.sh`, `scripts/plot-impl-status.sh`) and plans to add workflow scripts that compose them. The relationship between skills (adaptive, AI-interpreted) and scripts (deterministic, human-executable) needs a clearer articulation. See the Pacing section below for how mechanical vs. judgment-requiring steps inform this split.

### 4. One plan, many branches

A single approved plan can spawn multiple implementation branches. Different people, different agents, different worktrees — all working on the same plan in parallel. Each branch merges independently on its own schedule.

### 5. Skills stay project-agnostic

Plot contains zero hardcoded project names, paths, or configuration. Adopting projects describe their conventions in a `## Plot Config` section of their `CLAUDE.md`. Plot discovers and adapts to whatever the project provides — branch prefixes, release tooling, changelog conventions. If a project uses changesets, Plot uses changesets. If it doesn't, Plot constructs release notes from plan files and commit messages.

### 6. Smart defaults over strict inputs

Commands discover context rather than demanding exact arguments. If there's one open plan PR, Plot proposes it. If the slug is obvious from the conversation, Plot suggests it. Missing or ambiguous input triggers a helpful suggestion, never a cryptic error. The system should feel forgiving, not bureaucratic.

### 7. Phase guardrails

Each command checks the current workflow phase before acting. You cannot approve an unreviewed draft. You cannot deliver a plan with open implementation PRs. You cannot release undelivered work. These guardrails prevent common workflow mistakes at the point where they'd cause the most confusion.

### 8. Plans stay in place

Plan files are created with a date prefix (`docs/plans/YYYY-MM-DD-slug.md`) and never move. Symlink directories (`docs/plans/active/`, `docs/plans/delivered/`) provide filtered views by phase. Links from PR bodies and other references point to the date-prefixed file, so they never break. The date prefix sorts files chronologically and answers "when did this start?" at a glance.

### 9. Small models welcome

Facilitator tasks — reading git state, running commands, printing summaries — must work with smaller, faster models (Sonnet, Haiku), not just frontier models. This means: explicit step-by-step instructions over narrative prose, structured data (JSON from helper scripts) over free-form parsing, and concrete examples over abstract descriptions. Steps requiring judgment (completeness verification, release note cross-checking) should degrade gracefully: a smaller model asks for human confirmation where a larger model might decide autonomously, but the workflow never breaks.

## Lifecycle

Plot has four plan-level phases: **Draft**, **Approved**, **Delivered**, and **Released**.

A plan starts as a draft on an `idea/` branch. When the plan is reviewed and approved, it merges to main and spawns implementation branches (`feature/`, `bug/`, `docs/`, `infra/`). When all implementation PRs are merged, the plan is delivered — its symlink moves from `active/` to `delivered/` and the Phase field is updated. For features and bugs, a separate release step cuts a versioned tag with changelog entries. For docs and infra work, delivery is the end — it's live when merged to main.

The release phase includes a verification loop. An RC (release candidate) tag is cut from delivered plans, and a verification checklist is generated — one item per delivered feature or bug fix. The team tests against the checklist: automated CI for technical tests, manual verification for user stories. Bugs found during this endgame phase are fixed via normal `bug/` branches, merged to main, and a new RC is cut. When all checklist items pass, a final release tag is created.

- **RC tags:** `v1.2.0-rc.1`, `v1.2.0-rc.2`, etc.
- **Verification checklist:** generated from delivered plans, lives as `docs/releases/v<version>-checklist.md` (git-native, like everything else).
- **Endgame fixes:** normal branches, normal PRs, new RC. No special process.
- **Sign-off:** humans give final OK on each checklist item. Agents can guide testing but never sign off.

The `/plot` dispatcher reads your current git state and tells you what to do next.

## Pacing

Not every step in the workflow should move at the same speed. Plot recognizes three pacing categories:

**Automate ASAP** — Mechanical transitions with no judgment required. These should be scripted and fast. Examples: merging an approved plan PR, creating implementation branches, delivering a plan (moving symlink), cutting an RC tag, generating a verification checklist, creating a final release tag.

**Natural pauses** — Steps where real work happens and the workflow should wait. These aren't bottlenecks; they're the point. Examples: implementing a feature on a branch, running the endgame verification checklist, writing a plan.

**Human-paced** — Steps that require a human decision. No agent should rush these. Examples: reviewing and approving a plan, deciding when to release, signing off on a verification checklist item, choosing the version number.

The meta-principle: **don't over-complicate because AI doesn't feel friction.** Every step must be executable by a human with basic git knowledge. If a workflow step can't be done by hand, it's too complex. Scripts and AI make it faster, not possible.

## What Plot Is Not

Plot is deliberately small and opinionated. These boundaries are intentional, not oversights.

- **Not a monorepo tool.** Plot works with a single repository. Coordinating releases across multiple packages or repos is out of scope.
- **Not a package publisher.** Plot handles versioning and changelogs, not npm publish or artifact distribution.
- **Not an issue tracker.** It doesn't supplement issue trackers — it replaces them. If you need GitHub Issues alongside Plot, the two systems will overlap and conflict.
- **Not a CI/CD system.** Plot creates tags and changelogs. What happens after that (deployment, notifications, artifact builds) is your CI/CD pipeline's job.
- **Not a time or effort tracker.** No story points, no burndown charts, no estimates. Plot tracks *what* is planned and *whether* it shipped, not *how long* it took.
- **Not a release note generator.** Plot discovers and uses whatever release note tooling the project already has (changesets, custom scripts, etc.). When no tooling exists, it constructs notes from plan changelog sections and commit messages. It doesn't auto-generate notes from commit history alone.

## Release Notes

Not every change needs a release note. The rule: **user-facing changes need release notes; internal work does not.** Features and bug fixes describe what changed for users. Documentation, infrastructure, tests, and refactoring don't — they're important work, but they aren't something users need to know about in a changelog.

## Origin

Plot was built on 2026-02-07 across five Claude Code sessions, starting from a simple question: "I want to plan multiple ideas, read them as formatted text, and implement them in parallel." The design evolved through two complete end-to-end lifecycle tests that uncovered and fixed critical issues — empty branches on approve, undated archive names, draft PR merge failures, and stale local state in helper scripts.

It is still experimental. The current version (1.0.0-beta) reflects what works in practice for a small team, but the system is actively evolving as it gets used in more projects. Conventions may change, new commands may appear, and some current behavior may be revised based on real-world feedback.

## Making Decisions

When considering a change to Plot, ask:

1. Does it keep planning in git, or does it introduce an external dependency?
2. Does it stay project-agnostic, or does it hardcode assumptions about a specific project?
3. Does it fail gracefully with helpful suggestions, or does it break on unexpected state?
4. Is it a convention that projects opt into, or configuration that Plot enforces?
5. Would removing it make the system simpler without losing something essential?
6. Could a human with basic git knowledge execute this manually?
7. Could a smaller model (Sonnet/Haiku) follow these instructions for the mechanical parts?

If the answer to question 5 is yes, remove it. If the answer to question 6 is no, simplify it. Plot should stay lean. The goal is a small set of strong conventions, not a large set of flexible options.
