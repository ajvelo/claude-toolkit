#!/bin/bash
# Write Guard Hook - Blocks editing sensitive files
# PreToolUse[Write|Edit] hook

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

# Extract the file path from the JSON input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Get just the filename
FILENAME=$(basename "$FILE_PATH")

# --- Block .env files ---
if echo "$FILENAME" | grep -qE '^\.(env|env\..*)$'; then
  deny "BLOCKED: Cannot edit environment file '$FILENAME'. Edit .env files manually."
fi

# --- Block key/certificate files ---
if echo "$FILENAME" | grep -qiE '\.(keystore|jks|pem|key|p12|pfx)$'; then
  deny "BLOCKED: Cannot edit key/certificate file '$FILENAME'."
fi

# --- Block credentials/secrets files ---
if echo "$FILENAME" | grep -qiE '^(credentials\.json|secrets\.ya?ml|service[-_]?account\.json)$'; then
  deny "BLOCKED: Cannot edit credentials/secrets file '$FILENAME'."
fi

# --- Block already-committed Flyway migration files ---
if echo "$FILE_PATH" | grep -qE '/db/migration/.*\.sql$|/flyway/.*\.sql$|/resources/db/.*\.sql$'; then
  # Check if the file is tracked by git (already committed)
  FILE_DIR=$(dirname "$FILE_PATH")
  if cd "$FILE_DIR" 2>/dev/null && git log --oneline -1 -- "$FILE_PATH" >/dev/null 2>&1; then
    COMMITS=$(git log --oneline -1 -- "$FILE_PATH" 2>/dev/null)
    if [ -n "$COMMITS" ]; then
      deny "BLOCKED: Cannot edit already-committed Flyway migration '$FILENAME'. Create a new migration instead."
    fi
  fi
fi

# Allow everything else (exit 0 = allow, no JSON needed)
exit 0
