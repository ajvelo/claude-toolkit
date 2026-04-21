#!/bin/bash
# Notification Hook - Shows desktop notification
# Notification[*] hook

INPUT=$(cat 2>/dev/null)
MESSAGE=$(echo "$INPUT" | jq -r '.message // .title // .notification // .content // "Task completed"' 2>/dev/null)

[ -z "$MESSAGE" ] && MESSAGE="Task completed"

# Truncate long messages for notification display
if [ ${#MESSAGE} -gt 200 ]; then
  MESSAGE="${MESSAGE:0:197}..."
fi

# macOS
if command -v osascript >/dev/null 2>&1; then
  ESCAPED=$(echo "$MESSAGE" | sed 's/\\/\\\\/g; s/"/\\"/g')
  osascript -e "display notification \"$ESCAPED\" with title \"Claude Code\" sound name \"Glass\"" 2>/dev/null
# Linux
elif command -v notify-send >/dev/null 2>&1; then
  notify-send "Claude Code" "$MESSAGE" 2>/dev/null
fi

exit 0
