#!/bin/bash
# Bash Safety Hook - Blocks dangerous operations
# PreToolUse[Bash] hook

# Safety net: if anything goes wrong, allow the command
trap 'exit 0' ERR

# Emit a "deny" decision with the given reason, then exit.
deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# Read tool input from stdin
INPUT=$(cat)

# Extract the command from the JSON input
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Protected branches pattern
PROTECTED_BRANCHES="main|master|develop|dev|release"

# --- Block force push to protected branches ---
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*--force|git\s+push\s+.*--force-with-lease|git\s+push\s+.*-f\b'; then
  if echo "$COMMAND" | grep -qE "\b(origin|upstream)\s+($PROTECTED_BRANCHES)\b"; then
    deny "BLOCKED: Force push to protected branch. Use a feature branch instead."
  fi
  # Also block push --force without explicit branch (defaults to current which might be protected)
  if ! echo "$COMMAND" | grep -qE 'git\s+push\s+.*\s+\S+'; then
    deny "BLOCKED: Force push without explicit branch target. Specify the branch explicitly."
  fi
fi

# --- Block git reset --hard on protected branches ---
if echo "$COMMAND" | grep -qE 'git\s+reset\s+--hard'; then
  # Check if we're on a protected branch
  CURRENT_DIR=$(echo "$INPUT" | jq -r '.tool_input.workdir // "."' 2>/dev/null)
  CURRENT_BRANCH=$(cd "$CURRENT_DIR" 2>/dev/null && git branch --show-current 2>/dev/null)
  if echo "$CURRENT_BRANCH" | grep -qE "^($PROTECTED_BRANCHES)$"; then
    deny "BLOCKED: git reset --hard on protected branch '$CURRENT_BRANCH'. Stash or create a new branch instead."
  fi
fi

# --- Block git add . / git add -A when .env files exist ---
if echo "$COMMAND" | grep -qE 'git\s+add\s+(\.|--all|-A)\b'; then
  # Try to detect the working directory
  WORK_DIR="."
  if echo "$COMMAND" | grep -qE '^\s*cd\s+([^ ;]+)'; then
    WORK_DIR=$(echo "$COMMAND" | grep -oE '^\s*cd\s+([^ ;]+)' | awk '{print $2}')
  fi
  # Check for .env files in the working tree
  if find "$WORK_DIR" -maxdepth 3 -name ".env*" -not -path "*/.git/*" -not -path "*/node_modules/*" 2>/dev/null | head -1 | grep -q .; then
    deny "BLOCKED: git add . with .env files present. Stage specific files instead to avoid committing secrets."
  fi
fi

# --- Block deletion of protected branches ---
if echo "$COMMAND" | grep -qE 'git\s+branch\s+.*-[dD]\s+'; then
  if echo "$COMMAND" | grep -qE "\b($PROTECTED_BRANCHES)\b"; then
    deny "BLOCKED: Cannot delete protected branch."
  fi
fi

# --- Block --no-verify on commits ---
if echo "$COMMAND" | grep -qE 'git\s+commit\s+.*--no-verify'; then
  deny "BLOCKED: --no-verify bypasses pre-commit hooks. Fix the hook issue instead."
fi

# --- Block git clean with -f flag ---
if echo "$COMMAND" | grep -qE 'git\s+clean\s+.*-[a-zA-Z]*f'; then
  deny "BLOCKED: git clean with -f flag. This permanently deletes untracked files. Use git stash instead."
fi

# --- Block git checkout . / git restore . ---
if echo "$COMMAND" | grep -qE 'git\s+(checkout|restore)\s+\.\s*$'; then
  deny "BLOCKED: This discards all unstaged changes. Use git stash or stage specific files."
fi

# --- Block direct production deployment commands ---
if echo "$COMMAND" | grep -qE 'kubectl\s+.*--context.*prod|helm\s+.*install.*prod|docker\s+push.*prod'; then
  deny "BLOCKED: Direct production deployment. Use the CI/CD pipeline instead."
fi

# Allow everything else (exit 0 = allow, no JSON needed)
exit 0
