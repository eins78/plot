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
RALPH_SPRINT_AUTOMERGE="${RALPH_SPRINT_AUTOMERGE:-false}"
RALPH_SPRINT_TIMEOUT="${RALPH_SPRINT_TIMEOUT:-1800}"
NTFY_URL="${CLAUDE_NTFY_URL:?"Set CLAUDE_NTFY_URL (e.g. https://ntfy.sh)"}"
NTFY_TOKEN="${CLAUDE_NTFY_TOKEN:?"Set CLAUDE_NTFY_TOKEN"}"
NTFY_TOPIC="${CLAUDE_NTFY_TOPIC:-claude-on-$(hostname -s)}"

# --- Merge behavior ---

if [ "$RALPH_SPRINT_AUTOMERGE" = "true" ]; then
  MERGE_INSTRUCTION='Then merge ("gh pr merge --squash").'
  COMPLETE_CRITERIA='all PRs merged, all code features have demos in docs/demos/, RC release tagged via /plot-release rc'
else
  MERGE_INSTRUCTION='Do NOT merge — leave PRs ready for human review.'
  COMPLETE_CRITERIA='all PRs marked ready, CI green, zero unresolved comments'
fi

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
  echo "  RALPH_SPRINT_AUTOMERGE   Auto-merge reviewed PRs (default: false)"
  echo "  RALPH_SPRINT_TIMEOUT     Per-iteration timeout in seconds (default: 1800)"
  echo "  CLAUDE_NTFY_URL          ntfy server URL (required)"
  echo "  CLAUDE_NTFY_TOKEN        ntfy auth token (required)"
  echo "  CLAUDE_NTFY_TOPIC        ntfy topic (default: claude-on-\$(hostname -s))"
  echo ""
  echo "Mid-run steering:"
  echo "  echo 'Skip PR #38' > .ralph-state/instructions.md"
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

# --- Agent prompt ---
# Quoted heredoc prevents variable expansion; variables are substituted after.

# shellcheck disable=SC2016
IFS= read -r -d '' PROMPT <<'PROMPT' || true
/plot-sprint $SLUG

PRIORITY ORDER — follow this on every iteration:

0. REBASE first. Run "git fetch origin && git rebase origin/HEAD" to ensure
   the worktree has the latest changes. If the rebase has conflicts you cannot
   resolve cleanly, abort it ("git rebase --abort") and output
   <promise>BLOCKED</promise>.

1. CHECK OPEN PRs.
   List open PRs for this sprint. For each PR, check:
   a) CI status via "gh pr checks". If any are failing, investigate and fix.
   b) Unresolved review comments via "gh api". If any exist, fix the underlying
      issues, push the fixes, then reply to each comment and resolve it.

2. FINALIZE any PR that has green CI, zero unresolved comments, and has been
   reviewed (has at least one prior review). Mark draft PRs as ready first
   ("gh pr ready <n>"). $MERGE_INSTRUCTION
   Finalize base-branch PRs first. After merging, rebase remaining PRs.

3. PICK THE NEXT TASK if work remains.
   Find the highest-priority unblocked task.
   - If the task references a plan (slug notation) that is not yet approved,
     run /plot-approve if the plan PR is ready, or output BLOCKED if it needs
     human review.
   - For substantial new tasks with no plan, create one with /plot-idea first.
   - For small tasks (docs, config, minor fixes), implement directly.
   NEVER create a feature/* branch for plan-only changes. Plan documents
   belong on main — use /plot-idea for new plans. If a sprint item is
   plan-only (no implementation needed), mark it complete without a PR.
   Before implementing, search the codebase — do not assume functionality is
   missing. Implement, run tests and type checks, then create a PR.

4. SELF-REVIEW any open PR that has NO review comments at all.
   PRs with existing comments (even if resolved) count as already reviewed.
   Only re-review a PR if it has new commits since the last review.
   For PRs containing ONLY documentation/plan files (no code), do a single
   light review for factual errors and structural issues only.
   Use /pr-review-toolkit:review-pr for code PRs. Post findings as individual
   PR review comments via "gh api". Be harsh. Do NOT fix findings in this
   iteration — leave them for the next iteration.

5. CREATE DEMOS for any merged code features missing a demo in docs/demos/.
   Check docs/definition-of-done.md for requirements.
   Use /show-your-work to create each demo. Plan-only sprint items (no code
   implementation) do NOT need demos. Up to TWO demos per iteration.
   After creating demos, check if all code features now have demos.

6. TAG RC RELEASE once all code features have demos.
   Run /plot-release rc to determine version bump, tag the RC, and create
   a verification checklist. Then output BLOCKED (RC needs human testing).

Each iteration follows all steps above in order. "Single task" means step 3:
implement at most ONE new sprint task per iteration. Steps 0-2 and 4 apply
to ALL relevant PRs each iteration.

Retry transient failures (network errors, flaky tests) up to 3 times.

When done, write a one-paragraph summary of what you accomplished, then
output exactly one of these promise signals on its own line:
  <promise>COMPLETE</promise> — all sprint tasks done, $COMPLETE_CRITERIA
  <promise>BLOCKED</promise> — truly stuck: external dependency, needs human action

Do NOT output BLOCKED just because you posted review comments — fixing those
is the next iteration's job. Only output a signal when the sprint is COMPLETE
or genuinely BLOCKED. If you did useful work and there is more to do, end
your summary without any promise signal.
PROMPT
PROMPT="${PROMPT//\$SLUG/$SLUG}"
PROMPT="${PROMPT//\$MERGE_INSTRUCTION/$MERGE_INSTRUCTION}"
PROMPT="${PROMPT//\$COMPLETE_CRITERIA/$COMPLETE_CRITERIA}"

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
