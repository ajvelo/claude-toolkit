# Customising the toolkit

The toolkit ships opinionated defaults. This guide covers how to adapt it
to your own projects without forking if you don't want to.

## Layering personal overrides

Everything in the toolkit loads *before* your user-level config in
`~/.claude/`. If you want behaviour that differs from the toolkit default,
override it in `~/.claude/` rather than editing toolkit files.

### Per-repo path overrides

If the installer doesn't find a repo where you put it, add an entry to
`~/.claude/project-repos.local.env`:

```
PROJECT_REPO_API=/custom/path/to/api
PROJECT_REPO_WEB=/home/me/code/my-frontend
```

The installer sources this file *after* auto-discovery, so any entries
here take precedence. Re-run `./install.sh` to refresh.

### Override a skill locally

User-level skills in `~/.claude/skills/` take precedence over toolkit
skills. If you want a different `/pr` than the toolkit's, drop a
`~/.claude/skills/pr/SKILL.md` and it wins.

### Override an agent locally

Same pattern: `~/.claude/agents/{name}.md` overrides
`~/claude-toolkit/.claude/agents/{name}.md`.

### Additional hooks

Add per-user hooks to `~/.claude/hooks/` and register them in
`~/.claude/settings.json` under `hooks`. They run alongside the toolkit
hooks.

---

## Forking: adapting to your stack

Most teams want to fork and rename. Here's the recommended order:

### 1. Replace the registry

Edit `repos.conf`:

```
# Format: shortname|github-repo|project-file|icon|tech|base-branch|jira-prefix|build-tool
web|my-web|web.md||TypeScript/Next.js|main|WEB-|pnpm
api|my-api|api.md||Kotlin/Ktor|main|API-|./gradlew
...
```

### 2. Rewrite per-project instruction files

For each entry, edit `projects/{shortname}.md`. Describe:
- Stack (framework, language, package manager, testing stack)
- Commands (build, test, analyze, format, validate)
- Conventions (directory layout, naming, idioms)
- Gotchas (workarounds, surprising defaults)

These files are auto-loaded when Claude works inside that project.

### 3. Update the CLAUDE.md project registry table

The table in `CLAUDE.md` must match `repos.conf` — Claude reads it
constantly. Keep them in sync.

### 4. Update ticket routing

Edit `.claude/skills/start/ticket-routing.md` with your actual Jira prefixes.

### 5. Update the dependency map (if you use `/investigate`)

`knowledge/service-dependency.md` (not included by default — add it if the
investigate skill's built-in template doesn't match your architecture) is
where you describe your service topology.

### 6. Remove or rename example skills

Skills that don't apply to your stack (e.g. `/server` if you don't have
Python, `/flutter` if you don't ship mobile) can be deleted entirely:

```bash
rm -rf .claude/skills/flutter
rm -rf .claude/skills/server
```

---

## Adding a new skill

1. Create a directory in `.claude/skills/` (e.g. `.claude/skills/deploy/`)
2. Add a `SKILL.md` with frontmatter:

```yaml
---
name: deploy
description: One-line description shown in /help
argument-hint: "<project> [--env <env>]"
disable-model-invocation: false
user-invocable: true
---

## Deploy
...body...
```

3. The skill becomes `/deploy`
4. Drop helper files (templates, tables) in the same directory — Claude
   reads them via `Read` on demand

## Adding a new agent

1. Create `.claude/agents/{name}.md`
2. Frontmatter declares trigger conditions, model, and colour:

```yaml
---
name: my-agent
description: One-line description of when this agent is useful
model: opus
color: cyan
memory: user
---
```

3. Body describes the agent's focus, capabilities, and example scenarios.
4. Use the `Agent` tool with `subagent_type: my-agent` to dispatch to it.

## Adding a new hook

1. Add a shell script to `hooks/`
2. Register it in `templates/settings.json` under `hooks`
3. Re-run `./install.sh` to symlink
