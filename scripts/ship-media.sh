#!/bin/bash
# Run on your laptop when the loop lives on a remote box: copy a ticket's before/after
# QA videos and open the folder, ready to drag into a PR comment.
#   SHIP_REMOTE=user@build-box ship-media API-42 [destination]
# Without SHIP_REMOTE the videos are read from this machine.
set -euo pipefail

KEY="${1:?usage: ship-media <TICKET-KEY> [destination]}"
DEST="${2:-$HOME/Downloads/$KEY-qa}"
SRC=".claude/work/$KEY/qa/media"

mkdir -p "$DEST"
if [ -n "${SHIP_REMOTE:-}" ]; then
  scp -q -r "$SHIP_REMOTE:$SRC/." "$DEST/"
else
  cp -R "$HOME/$SRC/." "$DEST/"
fi
ls -1 "$DEST"
if command -v open >/dev/null 2>&1; then open "$DEST"; elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$DEST"; fi
