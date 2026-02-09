#!/usr/bin/env bash
# Plot helper: Get plan PR state for a slug
# Usage: plot-pr-state.sh <slug>
# Output: JSON with number, state, isDraft, merged fields
# Designed for small-model consumption: structured JSON output, no interpretation needed.

set -euo pipefail

SLUG="${1:?Usage: plot-pr-state.sh <slug>}"

# Look for PR on idea/<slug> branch
PR_JSON=$(gh pr list --head "idea/${SLUG}" --state all --json number,state,isDraft,mergedAt --jq '.[0] // empty' 2>/dev/null)

if [ -z "$PR_JSON" ]; then
  echo '{"found": false}'
  exit 0
fi

STATE=$(echo "$PR_JSON" | jq -r '.state')
IS_DRAFT=$(echo "$PR_JSON" | jq -r '.isDraft')
NUMBER=$(echo "$PR_JSON" | jq -r '.number')
MERGED_AT=$(echo "$PR_JSON" | jq -r '.mergedAt // empty')

if [ "$STATE" = "MERGED" ]; then
  STATUS="merged"
elif [ "$STATE" = "CLOSED" ]; then
  STATUS="closed"
elif [ "$IS_DRAFT" = "true" ]; then
  STATUS="draft"
else
  STATUS="ready"
fi

jq -n \
  --argjson found true \
  --argjson number "$NUMBER" \
  --arg state "$STATE" \
  --argjson isDraft "$IS_DRAFT" \
  --arg status "$STATUS" \
  --arg mergedAt "$MERGED_AT" \
  '{found: $found, number: $number, state: $state, isDraft: $isDraft, status: $status, mergedAt: $mergedAt}'
