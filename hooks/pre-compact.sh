#!/usr/bin/env bash
# PreCompact Hook — injects git context before context compaction
# Captures branch, project, and uncommitted state so Claude retains key info.

trap 'exit 0' ERR

REPOS_ENV="$HOME/.claude/project-repos.env"
# shellcheck source=/dev/null
[ -f "$REPOS_ENV" ] && source "$REPOS_ENV"

CWD=$(pwd)
PROJECT="unknown"

# Iterate over all PROJECT_REPO_* env vars and match the longest prefix.
# Longest-prefix match so nested sub-repos (e.g. a workspace package inside
# another project) are matched before their parent.
BEST_MATCH_LEN=0
while IFS= read -r var; do
  path="${!var:-}"
  [ -z "$path" ] && continue
  if [[ "$CWD" == "$path"* ]] && (( ${#path} > BEST_MATCH_LEN )); then
    BEST_MATCH_LEN=${#path}
    # Derive shortname from env var name: PROJECT_REPO_FOO_BAR -> foo-bar
    PROJECT=$(echo "${var#PROJECT_REPO_}" | tr '[:upper:]_' '[:lower:]-')
  fi
done < <(compgen -v | grep '^PROJECT_REPO_')

SUMMARY="## Session Context (pre-compact)\n"
SUMMARY+="**Project:** $PROJECT\n"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null)
  TICKET=$(echo "$BRANCH" | grep -oE '[A-Z]+-[0-9]+' | head -1)
  SUMMARY+="**Branch:** $BRANCH\n"
  [ -n "$TICKET" ] && SUMMARY+="**Ticket:** $TICKET\n"

  DIRTY=$(git status --short 2>/dev/null | head -20)
  if [ -n "$DIRTY" ]; then
    SUMMARY+="**Uncommitted changes:**\n\`\`\`\n$DIRTY\n\`\`\`\n"
  fi

  # Try to determine base branch from upstream; fall back to main.
  BASE_BRANCH=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null | sed 's|^origin/||')
  [ -z "$BASE_BRANCH" ] && BASE_BRANCH="main"
  COMMITS=$(git log "origin/$BASE_BRANCH..HEAD" --oneline 2>/dev/null | head -10)
  if [ -n "$COMMITS" ]; then
    SUMMARY+="**Commits on branch:**\n\`\`\`\n$COMMITS\n\`\`\`\n"
  fi
fi

ESCAPED=$(printf '%s' "$SUMMARY" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g')

echo "{\"systemMessage\": \"$ESCAPED\"}"
