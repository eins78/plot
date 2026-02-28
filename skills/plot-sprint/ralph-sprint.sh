#!/bin/bash
set -e

# ralph-sprint: Run automated sprint iterations via claude -p + /plot-sprint.
# Notifies via ntfy when human action is needed.
# On exit, runs a wrap-up session summarizing all iteration sessions.
#
# With -p mode, claude buffers text output (no incremental streaming).
# Each iteration's output appears in full once the agent finishes.

# --- Configuration ---

RALPH_SPRINT_CLAUDE="${RALPH_SPRINT_CLAUDE:-claude --dangerously-skip-permissions}"
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
  echo "  RALPH_SPRINT_CLAUDE    Claude command (default: claude --dangerously-skip-permissions)"
  echo "  CLAUDE_NTFY_URL     ntfy server URL (required)"
  echo "  CLAUDE_NTFY_TOKEN   ntfy auth token (required)"
  echo "  CLAUDE_NTFY_TOPIC   ntfy topic (default: claude-on-\$(hostname -s))"
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

# --- Agent prompt ---
# Quoted heredoc prevents variable expansion; $SLUG is substituted after.

# shellcheck disable=SC2016
IFS= read -r -d '' PROMPT <<'PROMPT' || true
/plot-sprint $SLUG

PRIORITY ORDER — follow this on every iteration:

0. REBASE first. Run "git fetch origin && git rebase origin/HEAD" to ensure
   the worktree has the latest changes (other iterations may have merged PRs
   or pushed commits since this worktree was created).

1. CHECK OPEN PRs first.
   List open PRs for this sprint. For each PR, check:
   a) CI status checks via "gh pr checks". If any are failing, investigate and fix.
   b) Unresolved review comments via "gh api". If any exist, fix the underlying
      issues, push the fixes, then reply to each comment and resolve it.
   If all PRs are green and comment-free, continue to step 2.

2. PICK THE NEXT TASK if no unresolved comments remain.
   Find the highest-priority unblocked task. Implement it, run tests and type
   checks, then create a PR using /plot skills.

3. SELF-REVIEW any open PR that has not been reviewed yet.
   This includes PRs you just created AND existing PRs with no review comments.
   Use /pr-review-toolkit:review-pr to run a thorough, critical review.
   Post all findings as individual PR review comments using "gh api".
   Be harsh — flag anything you would flag reviewing someone else's code.
   Do NOT fix the findings in this iteration. Leave them as comments
   for the next iteration to address.

ONLY WORK ON A SINGLE TASK PER ITERATION.
Retry transient failures — network errors, flaky tests, temporary CI issues —
a reasonable number of times before giving up.

When done, write a one-paragraph summary of what you accomplished, then
output exactly one of these promise signals on its own line:
  <promise>COMPLETE</promise> — all sprint tasks done, all PRs green and clean
  <promise>BLOCKED</promise> — truly stuck: external dependency, needs human action you cannot take

Do NOT output BLOCKED just because you posted review comments — fixing those
is the next iteration's job. Only output a signal when the sprint is COMPLETE
or genuinely BLOCKED. If you did useful work and there is more to do, end
your summary without any promise signal.
PROMPT
PROMPT="${PROMPT//\$SLUG/$SLUG}"

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

  # shellcheck disable=SC2086
  json_result=$($RALPH_SPRINT_CLAUDE --worktree "sprint-$SLUG" -p "$PROMPT" --output-format json) || json_result=""

  result=$(echo "$json_result" | jq -r '.result // empty' 2>/dev/null) || result=""
  session_id=$(echo "$json_result" | jq -r '.session_id // empty' 2>/dev/null) || session_id=""

  if [ -n "$session_id" ]; then
    SESSION_IDS+=("$session_id")
  fi

  echo "$result"

  # Extract summary: last ~10 lines before the promise tag
  summary=$(echo "$result" | grep -B 50 '<promise>' | grep -v '<promise>' | tail -10) || true

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
    # No recognized signal — agent did work but forgot the keyword. Continue.
    echo "Iteration $i: no signal detected — continuing."
  fi
done

# Exhausted iterations without a promise signal
notify "Sprint Iterations Exhausted" "Sprint '$SLUG' used all $ITERATIONS iterations without completing." "warning"
echo "Exhausted $ITERATIONS iterations without completing."
EXITING_NORMALLY=true
wrapup "Sprint Iterations Exhausted"
exit 1
