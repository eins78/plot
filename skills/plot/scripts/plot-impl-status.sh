#!/usr/bin/env bash
# Plot helper: Get implementation PR states for a slug
# Usage: plot-impl-status.sh <slug>
# Reads the plan file for <slug> (date-prefixed in docs/plans/) and checks PR states
# Output: JSON array of {branch, number, state, isDraft, title}
# Designed for small-model consumption: structured JSON output, no interpretation needed.

set -euo pipefail

SLUG="${1:?Usage: plot-impl-status.sh <slug>}"

# Read plan file from main (not CWD) so PR links are always current.
# On impl branches the local copy is stale — it lacks the → #N annotations
# that /plot-approve adds to main after creating impl PRs.
#
# Find the date-prefixed plan file via the active or delivered symlink index
PLAN_PATH=$(git ls-tree --name-only origin/main docs/plans/ 2>/dev/null \
  | grep -E "[0-9]{4}-[0-9]{2}-[0-9]{2}-${SLUG}\.md$" | head -1)
if [ -n "$PLAN_PATH" ]; then
  PLAN_CONTENT=$(git show "origin/main:${PLAN_PATH}" 2>/dev/null || true)
else
  PLAN_CONTENT=""
fi

if [ -z "$PLAN_CONTENT" ]; then
  echo '{"error": "Plan file not found on main", "prs": []}'
  exit 0
fi

# Parse PR numbers from ## Branches section
# Format: - `type/name` — description → #12
PR_NUMBERS=$(echo "$PLAN_CONTENT" \
  | sed -n '/^## Branches/,/^## /p' \
  | grep -oE '#[0-9]+' \
  | tr -d '#' \
  | sort -u)

if [ -z "$PR_NUMBERS" ]; then
  echo '{"error": "No PR references found in plan", "prs": []}'
  exit 0
fi

# Build JSON array of PR states
RESULT="["
FIRST=true
for NUM in $PR_NUMBERS; do
  PR_JSON=$(gh pr view "$NUM" --json number,title,state,isDraft,headRefName 2>/dev/null || echo '{}')

  if [ "$PR_JSON" = "{}" ]; then
    continue
  fi

  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    RESULT="${RESULT},"
  fi

  RESULT="${RESULT}${PR_JSON}"
done
RESULT="${RESULT}]"

jq -n --argjson prs "$RESULT" '{prs: $prs}'
