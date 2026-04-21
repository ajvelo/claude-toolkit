#!/usr/bin/env bash
# Statusline Hook — shows project context + Claude session info.
# Receives JSON on stdin with: model, context window usage, vim mode, etc.

INPUT=$(cat)

MODEL=$(echo "$INPUT" | jq -r '.model.display_name // empty' 2>/dev/null)
CTX_PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)
VIM_MODE=$(echo "$INPUT" | jq -r '.vim.mode // empty' 2>/dev/null)
CWD_JSON=$(echo "$INPUT" | jq -r '.workspace.current_dir // empty' 2>/dev/null)

RESET="\033[0m"
DIM="\033[2m"
BOLD="\033[1m"
CYAN="\033[36m"
BLUE="\033[34m"
MAGENTA="\033[35m"
YELLOW="\033[33m"
GREEN="\033[32m"
RED="\033[31m"

# --- Project detection ---
REPOS_ENV="$HOME/.claude/project-repos.env"
[ -f "$REPOS_ENV" ] && source "$REPOS_ENV"

CWD="${CWD_JSON:-$(pwd)}"
PROJECT="~"
ICON=""

# Longest-prefix match across all PROJECT_REPO_* env vars so nested paths win.
BEST_MATCH_LEN=0
while IFS= read -r var; do
  path="${!var:-}"
  [ -z "$path" ] && continue
  if [[ "$CWD" == "$path"* ]] && (( ${#path} > BEST_MATCH_LEN )); then
    BEST_MATCH_LEN=${#path}
    PROJECT=$(echo "${var#PROJECT_REPO_}" | tr '[:upper:]_' '[:lower:]-')
  fi
done < <(compgen -v | grep '^PROJECT_REPO_')

# --- Git info ---
BRANCH=""
TICKET=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null)
  if [ -n "$BRANCH" ]; then
    TICKET=$(echo "$BRANCH" | grep -oE '[A-Z]+-[0-9]+' | head -1)
  fi
fi

# --- Model short name ---
SHORT_MODEL=""
if [ -n "$MODEL" ]; then
  SHORT_MODEL=$(echo "$MODEL" | sed 's/^Claude //')
fi

# --- Context bar ---
CTX_DISPLAY=""
if [ -n "$CTX_PCT" ]; then
  PCT=$(printf "%.0f" "$CTX_PCT" 2>/dev/null || echo "$CTX_PCT")

  if [ "$PCT" -ge 90 ]; then
    BAR_COLOR="$RED"
    CTX_ICON=""
  elif [ "$PCT" -ge 70 ]; then
    BAR_COLOR="$YELLOW"
    CTX_ICON=""
  elif [ "$PCT" -ge 30 ]; then
    BAR_COLOR="$GREEN"
    CTX_ICON=""
  else
    BAR_COLOR="$CYAN"
    CTX_ICON=""
  fi

  WIDTH=15
  FILLED=$((PCT * WIDTH / 100))
  EMPTY=$((WIDTH - FILLED))
  BAR=""
  for ((i=0; i<FILLED; i++)); do BAR="${BAR}█"; done
  for ((i=0; i<EMPTY; i++)); do BAR="${BAR}░"; done

  CTX_DISPLAY="${CTX_ICON} ${BAR_COLOR}${BAR}${RESET} ${BOLD}${BAR_COLOR}${PCT}%${RESET}"
fi

# --- Vim mode ---
VIM_DISPLAY=""
if [ -n "$VIM_MODE" ]; then
  case "$VIM_MODE" in
    NORMAL)  VIM_DISPLAY="${BOLD}${BLUE} N${RESET}" ;;
    INSERT)  VIM_DISPLAY="${BOLD}${GREEN} I${RESET}" ;;
    VISUAL)  VIM_DISPLAY="${BOLD}${MAGENTA} V${RESET}" ;;
    *)       VIM_DISPLAY="${DIM}${VIM_MODE}${RESET}" ;;
  esac
fi

# --- Assemble status line ---
STATUS="${BOLD}${CYAN}${ICON}${PROJECT}${RESET}"

if [ -n "$BRANCH" ]; then
  STATUS="${STATUS} ${YELLOW}›${RESET} ${MAGENTA}${BRANCH}${RESET}"
fi

if [ -n "$TICKET" ]; then
  STATUS="${STATUS} ${DIM}(${YELLOW}${TICKET}${RESET}${DIM})${RESET}"
fi

RIGHT=""
if [ -n "$SHORT_MODEL" ]; then
  RIGHT="${BOLD}${BLUE}${SHORT_MODEL}${RESET}"
fi

if [ -n "$CTX_DISPLAY" ]; then
  [ -n "$RIGHT" ] && RIGHT="${RIGHT} ${DIM}│${RESET} "
  RIGHT="${RIGHT}${CTX_DISPLAY}"
fi

if [ -n "$VIM_DISPLAY" ]; then
  [ -n "$RIGHT" ] && RIGHT="${RIGHT} ${DIM}│${RESET} "
  RIGHT="${RIGHT}${VIM_DISPLAY}"
fi

if [ -n "$RIGHT" ]; then
  STATUS="${STATUS} ${DIM}│${RESET} ${RIGHT}"
fi

echo -e "$STATUS"
