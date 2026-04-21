#!/usr/bin/env bash
# Runs the real installer against a throwaway $HOME so you can record a
# demo without touching your actual ~/.claude/ setup.
#
# Usage:
#   ./examples/install-demo.sh
#
# For a recording:
#   asciinema rec -c "./examples/install-demo.sh" claude-toolkit.cast

set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SBOX="$(mktemp -d)"
trap 'rm -rf "$SBOX"' EXIT

# Stub out the bits the installer expects
mkdir -p "$SBOX/.claude" "$SBOX/code/demo-mobile" "$SBOX/code/demo-api" "$SBOX/code/demo-web"
echo '{}' > "$SBOX/.claude/settings.json"

# Give the demo repos just enough structure to be detected
(cd "$SBOX/code/demo-mobile" && git init -q && echo "name: mobile" > pubspec.yaml \
  && git add . && git -c user.email=demo@demo -c user.name=demo commit -qm init)
(cd "$SBOX/code/demo-api" && git init -q && echo 'plugins { id("kotlin") }' > build.gradle.kts \
  && git add . && git -c user.email=demo@demo -c user.name=demo commit -qm init)
(cd "$SBOX/code/demo-web" && git init -q && echo '{"name":"web"}' > package.json \
  && git add . && git -c user.email=demo@demo -c user.name=demo commit -qm init)

printf "\n\033[2m# running installer against sandboxed HOME=%s\033[0m\n\n" "$SBOX"
sleep 0.4

HOME="$SBOX" PROJECT_REPOS_DIR="$SBOX/code" SKIP_CLAUDE_CHECK=1 \
  bash "$TOOLKIT_DIR/install.sh"

# Show the results the installer wrote
printf "\n\033[1m# discovered paths (from ~/.claude/project-repos.json):\033[0m\n"
sleep 0.3
jq '.repos | to_entries[] | {key, path: .value.path, tech: .value.tech}' \
  "$SBOX/.claude/project-repos.json"

printf "\n\033[1m# hooks installed:\033[0m\n"
sleep 0.3
ls -la "$SBOX/.claude/hooks/" | awk 'NR>3 {print "  " $NF " -> " $(NF-2)}' | head -8

printf "\n\033[32m✓ Install complete. Sandbox will be cleaned up on exit.\033[0m\n\n"
