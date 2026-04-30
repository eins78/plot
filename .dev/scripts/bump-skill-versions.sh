#!/usr/bin/env bash
# bump-skill-versions.sh — parse changeset bumps block, bump SKILL.md versions
# Must run BEFORE `changeset version` (which deletes changeset files)
# Called by: pnpm run version
#
# Reads structured YAML from HTML comments in changeset files:
#   <!--
#   bumps:
#     skills:
#       plot-idea: patch
#       plot-approve: minor
#   -->
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHANGESET_DIR="$REPO_ROOT/.changeset"

source "$(dirname "$0")/lib.sh"

echo "Scanning changesets for skill version bumps..."

# Collect skill bumps from all pending changesets
# Format: SKILL_NAME:BUMP_TYPE (one per line)
all_bumps=""
declare -A SKILL_BUMPS=()

for cs_file in "$CHANGESET_DIR"/*.md; do
  [ ! -f "$cs_file" ] && continue
  basename_file="$(basename "$cs_file")"
  [[ "$basename_file" == "README.md" ]] && continue
  [[ "$basename_file" == "_template" ]] && continue

  # Extract YAML from <!-- bumps: ... --> HTML comment block
  # Uses awk to find content between <!-- and -->, then looks for skills: entries
  bumps_yaml=$(awk '
    /^<!--/  { in_comment=1; next }
    /^-->/   { in_comment=0; next }
    in_comment { print }
  ' "$cs_file")

  [ -z "$bumps_yaml" ] && continue

  # Parse "skills:" section — each line is "    skill-name: bump-type"
  in_skills=0
  while IFS= read -r line; do
    # Detect "skills:" section header
    if echo "$line" | grep -qE '^[[:space:]]*skills:[[:space:]]*$'; then
      in_skills=1
      continue
    fi
    # Detect other top-level keys (e.g., "agents:") — exit skills section
    if echo "$line" | grep -qE '^[[:space:]]{0,2}[a-z]'; then
      if [ $in_skills -eq 1 ] && ! echo "$line" | grep -qE '^[[:space:]]{4,}'; then
        in_skills=0
      fi
    fi
    # Parse skill entries (indented under skills:)
    if [ $in_skills -eq 1 ]; then
      skill=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*:.*//')
      bump=$(echo "$line" | sed 's/.*:[[:space:]]*//')
      if [ -n "$skill" ] && [ -n "$bump" ]; then
        all_bumps="${all_bumps}${skill}:${bump}"$'\n'
      fi
    fi
  done <<< "$bumps_yaml"
done

# Deduplicate: if same skill appears multiple times, keep highest bump
while IFS= read -r line; do
  [ -z "$line" ] && continue
  skill="${line%%:*}"
  bump="${line##*:}"
  existing="${SKILL_BUMPS[$skill]:-}"
  if [ -z "$existing" ]; then
    SKILL_BUMPS[$skill]="$bump"
  else
    existing_pri=$(bump_priority "$existing")
    new_pri=$(bump_priority "$bump")
    if [ "$new_pri" -gt "$existing_pri" ]; then
      SKILL_BUMPS[$skill]="$bump"
    fi
  fi
done <<< "$all_bumps"

if [ ${#SKILL_BUMPS[@]} -eq 0 ]; then
  echo "  No skill version bumps found in changesets."
  exit 0
fi

# Apply version bumps
for skill in "${!SKILL_BUMPS[@]}"; do
  bump="${SKILL_BUMPS[$skill]}"
  skill_md="$REPO_ROOT/skills/$skill/SKILL.md"

  if [ ! -f "$skill_md" ]; then
    echo "  WARN: skill directory 'skills/$skill' not found — skipping"
    continue
  fi

  current=$(extract_version "$skill_md")
  if [ -z "$current" ]; then
    echo "  WARN: no metadata.version in $skill/SKILL.md — skipping"
    continue
  fi

  new_version=$(increment_semver "$current" "$bump")
  replace_version_in_frontmatter "$skill_md" "$current" "$new_version"
  echo "  ✓ $skill: $current → $new_version ($bump)"
done

echo "Done bumping skill versions."
