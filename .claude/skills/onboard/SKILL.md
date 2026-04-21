---
name: onboard
description: Full guided onboarding — installs toolkit, clones your projects, sets up MCP servers, verifies everything works
disable-model-invocation: false
user-invocable: true
argument-hint: "[repos-to-clone: all | core | <shortname,...>]"
---

## Full Onboarding

**Arguments:** $ARGUMENTS

Take the user from zero to a fully working Claude Code + toolkit setup for
the projects defined in `repos.conf`.

## Step 1 — assess current state (in parallel)

1. **Toolkit installed?** Check that `~/.claude/settings.json` has toolkit hooks configured
2. **Repos discovered?** Check whether `~/.claude/project-repos.json` exists; read it
3. **MCP servers?** Check `~/.claude/settings.json` → `mcpServers` for the servers listed in `docs/MCP-SETUP.md`
4. **Prerequisites?** `jq`, `gh` (authenticated), `claude`, plus any per-stack tools (FVM, JDK, Docker, `uv`, pnpm, Go, Terraform)
5. **Git config?** GPG signing if your workflow requires it: `git config --global user.signingkey`
6. **GitHub auth:** `gh auth status`

Present a checklist showing what's done and what's missing.

## Step 2 — install the toolkit (if needed)

If the toolkit isn't installed or needs a refresh:
```bash
cd ~/claude-toolkit && bash install.sh
```

This handles: hooks, settings merge, repo discovery, project instruction symlinks.

If the toolkit directory doesn't exist:
```bash
gh repo clone <owner>/claude-toolkit ~/claude-toolkit
```

## Step 3 — clone repos

Parse the argument:
- `all` — clone every entry in `repos.conf` that has a project-instruction file
- `core` (default) — clone the five example projects: `mobile`, `web`, `api`, `server`, `infra`
- `<shortname,...>` — clone specific projects by shortname (comma-separated)

Read `~/.claude/project-repos.json` to see which repos are already cloned.

For each repo that needs cloning:

- Ask **once** where the user keeps repos (or respect `PROJECT_REPOS_DIR`):
  default is `$HOME`, but `~/code`, `~/projects`, `~/work` are common
- Use `AskUserQuestion` to confirm the full clone plan before proceeding

Clone (these can run in parallel):
```bash
gh repo clone <owner>/<repo> <target-path>
```

(`<owner>` comes from `$GITHUB_OWNER` env var, or is asked once.)

After cloning, re-run discovery:
```bash
bash ~/claude-toolkit/scripts/discover-repos.sh
```

Then re-run install to symlink newly discovered project instructions:
```bash
bash ~/claude-toolkit/install.sh
```

## Step 4 — set up MCP servers

Check which servers are configured in `~/.claude/settings.json` under
`mcpServers`. For each missing server referenced by skills (Sentry, Jira,
PostHog, Notion, context7, Figma, Chrome DevTools), present the setup
command and note that SSE servers need browser authentication.

Tell the user: "Each SSE server will open a browser for authentication. Run
the commands one at a time — use the `!` prefix in the Claude Code prompt
so I can see the output."

See `docs/MCP-SETUP.md` for exact commands and any env vars required.

## Step 5 — stack-specific setup

Based on which projects were cloned, verify and assist with stack tooling:

### Flutter (`mobile`)
- FVM: `fvm --version`; if missing → `dart pub global activate fvm`
- `cd {path} && fvm install && fvm flutter pub get`

### TypeScript / Next.js (`web`)
- pnpm: `pnpm --version`; if missing → `npm install -g pnpm`
- `cd {path} && pnpm install`

### Kotlin (`api`)
- JDK: `java -version`; ensure JDK matches the project (see `projects/api.md`)
- `cd {path} && ./gradlew build`

### Python (`server`)
- uv: `uv --version`; if missing → `curl -LsSf https://astral.sh/uv/install.sh | sh`
- `cd {path} && uv sync`

### Terraform / Helm (`infra`)
- `terraform version`; if missing → install via your OS package manager
- `helm version`; if missing → install similarly
- `cd {path} && terraform -chdir=envs/dev init`

## Step 6 — verify everything works

Run checks per cloned repo in parallel:

1. **Toolkit:** `cat ~/.claude/project-repos.json | jq '.repos | to_entries[] | select(.value.path != null) | .key'`
2. **Git:** `git config --global user.name && git config --global user.email`
3. **GPG** (if used): `echo test | gpg --clearsign > /dev/null`
4. **GitHub:** `gh auth status`
5. **Per-repo lightweight check** using the stack's version command

## Step 7 — present a final report

```
## Onboarding Complete!

### Toolkit
- [x] claude-toolkit installed
- [x] 7 hooks configured
- [x] 17 skills available
- [x] 12 agents available

### Repos Cloned (n / total)
- [x] mobile (/path/to/demo-mobile)
- [x] web (/path/to/demo-web)
- [ ] infra (not cloned)
...

### MCP Servers (n / total)
- [x] Sentry
- [x] Jira / Confluence
- [ ] Figma (not configured)
...

### Quick Reference
- Start a ticket: `/start MOB-123 mobile`
- Explore a repo: `/explore-repo demo-api`
- Check Sentry: `/sentry web`
- Look up a ticket: `MOB-123`
- Create PR: `/pr`
- Run tests: `/flutter test mobile`, `/kt test api`, `/server test`
```

## Rules

- Check current state before suggesting actions — don't redo what's done
- Use `AskUserQuestion` before cloning (confirm which ones and where)
- MCP server setup opens browsers — suggest `!` prefix for those commands
- Don't install system-level tools without asking (JDK, Docker, Terraform)
- If a step fails, diagnose and suggest a fix rather than skipping
- Track progress with checkmarks so the user can see what's left
