# Contributing

Thanks for considering a contribution. This is a personal toolkit but
contributions of any kind are welcome: typos, new skills, new hooks,
better gotchas, fixes.

## Getting started

Fork, clone, and run the installer against a sandbox `$HOME` so you
don't touch your real Claude Code setup while iterating:

```bash
SBOX=$(mktemp -d)
mkdir -p "$SBOX/.claude"
echo '{}' > "$SBOX/.claude/settings.json"
HOME="$SBOX" PROJECT_REPOS_DIR="$SBOX/code" SKIP_CLAUDE_CHECK=1 bash install.sh
```

## Development workflow

Most changes fall into one of four categories:

### Skills (`.claude/skills/{name}/SKILL.md`)
- Add or edit under `.claude/skills/`
- Valid frontmatter fields: `name`, `description`, `argument-hint`, `disable-model-invocation`, `user-invocable`
- CI validates frontmatter on every push, so a missing `name` or `description` fails fast

### Agents (`.claude/agents/{name}.md`)
- Add or edit under `.claude/agents/`
- Required frontmatter: `name`, `description`

### Hooks (`hooks/*.sh`)
- Run `shellcheck --severity=warning hooks/*.sh` before committing
- Add `# shellcheck disable=<code>` with a reason if a warning is intentional
- Keep hooks fail-open so a bad hook never breaks the user's session

### Knowledge (`knowledge/*.md`)
- Factual, non-speculative entries
- Lead with the rule, follow with *Why* and *How to apply* when it's a lesson from experience

## Running CI checks locally

```bash
# shell
shellcheck --severity=warning hooks/*.sh scripts/*.sh install.sh

# JSON
find . -name '*.json' -not -path './.git/*' -exec jq empty {} \;

# installer smoke test (uses a sandboxed HOME)
SBOX=$(mktemp -d) && mkdir -p "$SBOX/.claude" && echo '{}' > "$SBOX/.claude/settings.json"
HOME="$SBOX" PROJECT_REPOS_DIR="$SBOX/code" SKIP_CLAUDE_CHECK=1 bash install.sh
```

## Pull requests

- One logical change per PR. Keep commits focused.
- Update `CHANGELOG.md` under `[Unreleased]`.
- Make sure CI is green before requesting review.
- For new skills or agents, include an example in `docs/SKILLS.md` or `docs/AGENTS.md`.

## Commit style

Conventional commits are encouraged:
```
feat(skills): add /deploy skill for Helm releases
fix(hooks): handle missing git remote in statusline
docs(knowledge): add postgres index-size patterns
```
