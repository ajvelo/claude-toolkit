#!/bin/bash
# The 24/7 /ship tmux session:
#   window "loop" — unattended `/loop /ship tick`, relaunched if claude exits
#   window "work" — your interactive session for clearing gates (`/ship`)
#
#   ship-up   (ship-loop up)    create the session if needed, start the loop, open a fresh
#                               work Claude if work is idle, then attach
#   ship-down (ship-loop down)  stop every Claude in the session; tmux and its windows stay
#   ship-work (ship-loop work)  restart the work window with a fresh `claude '/ship'`
#   ship-loop status            whether each window is running Claude, and whether the loop is up
#   ship-loop here              the session:window this command runs in (empty outside tmux)
set -euo pipefail

SESSION="${SHIP_TMUX_SESSION:-ship}"
SELF="$(readlink -f "$0")"
TOOLKIT="$(cd "$(dirname "$SELF")/.." && pwd)"
CLAUDE_BIN="${SHIP_CLAUDE:-claude}"
LOOP_CMD="SHIP_CLAUDE=$CLAUDE_BIN $SELF --run-loop"
WORK_CMD="$CLAUDE_BIN '/ship'; exec \$SHELL"

case "$(basename "$0")" in
  ship-up) set -- up "$@" ;;
  ship-down) set -- down "$@" ;;
  ship-work) set -- work "$@" ;;
esac

if [ "${1:-}" = "--run-loop" ]; then
  export SHIP_UNATTENDED=1
  while true; do
    "${SHIP_CLAUDE:-claude}" "/loop /ship tick" || true
    echo "[ship-loop] claude exited at $(date -u +%FT%TZ); restarting in 60s (Ctrl-C to stop)"
    sleep 60
  done
fi

command -v tmux >/dev/null || { echo "tmux not installed" >&2; exit 1; }

loop_running() { pgrep -u "$(id -u)" -fx '/bin/bash .*/ship-loop\.sh --run-loop' >/dev/null; }
# The window this command was typed in, if it's inside the ship session: handled last,
# because respawning it kills this script.
here() { [ -n "${TMUX_PANE:-}" ] && tmux display -p -t "$TMUX_PANE" '#{session_name}:#{window_name}' 2>/dev/null; }
runs_claude() {
  local c
  [ "$(ps -o comm= -p "$1" 2>/dev/null)" = claude ] && return 0
  for c in $(pgrep -P "$1"); do runs_claude "$c" && return 0; done
  return 1
}
# pane_current_command can't see claude: the pane's shell stays in the foreground while it runs.
pane_idle() {
  local pid
  pid="$(tmux display -p -t "$1" '#{pane_pid}' 2>/dev/null)"
  [ -z "$pid" ] || ! runs_claude "$pid"
}
has_window() { tmux list-windows -t "$SESSION" -F '#W' 2>/dev/null | grep -qx "$1"; }
attach_session() {
  if [ -n "${TMUX:-}" ]; then exec tmux switch-client -t "$SESSION"; else exec tmux attach -t "$SESSION"; fi
}

case "${1:-up}" in
  up)
    command -v "$CLAUDE_BIN" >/dev/null || { echo "$CLAUDE_BIN not on PATH" >&2; exit 1; }
    fresh=""
    if ! tmux has-session -t "$SESSION" 2>/dev/null; then
      fresh=1
      tmux new-session -d -s "$SESSION" -n loop -c "$TOOLKIT" "$LOOP_CMD"
      tmux new-window -t "$SESSION" -n work -c "$TOOLKIT" "$WORK_CMD"
    else
      has_window loop || tmux new-window -t "$SESSION:1" -n loop -c "$TOOLKIT" "$LOOP_CMD"
      has_window work || tmux new-window -t "$SESSION:2" -n work -c "$TOOLKIT" "$WORK_CMD"
      [ "$(here)" = "$SESSION:work" ] || { pane_idle "$SESSION:work" && tmux respawn-pane -k -t "$SESSION:work" -c "$TOOLKIT" "$WORK_CMD"; } || true
    fi
    tmux select-window -t "$SESSION:work"
    echo "ship: loop running, work ready"
    if [ -n "$fresh" ]; then
      :
    elif [ "$(here)" = "$SESSION:loop" ]; then
      loop_running || exec tmux respawn-pane -k -t "$SESSION:loop" -c "$TOOLKIT" "$LOOP_CMD"
    elif [ "$(here)" = "$SESSION:work" ]; then
      loop_running || tmux respawn-pane -k -t "$SESSION:loop" -c "$TOOLKIT" "$LOOP_CMD"
      exec tmux respawn-pane -k -t "$SESSION:work" -c "$TOOLKIT" "$WORK_CMD"
    else
      loop_running || tmux respawn-pane -k -t "$SESSION:loop" -c "$TOOLKIT" "$LOOP_CMD"
    fi
    [ "${2:-}" = "--no-attach" ] || attach_session
    ;;
  down)
    tmux has-session -t "$SESSION" 2>/dev/null || { echo "no $SESSION session"; exit 0; }
    last=""; stopped=""
    for w in loop work; do
      has_window "$w" || continue
      if { [ "$w" = loop ] && loop_running; } || ! pane_idle "$SESSION:$w"; then stopped="${stopped:+$stopped and }$w"; fi
      if [ "$(here)" = "$SESSION:$w" ]; then last="$w"; continue; fi
      tmux respawn-pane -k -t "$SESSION:$w" -c "$TOOLKIT" "${SHELL:-zsh}"
    done
    if [ -n "$last" ]; then
      echo "ship: Claude stopped in the other window; replacing this one with a shell"
      exec tmux respawn-pane -k -t "$SESSION:$last" -c "$TOOLKIT" "${SHELL:-zsh}"
    fi
    sleep 1
    if loop_running; then echo "loop still running, check: pgrep -af ship-loop" >&2; exit 1; fi
    if [ -n "$stopped" ]; then echo "ship: Claude stopped in $stopped; tmux session kept"; else echo "ship: nothing was running; tmux session kept"; fi
    ;;
  work)
    tmux has-session -t "$SESSION" 2>/dev/null || { echo "no $SESSION session: run ship-up" >&2; exit 1; }
    tmux respawn-pane -k -t "$SESSION:work" -c "$TOOLKIT" "$WORK_CMD"
    tmux select-window -t "$SESSION:work"
    [ "${2:-}" = "--no-attach" ] || attach_session
    ;;
  status)
    tmux has-session -t "$SESSION" 2>/dev/null || { echo "no $SESSION session"; exit 0; }
    for w in $(tmux list-windows -t "$SESSION" -F '#I:#W'); do
      if pane_idle "$SESSION:${w#*:}"; then echo "$w  no claude"; else echo "$w  claude"; fi
    done
    if loop_running; then echo "loop: running"; else echo "loop: stopped"; fi
    ;;
  here) here || true ;;
  *) sed -n '2,11p' "$SELF" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
