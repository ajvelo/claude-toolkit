#!/bin/bash
# Minimal Jira Cloud REST client for /ship and the loop. Shell scripts can't call
# the Atlassian MCP, so the pipeline uses this instead.
# Needs JIRA_HOST (e.g. yourteam.atlassian.net), JIRA_EMAIL and JIRA_API_TOKEN.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ship-jira <command> [args]
  search <JQL>                 print matching issue keys, one per line
  view <KEY>                   print key, status, assignee and summary as JSON
  comments <KEY>               print the issue's comments as JSON lines {id, body}
  comment <KEY> <text>         add a plain-text comment (gated in the unattended loop)
  transition <KEY> <status>    move the issue to the named status (gated in the loop)
EOF
}

: "${JIRA_HOST:?set JIRA_HOST, e.g. yourteam.atlassian.net}"
: "${JIRA_EMAIL:?set JIRA_EMAIL}"
: "${JIRA_API_TOKEN:?set JIRA_API_TOKEN}"
BASE="https://${JIRA_HOST#https://}/rest/api/3"

api() {
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    curl -fsS -u "$JIRA_EMAIL:$JIRA_API_TOKEN" -X "$method" -H 'Content-Type: application/json' \
      -H 'Accept: application/json' "$BASE$path" -d "$body"
  else
    curl -fsS -u "$JIRA_EMAIL:$JIRA_API_TOKEN" -X "$method" -H 'Accept: application/json' "$BASE$path"
  fi
}

cmd="${1:-}"; shift || true
case "$cmd" in
  search)
    jql="${1:?JQL}"
    api POST /search/jql "$(jq -n --arg jql "$jql" '{jql: $jql, fields: ["summary"], maxResults: 50}')" \
      | jq -r '.issues[].key'
    ;;
  view)
    api GET "/issue/${1:?KEY}?fields=status,assignee,summary,issuetype,description" \
      | jq '{key, status: .fields.status.name, statusCategory: .fields.status.statusCategory.key,
             assignee: .fields.assignee.displayName, summary: .fields.summary, type: .fields.issuetype.name}'
    ;;
  comments)
    api GET "/issue/${1:?KEY}/comment?maxResults=100" \
      | jq -c '.comments[] | {id, body: ([.body.content[]?.content[]?.text] | join(""))}'
    ;;
  comment)
    key="${1:?KEY}"; text="${2:?text}"
    api POST "/issue/$key/comment" "$(jq -n --arg t "$text" \
      '{body: {type: "doc", version: 1, content: [{type: "paragraph", content: [{type: "text", text: $t}]}]}}')" \
      | jq -r .id
    ;;
  transition)
    key="${1:?KEY}"; target="${2:?status name}"
    id="$(api GET "/issue/$key/transitions" | jq -r --arg s "$target" \
      '[.transitions[] | select((.to.name | ascii_downcase) == ($s | ascii_downcase) or (.name | ascii_downcase) == ($s | ascii_downcase))][0].id // empty')"
    [ -n "$id" ] || { echo "no transition to '$target' from the current status of $key" >&2; exit 1; }
    api POST "/issue/$key/transitions" "$(jq -n --arg id "$id" '{transition: {id: $id}}')" >/dev/null
    echo "$key -> $target"
    ;;
  *) usage; [ -z "$cmd" ] || exit 1 ;;
esac
