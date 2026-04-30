#!/usr/bin/env bash
# validate-skills.sh — validate SKILL.md frontmatter for all skills
# Uses `skills ls --json` for canonical skill list, then checks metadata
# Called by: pnpm run validate, CI pipeline
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

source "$(dirname "$0")/lib.sh"

echo "Validating skill metadata..."

errors=0
warnings=0

# Use skills CLI for canonical skill list (name + path)
skill_data=$(cd "$REPO_ROOT" && pnpx skills ls --json 2>/dev/null || true)

if [ -z "$skill_data" ] || [ "$skill_data" = "[]" ]; then
  # Fallback to directory scan if CLI unavailable
  echo "  (skills CLI unavailable, scanning directories)"
  for skill_dir in "$REPO_ROOT"/skills/*/; do
    [ ! -d "$skill_dir" ] && continue
    skill="$(basename "$skill_dir")"
    skill_md="$skill_dir/SKILL.md"

    if [ ! -f "$skill_md" ]; then
      echo "  ERROR: $skill/ missing SKILL.md"
      errors=$((errors + 1))
      continue
    fi

    name=$(extract_frontmatter_field "$skill_md" "name")
    if [ "$name" != "$skill" ]; then
      echo "  ERROR: $skill/SKILL.md name '$name' does not match directory '$skill'"
      errors=$((errors + 1))
    fi

    version=$(extract_version "$skill_md")
    if [ -z "$version" ]; then
      echo "  ERROR: $skill/SKILL.md missing metadata.version"
      errors=$((errors + 1))
    fi

    if [ ! -f "$skill_dir/README.md" ]; then
      echo "  WARN: $skill/ missing README.md"
      warnings=$((warnings + 1))
    fi

    license=$(extract_frontmatter_field "$skill_md" "license")
    if [ -z "$license" ]; then
      echo "  WARN: $skill/SKILL.md missing license field"
      warnings=$((warnings + 1))
    fi
  done
else
  # Use CLI output: name validated by the parser, path is canonical
  echo "$skill_data" | jq -r '.[] | "\(.name)\t\(.path)"' | while IFS=$'\t' read -r name skill_path; do
    [ -z "$name" ] && continue
    skill_md="$skill_path/SKILL.md"

    # metadata.version must be present
    version=$(extract_version "$skill_md")
    if [ -z "$version" ]; then
      echo "  ERROR: $name/SKILL.md missing metadata.version"
      errors=$((errors + 1))
    fi

    # README.md must exist
    if [ ! -f "$skill_path/README.md" ]; then
      echo "  WARN: $name/ missing README.md"
      warnings=$((warnings + 1))
    fi

    # license should be present
    license=$(extract_frontmatter_field "$skill_md" "license")
    if [ -z "$license" ]; then
      echo "  WARN: $name/SKILL.md missing license field"
      warnings=$((warnings + 1))
    fi
  done
fi

echo ""
if [ $errors -gt 0 ]; then
  echo "Validation failed: $errors error(s), $warnings warning(s)"
  exit 1
fi

echo "All skills valid ($warnings warning(s))"
