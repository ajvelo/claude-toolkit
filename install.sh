#!/usr/bin/env bash
# claude-toolkit installer
# Symlinks hooks into ~/.claude/hooks/, merges settings, installs project
# instructions, and discovers your project paths on disk.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
PROJECTS_DIR="$CLAUDE_DIR/projects"
REPOS_CONF="$SCRIPT_DIR/repos.conf"

# The env var namespace used for discovered repo paths. Per-project env vars
# are emitted as ${ENV_PREFIX}_<UPPER_SHORTNAME>=/abs/path.
ENV_PREFIX="${ENV_PREFIX:-PROJECT_REPO}"

echo "=== claude-toolkit installer ==="
echo ""

# --- Prerequisites ---
MISSING=()
command -v jq >/dev/null 2>&1 || MISSING+=("jq")
command -v claude >/dev/null 2>&1 || MISSING+=("claude (Claude Code CLI)")

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "ERROR: Missing prerequisites:"
  for dep in "${MISSING[@]}"; do
    echo "  - $dep"
  done
  echo ""
  echo "  brew install jq"
  echo "  Claude Code: https://docs.anthropic.com/en/docs/claude-code"
  exit 1
fi

# --- Directories ---
mkdir -p "$HOOKS_DIR"
echo "[1/6] Directories ready"

# --- Hooks ---
echo "[2/6] Symlinking hooks..."
for hook in "$SCRIPT_DIR/hooks/"*.sh; do
  name=$(basename "$hook")
  target="$HOOKS_DIR/$name"
  if [ -L "$target" ]; then
    rm "$target"
  elif [ -f "$target" ]; then
    echo "  WARNING: $target exists (not a symlink). Backing up to ${target}.bak"
    mv "$target" "${target}.bak"
  fi
  ln -s "$hook" "$target"
  echo "  $name -> linked"
done
chmod +x "$SCRIPT_DIR/hooks/"*.sh

# --- Settings merge ---
echo "[3/6] Configuring hooks in settings.json..."
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
TEMPLATE="$SCRIPT_DIR/templates/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
  EXISTING=$(cat "$SETTINGS_FILE")
  HOOKS_JSON=$(jq '.hooks' "$TEMPLATE")
  STATUSLINE_JSON=$(jq '.statusLine' "$TEMPLATE")
  PERMISSIONS_JSON=$(jq '.permissions' "$TEMPLATE")

  echo "$EXISTING" | jq \
    --argjson hooks "$HOOKS_JSON" \
    --argjson statusLine "$STATUSLINE_JSON" \
    --argjson permissions "$PERMISSIONS_JSON" \
    '. + {hooks: $hooks, statusLine: $statusLine, permissions: $permissions}' \
    > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
  echo "  Merged hooks into existing settings.json"
else
  cp "$TEMPLATE" "$SETTINGS_FILE"
  echo "  Created settings.json from template"
fi

# --- Repo discovery ---
echo "[4/6] Discovering repo locations..."
ENV_PREFIX="$ENV_PREFIX" bash "$SCRIPT_DIR/scripts/discover-repos.sh" "$@"

ENV_FILE="$CLAUDE_DIR/project-repos.env"
# shellcheck source=/dev/null
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

# --- Project instruction symlinks ---
echo "[5/6] Installing project-specific instructions..."
LINKED=0
# shellcheck disable=SC2034  # github_repo is part of the record but unused here
while IFS='|' read -r shortname github_repo project_file rest; do
  [[ "$shortname" =~ ^#.*$ || -z "$shortname" ]] && continue
  shortname=$(echo "$shortname" | xargs)
  project_file=$(echo "$project_file" | xargs)
  [ -z "$project_file" ] && continue

  varname="${ENV_PREFIX}_$(echo "$shortname" | tr '[:lower:]' '[:upper:]' | tr '-' '_')"
  repo_path="${!varname:-}"

  if [ -z "$repo_path" ] || [ ! -d "$repo_path" ]; then
    continue
  fi

  encoded=$(echo "$repo_path" | sed 's|/|-|g')
  target_dir="$PROJECTS_DIR/$encoded"
  mkdir -p "$target_dir"

  source_file="$SCRIPT_DIR/projects/$project_file"
  target_file="$target_dir/CLAUDE.md"

  if [ ! -f "$source_file" ]; then
    continue
  fi

  if [ -L "$target_file" ]; then
    rm "$target_file"
  elif [ -f "$target_file" ]; then
    if ! grep -q "claude-toolkit" "$target_file" 2>/dev/null; then
      echo "  WARNING: $target_file exists with custom content. Skipping $shortname."
      continue
    fi
    rm "$target_file"
  fi

  ln -s "$source_file" "$target_file"
  echo "  $shortname -> $target_file"
  LINKED=$((LINKED + 1))
done < "$REPOS_CONF"
echo "  $LINKED project instruction files linked"

# --- Summary ---
echo ""
echo "[6/6] Installation complete!"
echo ""
SKILL_COUNT=$(find "$SCRIPT_DIR/.claude/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
AGENT_COUNT=$(find "$SCRIPT_DIR/.claude/agents" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
HOOK_COUNT=$(find "$SCRIPT_DIR/hooks" -name "*.sh" | wc -l | tr -d ' ')

echo "=== Installed ==="
echo "  - $HOOK_COUNT hooks symlinked to ~/.claude/hooks/"
echo "  - $LINKED project instructions symlinked to ~/.claude/projects/"
echo "  - Hook config merged into ~/.claude/settings.json"
echo "  - $SKILL_COUNT skills available (.claude/skills/)"
echo "  - $AGENT_COUNT agents available (.claude/agents/)"
echo "  - Repo paths resolved to ~/.claude/project-repos.env + .json"
echo ""
echo "=== Customising repo paths ==="
echo "  Repos are auto-discovered in \$HOME, \$HOME/code, \$HOME/projects, etc."
echo "    export PROJECT_REPOS_DIR=/path/to/your/repos && ./install.sh"
echo "    ./install.sh --search-dir /custom/path"
echo "    ./install.sh --deep-scan     # scan git remotes (slower)"
echo "  Per-repo overrides go in ~/.claude/project-repos.local.env, e.g.:"
echo "    ${ENV_PREFIX}_API=/custom/path/to/api-repo"
echo ""
echo "=== Next steps ==="
echo "  1. Edit repos.conf to list your actual projects, then re-run ./install.sh"
echo "  2. Edit projects/*.md to describe each project's stack and conventions"
echo "  3. (Optional) Configure MCP servers (see docs/MCP-SETUP.md)"
echo "  4. Start Claude Code from this directory:  claude"
echo ""
