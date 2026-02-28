#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p ~/bin
ln -sf "$SCRIPT_DIR/ralph-sprint.sh" ~/bin/ralph-sprint.sh
echo "Symlinked ralph-sprint.sh → ~/bin/ralph-sprint.sh"

echo ""
echo "Required environment variables:"
echo "  CLAUDE_NTFY_URL     ntfy server URL"
echo "  CLAUDE_NTFY_TOKEN   ntfy auth token"
echo ""
echo "Optional:"
echo "  RALPH_SPRINT_CLAUDE    Claude command (default: claude --dangerously-skip-permissions)"
echo "  CLAUDE_NTFY_TOPIC   ntfy topic (default: claude-on-\$(hostname -s))"
