# Plot Manifesto

Plot is a git-native planning system for AI-assisted software development. It is experimental, still taking shape through real-world usage, and currently in alpha.

## Core Belief

If your development workflow starts inside an AI coding agent, your planning system should live there too — in git, in markdown, on branches. Not in a separate issue tracker, not in a project management tool, not in a spreadsheet. Plans are code artifacts: written, reviewed, and versioned just like source code.

Plot exists because we wanted to plan multiple ideas, read them as formatted text, and implement them in parallel — all without leaving the terminal or switching context to an external tool.

## Principles

These are the founding beliefs that guide Plot's design. When a proposed change conflicts with these principles, the principles win.

### 1. Git is the database

Plans are markdown files committed to git. Pull requests are workflow metadata. The GitHub Projects board is a read-only reflection of PR state — useful to glance at, but never the source of truth. There is no external tracker, no database, no API to sync with. If it's not in git, it doesn't exist.

### 2. Plans merge before implementation

This is the key design insight that makes everything else work. The plan file lands on main *before* any implementation branch is created. Every implementation branch references a stable, approved document. This means you always know what was promised, and you can compare it to what was delivered.

### 3. Commands, not code

Plot's commands are markdown instructions that an AI agent interprets — not shell scripts or compiled programs. This makes them resilient: when a PR is already merged, when arguments are missing, when local state is stale, the agent adapts rather than crashing. The trade-off is that behavior isn't perfectly deterministic, but in practice the flexibility matters more than the precision.

### 4. One plan, many branches

A single approved plan can spawn multiple implementation branches. Different people, different agents, different worktrees — all working on the same plan in parallel. Each branch merges independently on its own schedule.

### 5. Skills stay project-agnostic

Plot contains zero hardcoded project names, paths, or configuration. Adopting projects describe their conventions in a `## Plot Config` section of their `CLAUDE.md`. Plot discovers and adapts to whatever the project provides — branch prefixes, release tooling, changelog conventions. If a project uses changesets, Plot uses changesets. If it doesn't, Plot constructs release notes from plan files and commit messages.

### 6. Smart defaults over strict inputs

Commands discover context rather than demanding exact arguments. If there's one open plan PR, Plot proposes it. If the slug is obvious from the conversation, Plot suggests it. Missing or ambiguous input triggers a helpful suggestion, never a cryptic error. The system should feel forgiving, not bureaucratic.

### 7. Phase guardrails

Each command checks the current workflow phase before acting. You cannot approve an unreviewed draft. You cannot deliver a plan with open implementation PRs. You cannot release undelivered work. These guardrails prevent common workflow mistakes at the point where they'd cause the most confusion.

### 8. Dated archives

Delivered plans move from `docs/plans/` to `docs/archive/YYYY-MM-DD-slug.md`. The date prefix sorts files chronologically and answers "when did this ship?" at a glance, without parsing git history.

## Lifecycle

Plot has four phases: **Draft**, **Approved**, **Delivered**, and **Released**.

A plan starts as a draft on an `idea/` branch. When the plan is reviewed and approved, it merges to main and spawns implementation branches (`feature/`, `bug/`, `docs/`, `infra/`). When all implementation PRs are merged, the plan is delivered — archived with a date stamp. For features and bugs, a separate release step cuts a versioned tag with changelog entries. For docs and infra work, delivery is the end — it's live when merged to main.

The `/plot` dispatcher reads your current git state and tells you what to do next.

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

If the answer to question 5 is yes, remove it. Plot should stay lean. The goal is a small set of strong conventions, not a large set of flexible options.
