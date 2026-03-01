#!/bin/bash
set -e

# ralph-sprint: Automated sprint loop using /ralph-plot-sprint skill.
# Each iteration invokes claude -p with the skill, reads COMPLETE/BLOCKED signals,
# and notifies via ntfy when human action is needed.
#
# With -p mode, claude buffers text output (no incremental streaming).
# Each iteration's output appears in full once the agent finishes.

# --- Configuration ---

RALPH_SPRINT_CLAUDE="${RALPH_SPRINT_CLAUDE:-claude --dangerously-skip-permissions}"
RALPH_SPRINT_SKILL="${RALPH_SPRINT_SKILL:-ralph-plot-sprint}"
RALPH_SPRINT_AUTOMERGE="${RALPH_SPRINT_AUTOMERGE:-false}"
RALPH_SPRINT_TIMEOUT="${RALPH_SPRINT_TIMEOUT:-1800}"
NTFY_URL="${CLAUDE_NTFY_URL:?"Set CLAUDE_NTFY_URL (e.g. https://ntfy.sh)"}"
NTFY_TOKEN="${CLAUDE_NTFY_TOKEN:?"Set CLAUDE_NTFY_TOKEN"}"
NTFY_TOPIC="${CLAUDE_NTFY_TOPIC:-claude-on-$(hostname -s)}"

# --- State ---

SESSION_IDS=()
i=0
EXITING_NORMALLY=false

# --- Signal handling ---

# shellcheck disable=SC2329
cleanup() {
  local exit_code=$?
  trap - EXIT

  # Skip cleanup on normal exit (already handled by the main flow)
  if [ "$EXITING_NORMALLY" = true ]; then
    exit "$exit_code"
  fi

  echo ""
  if [ "$exit_code" -eq 130 ]; then
    echo "Interrupted."
    notify "Sprint Interrupted" "Sprint '$SLUG' interrupted after $i iterations." "skull"
  else
    echo "Error (exit $exit_code) after $i iterations."
    notify "Sprint Error" "Sprint '$SLUG' errored (exit $exit_code) after $i iterations." "x"
  fi
  wrapup "Sprint Interrupted"
  exit "$exit_code"
}
trap cleanup EXIT

# --- Argument validation ---

if [ -z "$1" ] || [ -z "$2" ]; then
  EXITING_NORMALLY=true
  echo "Usage: $0 <iterations> <slug>"
  echo ""
  echo "Environment variables:"
  echo "  RALPH_SPRINT_CLAUDE      Claude command (default: claude --dangerously-skip-permissions)"
  echo "  RALPH_SPRINT_SKILL       Iteration skill name (default: ralph-plot-sprint)"
  echo "  RALPH_SPRINT_AUTOMERGE   Auto-merge reviewed PRs: true|false (default: false)"
  echo "  RALPH_SPRINT_TIMEOUT     Per-iteration timeout in seconds (default: 1800)"
  echo "  CLAUDE_NTFY_URL          ntfy server URL (required)"
  echo "  CLAUDE_NTFY_TOKEN        ntfy auth token (required)"
  echo "  CLAUDE_NTFY_TOPIC        ntfy topic (default: claude-on-\$(hostname -s))"
  echo ""
  echo "Mid-run steering:"
  echo "  echo 'Focus on demos' > .ralph-state/instructions.md"
  echo "  (Injected into the next iteration's prompt, then deleted)"
  exit 1
fi

if ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$1" -lt 1 ]; then
  EXITING_NORMALLY=true
  echo "Error: iterations must be a positive integer"
  exit 1
fi

if [[ "$2" =~ [[:space:]] ]]; then
  EXITING_NORMALLY=true
  echo "Error: slug must not contain whitespace"
  exit 1
fi

ITERATIONS=$1
SLUG=$2

# --- Pre-flight checks ---

# Verify GitHub CLI is authenticated (saves burning an iteration on auth failure)
if ! gh auth status &>/dev/null; then
  EXITING_NORMALLY=true
  echo "Error: GitHub CLI not authenticated. Run: gh auth login -h github.com"
  exit 1
fi

# Verify sprint file exists
if ! ls docs/sprints/*-"$SLUG".md &>/dev/null 2>&1; then
  EXITING_NORMALLY=true
  echo "Error: No sprint file found for slug '$SLUG' in docs/sprints/"
  echo "Available sprints:"
  ls docs/sprints/*.md 2>/dev/null | xargs -I{} basename {} .md | sed 's/^[0-9-]*W[0-9]*-//' | sort -u || echo "  (none)"
  exit 1
fi

# --- Agent prompt ---

PROMPT="/$RALPH_SPRINT_SKILL $SLUG

AUTOMERGE=$RALPH_SPRINT_AUTOMERGE"

# --- ntfy ---

notify() {
  local title="$1" message="$2" tags="$3"
  curl -s -o /dev/null \
    -H "Authorization: Bearer $NTFY_TOKEN" \
    -H "Title: $title" \
    -H "Tags: $tags" \
    -H "Priority: high" \
    -d "$message" \
    "$NTFY_URL/$NTFY_TOPIC" 2>/dev/null || true
}

# --- Wrap-up session ---

wrapup() {
  local title="$1"
  if [ ${#SESSION_IDS[@]} -eq 0 ]; then
    return
  fi
  local id_list
  id_list=$(printf '%s\n' "${SESSION_IDS[@]}")
  echo ""
  echo "=== Wrap-up ==="
  # shellcheck disable=SC2086
  $RALPH_SPRINT_CLAUDE -p "/bye
You are wrapping up an automated sprint run for sprint '$SLUG'.
The run completed $i iterations with outcome: $title.

These are the session IDs from each iteration — resume each one
to read its transcript, then create a single sessionlog summarizing
the full sprint run:

$id_list" || true
}

# --- Main loop ---

for ((i=1; i<=ITERATIONS; i++)); do
  echo "=== Iteration $i/$ITERATIONS ==="

  # --- Instruction injection ---
  INSTRUCTIONS_FILE=".ralph-state/instructions.md"
  ITER_PROMPT="$PROMPT"
  if [ -f "$INSTRUCTIONS_FILE" ]; then
    EXTRA_INSTRUCTIONS=$(cat "$INSTRUCTIONS_FILE")
    rm "$INSTRUCTIONS_FILE"
    echo "Injected instructions from $INSTRUCTIONS_FILE"
    ITER_PROMPT="HUMAN OVERRIDE (this iteration only):
$EXTRA_INSTRUCTIONS
---

$ITER_PROMPT"
  fi

  # shellcheck disable=SC2086
  json_result=$(timeout "$RALPH_SPRINT_TIMEOUT" $RALPH_SPRINT_CLAUDE --worktree "sprint-$SLUG" -p "$ITER_PROMPT" --output-format json </dev/null) || json_result=""

  result=$(echo "$json_result" | jq -r '.result // empty' 2>/dev/null) || result=""
  session_id=$(echo "$json_result" | jq -r '.session_id // empty' 2>/dev/null) || session_id=""

  if [ -n "$session_id" ]; then
    SESSION_IDS+=("$session_id")
  fi

  echo "$result"

  # Extract summary: last ~10 lines before the promise tag (or last 10 lines if no tag)
  summary=$(echo "$result" | grep -B 50 '<promise>' | grep -v '<promise>' | tail -10) || true
  if [ -z "$summary" ]; then
    summary=$(echo "$result" | tail -10)
  fi

  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    notify "Sprint Complete" "Sprint '$SLUG' complete after $i iterations.

$summary" "white_check_mark"
    echo "Sprint complete after $i iterations."
    EXITING_NORMALLY=true
    wrapup "Sprint Complete"
    exit 0

  elif [[ "$result" == *"<promise>BLOCKED</promise>"* ]]; then
    notify "Sprint Blocked" "Sprint '$SLUG' is blocked after $i iterations.

$summary" "octagonal_sign"
    echo "Sprint blocked after $i iterations."
    EXITING_NORMALLY=true
    wrapup "Sprint Blocked"
    exit 1

  else
    # No recognized signal — agent did work but there is more to do. Continue.
    notify "Sprint Iteration $i/$ITERATIONS" "Sprint '$SLUG' — iteration $i done.

$summary" "arrows_counterclockwise"
    echo "Iteration $i: no signal detected — continuing."
  fi
done

# Exhausted iterations without a promise signal
notify "Sprint Iterations Exhausted" "Sprint '$SLUG' used all $ITERATIONS iterations without completing." "warning"
echo "Exhausted $ITERATIONS iterations without completing."
EXITING_NORMALLY=true
wrapup "Sprint Iterations Exhausted"
exit 1
