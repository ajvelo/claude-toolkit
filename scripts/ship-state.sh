#!/bin/bash
# Per-ticket pipeline state for /ship and /monitor. One markdown file per ticket
# with flat `key: value` frontmatter; the body is free-form and edited by Claude.
set -euo pipefail

WORK_DIR="${SHIP_WORK_DIR:-$HOME/.claude/work}"
DONE_DIR="$WORK_DIR/done"
TEMPLATE="$(dirname "$(readlink -f "$0")")/../.claude/skills/ship/state-template.md"

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
path_for() { echo "$WORK_DIR/$1.md"; }

usage() {
  cat <<'EOF'
Usage: ship-state <command> [args]
  init <KEY> [source]          create state file from template (no-op if it exists, here or in done/)
  path <KEY>                   print the state file path
  get <KEY> <field>            print one frontmatter field
  set <KEY> <field> <value>    set one frontmatter field (bumps `updated`)
  claim <KEY> <owner> [ttl]    take the lock unless anyone holds it, including <owner> (ttl minutes, default 30)
  renew <KEY> <owner>          refresh a lock <owner> already holds (long-running work: renew every ~20 min)
  release <KEY> <owner>        drop the lock if <owner> holds it
  list                         in-flight tickets as a table
  awaiting                     tickets parked at a gate
  awaiting-count [--tmux]      number of parked tickets (--tmux prints nothing when 0)
  due                          tickets in stage monitor whose next_check has passed
  pending                      what a tick would do; exit 1 when there is nothing (cheap idle check)
  summary <KEY>                frontmatter + Next step, for context injection
  digest [--mark | --since ISO] log lines since you last looked (--mark records now as seen)
  notify <message>             ring the ship:work window and send a desktop notification
  issue <KEY> <stage> <text> [--new]  append to issues.log; if <KEY> <stage> already has a line, print it and exit 2 unless --new
  archive <KEY>                move a finished ticket to done/
EOF
}

field() {
  awk -v k="$2" '
    NR==1 && $0=="---" {fm=1; next}
    fm && $0=="---" {exit}
    fm && ($0==k":" || index($0, k": ")==1) {v=substr($0, length(k)+2); sub(/^ /, "", v); print v; exit}
  ' "$1"
}

set_field() {
  local file="$1" key="$2" val tmp
  val="$(printf '%s' "$3" | tr '\n\r' '  ')"
  tmp="$(mktemp "$WORK_DIR/.tmp.XXXXXX")"
  SF_KEY="$key" SF_VAL="$val" SF_TS="$(now)" awk '
    BEGIN {k=ENVIRON["SF_KEY"]; v=ENVIRON["SF_VAL"]; ts=ENVIRON["SF_TS"]}
    NR==1 && $0=="---" {fm=1; print; next}
    fm && $0=="---" {
      if (!seen) print k": "v
      if (k!="updated" && !useen) print "updated: "ts
      fm=0; print; next
    }
    fm && ($0==k":" || index($0, k": ")==1) {print (v=="" ? k":" : k": "v); seen=1; next}
    fm && k!="updated" && index($0, "updated: ")==1 {print "updated: "ts; useen=1; next}
    {print}
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

require() {
  local f
  f="$(path_for "$1")"
  [ -f "$f" ] || { echo "no state file for $1 ($f)" >&2; exit 1; }
  echo "$f"
}

# Exit 0 (and say why) when a ticket's PRs need the loop: merged/closed, a failed check,
# or a head commit with no QA result yet. Otherwise exit 1 with ci-running or review.
pr_attention() {
  local f="$1" url info state sha failed running open=0 waiting=review
  local urls; urls="$(awk '/^## Repos/ {on=1; next} on && /^## / {exit} on' "$f" | grep -oE 'https://github\.com/[^/ )]+/[^/ )]+/pull/[0-9]+' | sort -u)"
  [ -n "$urls" ] || { echo "no PR recorded"; return 0; }
  for url in $urls; do
    info="$(gh pr view "$url" --json state,headRefOid,statusCheckRollup --jq '[.state, .headRefOid[0:7],
      ([.statusCheckRollup[] | select((.conclusion // .state // "") | test("FAILURE|ERROR|CANCELLED|TIMED_OUT|ACTION_REQUIRED"))] | length),
      ([.statusCheckRollup[] | select((.status // "COMPLETED") != "COMPLETED" or (.state // "") == "PENDING")] | length)] | @tsv' 2>/dev/null)" \
      || { echo "gh pr view failed for $url"; return 0; }
    IFS=$'\t' read -r state sha failed running <<<"$info"
    case "$state" in
      MERGED) continue ;;
      CLOSED) echo "closed without merging: $url"; return 0 ;;
    esac
    open=$((open + 1))
    [ "$failed" -gt 0 ] && { echo "check failed on $url"; return 0; }
    grep -q "$sha" "$f" || { echo "new commit $sha on $url needs QA"; return 0; }
    [ "$running" -gt 0 ] && waiting=ci-running
  done
  [ "$open" -eq 0 ] && { echo "all PRs merged"; return 0; }
  echo "$waiting"; return 1
}

# Ring the ship:work window and send a desktop notification through tmux to the terminal
# (cmux flags the tab). Silent when there is no ship session.
notify() {
  local session="${SHIP_TMUX_SESSION:-ship}" tty
  tty="$(tmux display -p -t "$session:work" '#{pane_tty}' 2>/dev/null)" || return 0
  [ -w "$tty" ] || return 0
  printf '\a\ePtmux;\e\e]9;%s\a\e\\' "$1" >"$tty" 2>/dev/null || true
}

to_epoch() {
  [ -n "$1" ] || { echo 0; return; }
  date -u -d "$1" +%s 2>/dev/null || date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s 2>/dev/null || echo 0
}

# flock where it exists (Linux); a mkdir lock elsewhere (macOS has no flock).
with_lock() {
  local lockdir="$1.lockdir"
  for _ in $(seq 1 50); do mkdir "$lockdir" 2>/dev/null && return 0; sleep 0.2; done
  return 1
}

files() { find "$WORK_DIR" -maxdepth 1 -name '*.md' 2>/dev/null | sort; }

mkdir -p "$WORK_DIR" "$DONE_DIR"
cmd="${1:-}"; shift || true

case "$cmd" in
  init)
    key="${1:?ticket key}"; src="${2:-manual}"; f="$(path_for "$key")"
    if [ -f "$f" ]; then echo "$f"; exit 0; fi
    if [ -f "$DONE_DIR/$key.md" ]; then echo "$DONE_DIR/$key.md"; exit 0; fi
    [ -f "$TEMPLATE" ] || { echo "template missing: $TEMPLATE" >&2; exit 1; }
    ts="$(now)"
    sed -e "s/{{KEY}}/$key/g" -e "s/{{SOURCE}}/$src/g" -e "s/{{NOW}}/$ts/g" "$TEMPLATE" > "$f"
    echo "$f"
    ;;
  path) path_for "${1:?ticket key}" ;;
  get) f="$(require "${1:?ticket key}")"; field "$f" "${2:?field}" ;;
  set)
    f="$(require "${1:?ticket key}")"; set_field "$f" "${2:?field}" "${3-}"
    if [ "$2" = awaiting ] && [ -n "${3-}" ] && [ "$3" != none ]; then notify "ship: $1 is waiting on you ($3)"; fi
    ;;
  notify) notify "${1:?message}" ;;
  issue)
    key="${1:?ticket key}"; stage="${2:?stage}"; text="${3:?text}"; log="$WORK_DIR/issues.log"
    if [ "${4:-}" != "--new" ] && grep -sF " $key $stage: " "$log"; then
      echo "already logged for $key $stage (above); append only a different problem, with --new" >&2
      exit 2
    fi
    printf '%s %s %s: %s\n' "$(now)" "$key" "$stage" "$(printf '%s' "$text" | tr '\n\r' '  ')" >>"$log"
    ;;
  digest)
    seen_file="$WORK_DIR/.last-seen"; since="${2:-$(cat "$seen_file" 2>/dev/null || echo 1970-01-01T00:00:00Z)}"
    [ "${1:-}" = "--since" ] || since="$(cat "$seen_file" 2>/dev/null || echo 1970-01-01T00:00:00Z)"
    echo "since $since:"
    for f in "$WORK_DIR"/*.md "$DONE_DIR"/*.md; do
      [ -f "$f" ] || continue
      key="$(basename "$f" .md)"
      awk -v since="$since" -v key="$key" '
        match($0, /^- [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}(:[0-9]{2})?Z/) {
          ts=substr($0, 3, RLENGTH-2); if (length(ts) == 17) ts=substr(ts, 1, 16) ":00Z"
          if (ts > since) print key ": " substr($0, 3, 220)
        }' "$f"
    done | sort -t' ' -k2
    [ "${1:-}" = "--mark" ] && now >"$seen_file"
    exit 0
    ;;
  claim|renew)
    key="${1:?ticket key}"; owner="${2:?owner}"; ttl="${3:-30}"; f="$(require "$key")"
    if command -v flock >/dev/null; then
      exec 9>"$f.lock"; flock -w 10 9 || { echo "busy" >&2; exit 1; }
    else
      with_lock "$f" || { echo "busy" >&2; exit 1; }
      trap 'rmdir "$f.lockdir" 2>/dev/null' EXIT
    fi
    lock="$(field "$f" lock)"
    holder="${lock%@*}"; since="${lock#*@}"
    if [ "$cmd" = renew ]; then
      [ "$holder" = "$owner" ] || { echo "not held by $owner (held by ${holder:-nobody})" >&2; exit 1; }
    elif [ -n "$lock" ]; then
      age=$(( ( $(date -u +%s) - $(to_epoch "$since") ) / 60 ))
      if [ "$age" -lt "$ttl" ]; then
        echo "locked by $holder ${age}m ago" >&2; exit 1
      fi
    fi
    set_field "$f" lock "$owner@$(now)"
    ;;
  release)
    key="${1:?ticket key}"; owner="${2:?owner}"; f="$(require "$key")"
    lock="$(field "$f" lock)"
    [ "${lock%@*}" = "$owner" ] && set_field "$f" lock ""
    exit 0
    ;;
  list)
    printf '%-14s %-10s %-16s %-21s %s\n' TICKET STAGE AWAITING UPDATED SUMMARY
    while read -r f; do
      [ -n "$f" ] || continue
      printf '%-14s %-10s %-16s %-21s %s\n' \
        "$(field "$f" ticket)" "$(field "$f" stage)" "$(field "$f" awaiting)" \
        "$(field "$f" updated)" "$(field "$f" summary | cut -c1-60)"
    done < <(files)
    ;;
  awaiting)
    while read -r f; do
      [ -n "$f" ] || continue
      a="$(field "$f" awaiting)"
      [ -n "$a" ] && [ "$a" != "none" ] && echo "$(field "$f" ticket) $a"
    done < <(files)
    exit 0
    ;;
  awaiting-count)
    n="$("$0" awaiting | wc -l | tr -d ' ')"
    if [ "${1:-}" = "--tmux" ]; then
      [ "$n" -gt 0 ] && printf '#[fg=colour214,bold]ship:%s waiting #[default]' "$n"
      exit 0
    fi
    echo "$n"
    ;;
  due)
    t="$(date -u +%s)"
    while read -r f; do
      [ -n "$f" ] || continue
      [ "$(field "$f" stage)" = "monitor" ] || continue
      a="$(field "$f" awaiting)"; [ -z "$a" ] || [ "$a" = "none" ] || continue
      nc="$(field "$f" next_check)"
      [ "$(to_epoch "$nc")" -le "$t" ] && field "$f" ticket
    done < <(files)
    exit 0
    ;;
  pending)
    work=0; owned=""
    while read -r f; do
      [ -n "$f" ] || continue
      key="$(field "$f" ticket)"; stage="$(field "$f" stage)"; a="$(field "$f" awaiting)"
      case "$stage" in
        pickup|plan|implement)
          [ "$a" = reassigned ] || [ "$(field "$f" assignee_override)" = yes ] || owned="${owned:+$owned,}$key" ;;
      esac
      [ -z "$a" ] || [ "$a" = "none" ] || continue
      case "$stage" in
        pickup|plan) echo "advance $key $stage"; work=1 ;;
        pr)
          if why="$(pr_attention "$f")"; then echo "advance $key pr ($why)"; work=1; else echo "wait $key pr ($why)"; fi ;;
        implement) [ "$(field "$f" mode)" = "loop" ] && { echo "advance $key implement"; work=1; } ;;
      esac
    done < <(files)
    for key in $("$0" due); do echo "monitor $key"; work=1; done
    if [ -n "$owned" ]; then
      jql="key in ($owned) AND (assignee != currentUser() OR assignee is EMPTY)"
      for key in $(ship-jira search "$jql" 2>/dev/null); do
        echo "reassigned $key"; work=1
      done
    fi
    jql='assignee = currentUser() AND labels = claude-ready AND statusCategory = "To Do"'
    if keys="$(ship-jira search "$jql" 2>/dev/null)"; then
      for key in $keys; do
        [ -f "$WORK_DIR/$key.md" ] || [ -f "$DONE_DIR/$key.md" ] || { echo "intake $key"; work=1; }
      done
    else
      echo "intake-error (ship-jira search failed)"; work=1
    fi
    [ "$work" = 1 ] || { echo "idle"; exit 1; }
    ;;
  summary)
    f="$(require "${1:?ticket key}")"
    awk 'NR==1 && $0=="---" {fm=1; next} fm && $0=="---" {fm=0; next} fm {print}' "$f"
    awk '/^## Next step/ {on=1; next} on && /^## / {exit} on {print}' "$f"
    ;;
  archive)
    f="$(require "${1:?ticket key}")"
    mv "$f" "$DONE_DIR/"
    echo "$DONE_DIR/$(basename "$f")"
    ;;
  *) usage; [ -z "$cmd" ] || exit 1 ;;
esac
