#!/usr/bin/env bash
# Auto-Format Hook — formats edited files using the project-appropriate tool.
# PostToolUse[Edit|Write] hook.
#
# Strategy:
#   1. Check whether the file belongs to any registered project.
#      - If the project's `projects/{shortname}.md` / `repos.conf` marks it
#        as "format-owned" (i.e. has its own project-level hook), skip here.
#   2. Otherwise, format by file extension using the standard tool for that
#      language — but only if the tool is available on PATH.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

REPOS_ENV="$HOME/.claude/project-repos.env"
[ -f "$REPOS_ENV" ] && source "$REPOS_ENV"

# Projects that own their own format hook (opt-out of global auto-format).
# Set FORMAT_OWNED_PROJECTS in `project-repos.local.env` as a space-separated
# list of env-var names, e.g.:
#   FORMAT_OWNED_PROJECTS="PROJECT_REPO_WEB PROJECT_REPO_MOBILE"
for var in ${FORMAT_OWNED_PROJECTS:-}; do
  path="${!var:-}"
  if [[ -n "$path" && "$FILE_PATH" == "$path/"* ]]; then
    exit 0
  fi
done

case "$FILE_PATH" in
  *.dart)
    if command -v fvm >/dev/null 2>&1; then
      fvm dart format "$FILE_PATH" >/dev/null 2>&1
    elif command -v dart >/dev/null 2>&1; then
      dart format "$FILE_PATH" >/dev/null 2>&1
    fi
    ;;
  *.kt|*.kts)
    if command -v ktlint >/dev/null 2>&1; then
      ktlint -F "$FILE_PATH" >/dev/null 2>&1
    fi
    ;;
  *.go)
    if command -v gofmt >/dev/null 2>&1; then
      gofmt -w "$FILE_PATH" >/dev/null 2>&1
    fi
    ;;
  *.ts|*.tsx|*.js|*.jsx)
    # Prefer a project-local prettier (honours project config) — walk up from
    # the file until we find one. Fall back to global `prettier` on PATH.
    SEARCH_DIR=$(dirname "$FILE_PATH")
    PRETTIER_BIN=""
    while [ "$SEARCH_DIR" != "$HOME" ] && [ "$SEARCH_DIR" != "/" ]; do
      if [ -x "$SEARCH_DIR/node_modules/.bin/prettier" ]; then
        PRETTIER_BIN="$SEARCH_DIR/node_modules/.bin/prettier"
        break
      fi
      SEARCH_DIR=$(dirname "$SEARCH_DIR")
    done
    if [ -n "$PRETTIER_BIN" ]; then
      "$PRETTIER_BIN" --write "$FILE_PATH" >/dev/null 2>&1
    elif command -v prettier >/dev/null 2>&1; then
      prettier --write "$FILE_PATH" >/dev/null 2>&1
    fi
    ;;
  *.py)
    if command -v ruff >/dev/null 2>&1; then
      ruff format "$FILE_PATH" >/dev/null 2>&1
    elif command -v black >/dev/null 2>&1; then
      black -q "$FILE_PATH" >/dev/null 2>&1
    fi
    ;;
esac

exit 0
