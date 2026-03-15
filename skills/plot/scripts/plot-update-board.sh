#!/usr/bin/env bash
# Plot helper: Update GitHub Projects board status for a PR
# Usage: plot-update-board.sh <pr-url> <status> <owner> <project-number>
# Adds the PR to the board (idempotent) and sets its Status field.
# Designed for small-model consumption: exit 0 on success or graceful skip, exit 1 on usage error.

set -euo pipefail

PR_URL="${1:?Usage: plot-update-board.sh <pr-url> <status> <owner> <project-number>}"
STATUS="${2:?Usage: plot-update-board.sh <pr-url> <status> <owner> <project-number>}"
OWNER="${3:?Usage: plot-update-board.sh <pr-url> <status> <owner> <project-number>}"
PROJECT_NUMBER="${4:?Usage: plot-update-board.sh <pr-url> <status> <owner> <project-number>}"

CACHE_FILE="/tmp/plot-board-cache-${OWNER}-${PROJECT_NUMBER}.json"

# --- Load or fetch project metadata (project ID, Status field ID, options) ---

PROJECT_ID=""
FIELD_ID=""
OPTIONS_JSON=""

if [ -f "$CACHE_FILE" ]; then
  PROJECT_ID=$(jq -r '.projectId // empty' "$CACHE_FILE" 2>/dev/null || true)
  FIELD_ID=$(jq -r '.fieldId // empty' "$CACHE_FILE" 2>/dev/null || true)
  OPTIONS_JSON=$(jq -c '.options // empty' "$CACHE_FILE" 2>/dev/null || true)
fi

# Step 1: Resolve project node ID
if [ -z "$PROJECT_ID" ]; then
  PROJECT_ID=$(gh project view "$PROJECT_NUMBER" --owner "$OWNER" --format json --jq '.id' 2>/dev/null) || {
    echo "Warning: Could not resolve project ${OWNER}/${PROJECT_NUMBER} (missing token scope?)" >&2
    exit 0
  }
fi

# Step 2: Add PR to board (idempotent) and capture item ID
ITEM_ID=$(gh project item-add "$PROJECT_NUMBER" --owner "$OWNER" --url "$PR_URL" --format json --jq '.id' 2>/dev/null) || {
  echo "Warning: Could not add ${PR_URL} to project ${OWNER}/${PROJECT_NUMBER}" >&2
  exit 0
}

# Step 3: Find Status field and option IDs
if [ -z "$FIELD_ID" ] || [ -z "$OPTIONS_JSON" ]; then
  FIELDS_JSON=$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json 2>/dev/null) || {
    echo "Warning: Could not list fields for project ${OWNER}/${PROJECT_NUMBER}" >&2
    exit 0
  }

  FIELD_ID=$(echo "$FIELDS_JSON" | jq -r '.fields[] | select(.name == "Status") | .id')
  OPTIONS_JSON=$(echo "$FIELDS_JSON" | jq -c '.fields[] | select(.name == "Status") | .options')

  if [ -z "$FIELD_ID" ]; then
    echo "Warning: No Status field found in project ${OWNER}/${PROJECT_NUMBER}" >&2
    exit 0
  fi

  # Cache project metadata for bulk operations
  jq -n \
    --arg projectId "$PROJECT_ID" \
    --arg fieldId "$FIELD_ID" \
    --argjson options "$OPTIONS_JSON" \
    '{projectId: $projectId, fieldId: $fieldId, options: $options}' > "$CACHE_FILE"
fi

# Step 4: Find option ID for target status
OPTION_ID=$(echo "$OPTIONS_JSON" | jq -r --arg status "$STATUS" '.[] | select(.name == $status) | .id')

if [ -z "$OPTION_ID" ]; then
  echo "Warning: Status option '${STATUS}' not found in project ${OWNER}/${PROJECT_NUMBER}" >&2
  exit 0
fi

# Step 5: Set the status
gh project item-edit \
  --project-id "$PROJECT_ID" \
  --id "$ITEM_ID" \
  --field-id "$FIELD_ID" \
  --single-select-option-id "$OPTION_ID" >/dev/null 2>&1 || {
  echo "Warning: Could not set status '${STATUS}' for ${PR_URL}" >&2
  exit 0
}
