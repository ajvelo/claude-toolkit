#!/usr/bin/env bash
# Plays a /ship walkthrough against made-up tickets in examples/ship-demo/.
# The ship-state and guard commands are real; the Claude session is a scripted replay.
#
# Usage:
#   ./examples/ship-demo.sh
#
# For a recording:
#   asciinema rec --headless --window-size 124x26 -c "./examples/ship-demo.sh" assets/ship-demo.cast
#   agg --theme monokai assets/ship-demo.cast assets/ship-demo.gif

set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO="/tmp/ship-demo"
rm -rf "$DEMO"
mkdir -p "$DEMO/work" "$DEMO/bin"
trap 'rm -rf "$DEMO"' EXIT
cp "$TOOLKIT_DIR/examples/ship-demo/"*.md "$DEMO/work/"
EARLIER="$(date -u -v-25M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '25 minutes ago' +%Y-%m-%dT%H:%M:%SZ)"
for f in "$DEMO/work/"*.md; do sed "s/^updated: .*/updated: $EARLIER/" "$f" >"$f.tmp" && mv "$f.tmp" "$f"; done

cat >"$DEMO/bin/gh" <<'EOF'
#!/usr/bin/env bash
[ "$1 $2" = "pr view" ] && printf 'OPEN\t4f1c2ab\t0\t0\n'
EOF
printf '#!/usr/bin/env bash\nexit 0\n' >"$DEMO/bin/ship-jira"
ln -s "$TOOLKIT_DIR/scripts/ship-state.sh" "$DEMO/bin/ship-state"
chmod +x "$DEMO/bin/"*
export PATH="$DEMO/bin:$PATH" SHIP_WORK_DIR="$DEMO/work"
COLS="${DEMO_COLS:-124}"

DIM=$'\033[2m'; BOLD=$'\033[1m'; GREEN=$'\033[32m'; ORANGE=$'\033[38;5;214m'; CYAN=$'\033[36m'; RESET=$'\033[0m'

type_cmd() {
  printf '%s$%s ' "$GREEN" "$RESET"
  local i
  for ((i = 0; i < ${#1}; i++)); do printf '%s' "${1:i:1}"; sleep 0.035; done
  sleep 0.4; printf '\n'
}
run() { type_cmd "$*"; "$@"; sleep 1.6; printf '\n'; }
say() { printf '%s# %s%s\n' "$DIM" "$1" "$RESET"; sleep 0.9; }
claude_line() { printf '%s\n' "$1"; sleep "${2:-0.5}"; }
status_bar() {
  printf '\033[48;5;236m\033[38;5;250m %s ship %s  1:loop  %s2:work%s %*s%sship:%s waiting%s  %s %s\n\n' \
    $'\033[48;5;31m\033[38;5;231m\033[1m' $'\033[22m\033[48;5;236m\033[38;5;250m' \
    $'\033[48;5;31m\033[38;5;231m' $'\033[48;5;236m\033[38;5;250m' "$((COLS - 47))" "" "$ORANGE$BOLD" "$1" \
    $'\033[22m\033[38;5;250m' "$(date +%H:%M)" "$RESET"
  sleep 1.4
}

clear
say "the loop runs in tmux window 1; you clear gates in window 2"
status_bar "$(ship-state awaiting-count)"

say "what's in flight (real ship-state output)"
run ship-state list

say "what a tick would do right now"
type_cmd "ship-state pending"; ship-state pending || true; sleep 1.8; printf '\n'

say "the unattended loop can't push: the guard blocks it and the ticket parks"
type_cmd "python3 hooks/ship_guard.py 'git push origin HEAD'"
printf '%sblocked:%s %s\n\n' "$ORANGE" "$RESET" "$(python3 -I "$TOOLKIT_DIR/hooks/ship_guard.py" 'git push origin HEAD' || true)"
sleep 1.8

sleep 0.6; clear
say "illustrative replay of a /ship session in the work window"
printf '%s>%s /ship\n\n' "$CYAN" "$RESET"; sleep 1
claude_line "● Since you last looked:"
claude_line "  WEB-214  implement → parked at publish: 1 test added, QA 3/3 on localhost"
claude_line "  API-87   pr: CI green on 4f1c2ab, waiting for review"
claude_line "  SRV-301  monitor: 4 ok, 0 regression, next check 15:20 UTC"
claude_line "  MOB-55   plan → parked at plan-approval" 1
claude_line ""
claude_line "● WEB-214 is ready to publish:"
claude_line "    branch  fix/WEB-214-empty-cart-banner   2 files, +38 −4"
claude_line "    commit  fix: show an empty-cart banner instead of a blank page (WEB-214)"
claude_line "    QA      empty-cart-banner ✓  checkout-disabled ✓  no-console-errors ✓" 1.2
claude_line ""
claude_line "  ❯ 1. Commit + push + draft PR"
claude_line "    2. Commit only"
claude_line "    3. Revise" 1.6
printf '\n%s>%s 1\n\n' "$CYAN" "$RESET"; sleep 0.8

ship-state set WEB-214 stage pr
ship-state set WEB-214 awaiting none
claude_line "● Pushed fix/WEB-214-empty-cart-banner"
claude_line "● Draft PR: https://github.com/example/demo-web/pull/42"
claude_line "● Queued for Jira: comment \"[claude] Draft PR: …\" + move to In Review" 1.6
printf '\n'

sleep 0.6; clear
say "back in the shell: WEB-214 moved to pr, one gate left"
run ship-state list
status_bar "$(ship-state awaiting-count)"
