#!/bin/bash
# QA runtime for /ship: scripted Playwright web checks against a local dev server,
# a PR preview, or the staging site that runs the base branch.
#
# Per-repo URLs come from env vars named after the repos.conf shortname (upper-case):
#   SHIP_QA_PREVIEW_WEB='https://web-pr-{pr}.preview.example.com'   ({pr} is replaced)
#   SHIP_QA_BASE_WEB='https://staging.example.com'
# Hosts the checks may visit: SHIP_QA_ALLOWED_HOSTS (an extended regex), localhost always.
set -euo pipefail

WORK_DIR="${SHIP_WORK_DIR:-$HOME/.claude/work}"
RUNTIME="${SHIP_QA_RUNTIME:-$HOME/.local/share/ship-qa}"
PLAYWRIGHT_VERSION="${SHIP_QA_PLAYWRIGHT:-1.55.0}"
ALLOWED_HOSTS="^(localhost|127\.0\.0\.1)$"
[ -n "${SHIP_QA_ALLOWED_HOSTS:-}" ] && ALLOWED_HOSTS="^(localhost|127\.0\.0\.1|${SHIP_QA_ALLOWED_HOSTS})$"

usage() {
  cat <<'EOF'
Usage: ship-qa <command> [args]
  setup                         install the Playwright runtime + headless Chromium (no sudo)
  preview-url <repo> <pr>       print the PR preview URL (needs SHIP_QA_PREVIEW_<REPO>)
  base-url <repo>               print the URL running the base branch (needs SHIP_QA_BASE_<REPO>)
  web <KEY> <base-url> [label]  run ~/.claude/work/<KEY>/qa/web/*.cjs against base-url
                                (label: head SHA for the PR, "before" for the base branch)
EOF
}

host_of() { sed -E 's#^[a-z]+://##; s#[:/].*$##' <<<"$1"; }
repo_var() { echo "$1_$(echo "$2" | tr '[:lower:]-' '[:upper:]_')"; }

cmd="${1:-}"; shift || true
case "$cmd" in
  setup)
    mkdir -p "$RUNTIME"
    npm install --prefix "$RUNTIME" --no-fund --no-audit "playwright@$PLAYWRIGHT_VERSION" >/dev/null
    "$RUNTIME/node_modules/.bin/playwright" install chromium-headless-shell
    echo "ship-qa runtime ready: $RUNTIME (playwright $PLAYWRIGHT_VERSION)"
    ;;
  preview-url)
    var="$(repo_var SHIP_QA_PREVIEW "${1:?repo shortname}")"; pr="${2:?PR number}"
    tpl="${!var:-}"; [ -n "$tpl" ] || exit 1
    echo "${tpl//\{pr\}/$pr}"
    ;;
  base-url)
    var="$(repo_var SHIP_QA_BASE "${1:?repo shortname}")"
    [ -n "${!var:-}" ] || exit 1
    echo "${!var}"
    ;;
  web)
    key="${1:?ticket key}"; base="${2:?base url}"; sha="${3:-local}"
    [[ "$(host_of "$base")" =~ $ALLOWED_HOSTS ]] || { echo "refusing host not in SHIP_QA_ALLOWED_HOSTS: $base" >&2; exit 2; }
    [ -d "$RUNTIME/node_modules/playwright" ] || { echo "run: ship-qa setup" >&2; exit 2; }
    dir="$WORK_DIR/$key/qa/web"; out="$WORK_DIR/$key/qa/results/$sha"
    shopt -s nullglob; scripts=("$dir"/*.cjs)
    ((${#scripts[@]})) || { echo "no QA scripts in $dir" >&2; exit 2; }
    mkdir -p "$out"; status=0
    for s in "${scripts[@]}"; do
      name="$(basename "$s" .cjs)"
      if PW_LIB="$RUNTIME/node_modules/playwright" BASE_URL="${base%/}" OUT="$out" CHECK="$name" \
           timeout 300 node "$s" >"$out/$name.json" 2>"$out/$name.err"; then
        echo "PASS $name"
      else
        echo "FAIL $name: $(tail -c 300 "$out/$name.err" | tr '\n' ' ')"; status=1
      fi
    done
    echo "results: $out"
    exit $status
    ;;
  *) usage; [ -z "$cmd" ] || exit 1 ;;
esac
