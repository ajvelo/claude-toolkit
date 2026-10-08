#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHIP_WORK_DIR="$(mktemp -d)"
export SHIP_WORK_DIR
trap 'rm -rf "$SHIP_WORK_DIR"' EXIT
S="$ROOT/scripts/ship-state.sh"
fails=0

expect() {
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$3', got '$2'"; fails=$((fails + 1)); fi
}

"$S" init API-1 >/dev/null
expect "init creates the file" "$(test -f "$SHIP_WORK_DIR/API-1.md" && echo yes)" yes
expect "init starts at pickup" "$("$S" get API-1 stage)" pickup
expect "init is a no-op for a known key" "$("$S" init API-1)" "$SHIP_WORK_DIR/API-1.md"

"$S" set API-1 stage plan
expect "set changes a field" "$("$S" get API-1 stage)" plan

"$S" claim API-1 loop 60
expect "claim records the owner" "$("$S" get API-1 lock | cut -d@ -f1)" loop
expect "a second claim is refused" "$("$S" claim API-1 interactive 60 2>/dev/null && echo taken || echo refused)" refused
"$S" release API-1 loop
expect "release clears the lock" "$("$S" get API-1 lock)" ""

"$S" set API-1 awaiting publish
expect "awaiting lists parked tickets" "$("$S" awaiting)" "API-1 publish"
expect "awaiting-count counts them" "$("$S" awaiting-count)" 1

"$S" init API-2 >/dev/null
"$S" set API-2 stage monitor
"$S" set API-2 next_check 2000-01-01T00:00:00Z
expect "due lists monitor tickets past next_check" "$("$S" due)" API-2
"$S" set API-2 next_check 2999-01-01T00:00:00Z
expect "due skips tickets not yet due" "$("$S" due)" ""

"$S" archive API-2 >/dev/null
expect "archive moves the file to done/" "$(test -f "$SHIP_WORK_DIR/done/API-2.md" && echo yes)" yes
expect "init finds archived keys" "$("$S" init API-2)" "$SHIP_WORK_DIR/done/API-2.md"

"$S" issue API-1 plan 'first problem'
expect "issue refuses a duplicate stage line" "$("$S" issue API-1 plan 'again' >/dev/null 2>&1; echo $?)" 2

[ "$fails" = 0 ] || { echo "$fails failed"; exit 1; }
echo "all passed"
