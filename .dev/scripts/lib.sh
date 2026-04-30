#!/usr/bin/env bash
# lib.sh — shared helpers for release automation scripts
# Source this file: source "$(dirname "$0")/lib.sh"

set -euo pipefail

# extract_version — read metadata.version from SKILL.md YAML frontmatter
# Usage: extract_version path/to/SKILL.md
extract_version() {
  local file="$1"
  # Match "  version:" inside the first YAML frontmatter block (between --- delimiters)
  awk '
    /^---$/ { block++; next }
    block == 1 && /^[[:space:]]+version:/ {
      sub(/^[[:space:]]+version:[[:space:]]*/, "")
      gsub(/"/, "")
      gsub(/'"'"'/, "")
      gsub(/[[:space:]]*$/, "")
      print
      exit
    }
    block >= 2 { exit }
  ' "$file"
}

# extract_frontmatter_field — read a top-level field from SKILL.md YAML frontmatter
# Usage: extract_frontmatter_field path/to/SKILL.md fieldname
# Note: only handles simple single-line fields (not nested or multi-line)
extract_frontmatter_field() {
  local file="$1" field="$2"
  awk -v f="$field" '
    /^---$/ { block++; next }
    block == 1 && $0 ~ "^"f":" {
      sub("^"f":[[:space:]]*", "")
      gsub(/"/, "")
      gsub(/'"'"'/, "")
      gsub(/[[:space:]]*$/, "")
      print
      exit
    }
    block >= 2 { exit }
  ' "$file"
}

# extract_description — read multi-line description from SKILL.md YAML frontmatter
# Handles both single-line and folded block scalar (>-) descriptions
extract_description() {
  local file="$1"
  awk '
    /^---$/ { block++; next }
    block >= 2 { exit }
    block == 1 && /^description:/ {
      # Check for >- or > (folded block scalar)
      if ($0 ~ /^description:[[:space:]]*>-?[[:space:]]*$/) {
        # Multi-line: read continuation lines (indented) from same input stream
        while ((getline line) > 0) {
          if (line ~ /^[[:space:]]+[^[:space:]]/) {
            sub(/^[[:space:]]+/, "", line)
            desc = desc (desc ? " " : "") line
          } else {
            break
          }
        }
        print desc
      } else {
        # Single-line
        sub(/^description:[[:space:]]*/, "")
        gsub(/"/, "")
        gsub(/'"'"'/, "")
        print
      }
      exit
    }
  ' "$file"
}

# increment_semver — bump a semver string by patch, minor, or major
# Pre-release suffixes are stripped (any bump graduates to release)
# Usage: increment_semver "1.0.0-beta.1" "minor" → "1.1.0"
increment_semver() {
  local version="$1" bump="$2"
  # Strip pre-release suffix: 1.0.0-beta.1 → 1.0.0
  local base="${version%%-*}"
  local major minor patch
  IFS='.' read -r major minor patch <<< "$base"
  case "$bump" in
    major) echo "$((major + 1)).0.0" ;;
    minor) echo "${major}.$((minor + 1)).0" ;;
    patch) echo "${major}.${minor}.$((patch + 1))" ;;
    *) echo "ERROR: unknown bump type '$bump'" >&2; return 1 ;;
  esac
}

# bump_priority — return numeric priority for bump type comparison
# major(3) > minor(2) > patch(1)
bump_priority() {
  case "$1" in
    major) echo 3 ;; minor) echo 2 ;; patch) echo 1 ;; *) echo 0 ;;
  esac
}

# replace_version_in_frontmatter — update metadata.version in a SKILL.md file
# Uses portable temp-file pattern (works on both macOS and Linux)
# Usage: replace_version_in_frontmatter path/to/SKILL.md "old_version" "new_version"
replace_version_in_frontmatter() {
  local file="$1" old="$2" new="$3"
  local tmp="${file}.tmp"
  # Only replace within the YAML frontmatter block, on lines matching version:
  # Uses index() for fixed-string match (not regex) so dots are literal
  awk -v old="$old" -v new="$new" '
    /^---$/ { block++ }
    block == 1 && /^[[:space:]]+version:/ && index($0, old) {
      pos = index($0, old)
      $0 = substr($0, 1, pos - 1) new substr($0, pos + length(old))
    }
    { print }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}
