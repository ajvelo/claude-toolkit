# claude-toolkit

[![CI](https://github.com/ajvelo/claude-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/ajvelo/claude-toolkit/actions/workflows/ci.yml)
![License](https://img.shields.io/badge/license-MIT-green)
![Shell](https://img.shields.io/badge/shell-bash-blue)
![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-purple)

An opinionated Claude Code workspace for orchestrating a multi-language
project setup. Clone it once, start Claude Code from the toolkit directory,
and every session gets the same skills, sub-agents, safety hooks, and
knowledge base, regardless of which repository you're working on.

![installer demo](assets/demo.gif)

📝 **Writeup:** [Single-shot LLM code suggestions are confidently wrong. Here's what I did about it.](https://medium.com/@Andreasv/single-shot-llm-code-suggestions-are-confidently-wrong-heres-what-i-did-about-it-a76bcef79215)

> **Positioning**: this is a *template toolkit* for multi-project teams. The
> example registry covers five representative stacks (Flutter, TypeScript,
> Kotlin, Python, Terraform). Fork it, replace the registry with your own
> projects, and the skills immediately operate on your stack.

---

## What's in the box

- **17 skills** — slash commands for ticket-to-PR workflows, investigation, build/test/analyze, onboarding, and releases. Skills support auto-triggering from natural language and per-skill tool restrictions.
- **12 specialist sub-agents** — debuggers and reviewers (Kotlin, Flutter, TypeScript portal, Python backend, API gateway, database, Kafka, E2E) plus UX/QA/code review agents.
- **7 safety hooks** — bash safety (pre-tool-use), write guard (secrets/migrations), auto-format (post-edit), bash-triage (post-run), desktop notification, status line, pre-compact.
- **Generic installer** — auto-discovers your repo paths on disk (`$HOME`, `$HOME/code`, `$HOME/projects`, custom), writes a resolved path file, and symlinks per-project instructions.
- **Curated knowledge base** — language idioms, architecture gotchas, integration patterns. Shipped sparsely on purpose: the real value is appending to it over time (the toolkit prompts Claude to do this automatically).
- **MCP templates** — opt-in wiring for Sentry, Jira/Confluence, PostHog, Notion, Figma, context7, Chrome DevTools.

---

## Why a toolkit and not a dotfile?

Most Claude Code customisation lives as `~/.claude/settings.json` plus a
handful of slash commands. That scales to one project. Once you're jumping
between a Flutter app, a Kotlin API, a Python service, and Terraform in the
same day, a monolithic config turns into noise — and Claude's guardrails
start contradicting each other across stacks.

This toolkit factors the customisation:

- **Skills** know about the workflow (ticket → branch → code → PR), not the stack
- **Per-project instruction files** carry stack-specific build/test/lint commands
- **A project registry** maps shortnames to on-disk paths, so skills work regardless of where you clone things
- **Hooks** enforce org-level rules (no force-push to `main`, no `.env` in commits) uniformly
- **Knowledge files** accumulate discoveries so every new session starts informed

The result is a single `claude` invocation from the toolkit directory that
works the same whether you're building a feature, investigating a bug, or
reviewing a PR — in any of your projects.

---

## Quick install

```bash
# Clone the toolkit
git clone https://github.com/ajvelo/claude-toolkit.git ~/claude-toolkit

# Run the installer (one-time)
cd ~/claude-toolkit && ./install.sh

# Start Claude Code from the toolkit directory
cd ~/claude-toolkit && claude
```

The installer will:

1. Symlink all safety hooks to `~/.claude/hooks/`
2. Merge hook configuration into `~/.claude/settings.json`
3. Configure the status line
4. Auto-discover repo paths on disk (`$HOME`, `$HOME/code`, `$HOME/projects`, custom search paths)
5. Write resolved paths to `~/.claude/project-repos.env` + `.json`
6. Symlink per-project instruction files for the discovered repos

Repos can live anywhere — the installer finds them. To customise search:

```bash
# Primary search directory
export PROJECT_REPOS_DIR=~/code && ./install.sh

# Extra search paths
./install.sh --search-dir ~/work

# Find repos even if renamed on disk (scans git remotes, slower)
./install.sh --deep-scan

# Per-repo manual overrides in ~/.claude/project-repos.local.env:
# PROJECT_REPO_API=/custom/path/to/api
```

### Make it yours

1. Edit `repos.conf` — replace the five demo entries with your actual projects
2. Edit `projects/{shortname}.md` for each project — describe its stack, build command, test command, conventions
3. Re-run `./install.sh` to refresh the registry
4. (Optional) Add stack-specific skills or knowledge files — see `docs/CUSTOMIZATION.md`

---

## First five minutes

Once installed, try these in any Claude Code session started from the toolkit:

```
/jira API-1234                # Look up a ticket
/sentry web                   # Check Sentry errors for a project
/start API-1234 api           # Full ticket-to-PR workflow
/start INF-99 api,infra       # Multi-repo ticket (auto-orders the work)
/investigate API-1234         # Trace a bug across the dependency chain
/explore-repo demo-server     # Discover any repo you haven't touched yet
/snowflake "last week's sign-ups"   # Query analytics data (if Snowflake MCP configured)
/onboard                      # Guided setup — clones repos, sets up MCP servers
```

Skills like `/jira`, `/sentry`, `/investigate`, and `/explore-repo` also
**auto-trigger from natural language** — just mention a ticket or describe a bug.

---

## Skill catalogue

### Workflow

| Skill         | Example                         | What it does                                                 |
|---------------|---------------------------------|--------------------------------------------------------------|
| `/start`      | `/start API-1234 api`           | Ticket-to-PR workflow — Jira → branch → explore → plan → implement → validate → PR. Handles multi-repo tickets. |
| `/pr`         | `/pr api create`                | Commit, create draft PR, review comments, fix, check CI.     |
| `/verify`     | `/verify web /dashboard`        | Parallel verification — tests, ticket match, visual.          |
| `/review-pr`  | `/review-pr #42`                | Team-based PR review (UX, code, QA agents in parallel).      |

### Onboarding

| Skill         | Example                         | What it does                                                 |
|---------------|---------------------------------|--------------------------------------------------------------|
| `/onboard`    | `/onboard`                      | Guided onboarding — clones repos, configures MCP, verifies.  |

### Investigation (auto-trigger)

| Skill            | Example                          | What it does                                                |
|------------------|----------------------------------|-------------------------------------------------------------|
| `/investigate`   | `/investigate MOB-42`            | Cross-project bug tracing + support-ticket triage           |
| `/jira`          | `/jira WEB-89`                   | Ticket lookup, maps prefix → project                        |
| `/sentry`        | `/sentry web`                    | Sentry error summary for a project                          |
| `/explore-repo`  | `/explore-repo demo-api`         | Discover and onboard a repo you haven't worked on yet       |
| `/snowflake`     | `/snowflake "active users last 7d"` | Run a parameterised analytics query                      |
| `/posthog`       | `/posthog web_checkout_v2`       | Feature flags, experiments, analytics                       |
| `/sonarqube`     | `/sonarqube api`                 | Code-quality metrics and quality gates                      |

### Build / Test / Analyze

| Skill         | Example                         | What it does                                                 |
|---------------|---------------------------------|--------------------------------------------------------------|
| `/kt`         | `/kt build api`                 | Kotlin build, test, analyze, or docker                       |
| `/flutter`    | `/flutter test mobile`          | Flutter build, test, or analyze                              |
| `/server`     | `/server test --filter=users`   | Python server test, analyze, or docker                       |
| `/e2e-test`   | `/e2e-test web --headed`        | Playwright E2E tests                                         |

### Release

| Skill         | Example                         | What it does                                                 |
|---------------|---------------------------------|--------------------------------------------------------------|
| `/release`    | `/release api`                  | Create a release tag with changelog preview                  |

See `docs/SKILLS.md` for detailed per-skill docs (frontmatter, tools, behaviour).

---

## Sub-agents

Sub-agents activate based on the type of problem in play. Each has a
scoped tool set and a system prompt tuned for its domain.

| Agent                      | Activates on                        | Focus                                                        |
|----------------------------|-------------------------------------|--------------------------------------------------------------|
| `kotlin-debugger`          | Stack traces, DI errors, ORM issues | Bean resolution, ORM queries, precision arithmetic           |
| `kotlin-test-writer`       | "Write tests for..."                | Kotest, MockK, TestContainers, property-based testing        |
| `api-debugger`             | HTTP errors, auth issues            | Auth session debugging, stub servers, DTO mapping            |
| `portal-debugger`          | TypeScript/Next.js UI bugs          | State, routing, DI, session/proxy issues                     |
| `flutter-mobile-debugger`  | App crashes, navigation issues      | Routing, state, platform channels, connectivity              |
| `e2e-debugger`             | Playwright test failures            | Selectors, timeouts, auth flows, cross-browser, flakiness    |
| `database-specialist`      | DB or analytics issues              | Schema, migrations, query optimization, consistency          |
| `kafka-debugger`           | Event-processing issues             | Consumer lag, deserialization, topic routing, dead letters   |
| `php-debugger`             | PHP service issues                  | Framework conventions, routing, queues, service container    |
| `code-reviewer`            | PR code-quality review              | Architecture fit, convention checks, dead-code detection     |
| `qa-reviewer`              | PR test-coverage review             | Edge cases, regression risk, test-plan completeness          |
| `ux-reviewer`              | PR UX review                        | Consistency, user flow, accessibility                        |

---

## Safety hooks

**bash-safety** (PreToolUse — Bash) blocks:
- Force-push to protected branches (`main`, `master`, `develop`, `dev`, `release/*`)
- `git reset --hard` on protected branches
- `git add .` when `.env` files are present
- `--no-verify` commits
- Direct production deployment (`kubectl`/`helm`/`docker` targeting prod)

**write-guard** (PreToolUse — Write/Edit) blocks:
- `.env*`, `.keystore`, `.jks`, `.pem`, `.key`, `.p12`, `credentials.json`, `secrets.yaml`
- Already-committed SQL migration files

**auto-format** (PostToolUse — Write/Edit):
- Dart (`dart format`), Kotlin (`ktlint`), Go (`gofmt`), TypeScript (`prettier`), Python (`ruff format`)

**bash-triage** (PostToolUse — Bash):
- Explains common failures (JDK mismatches, Gradle daemon issues, port conflicts, missing node_modules, Docker daemon, GPG signing)

**notification** (Notification): Desktop alerts when Claude finishes a task.

**statusline** (StatusLine): Project shortname, branch, and ticket in the status bar.

**pre-compact** (PreCompact): Injects a reminder to commit discoveries to `knowledge/` before the model compacts context.

---

## Project structure

```
claude-toolkit/
├── CLAUDE.md                 # Toolkit-level instructions (loaded by Claude)
├── README.md                 # This file
├── LICENSE                   # MIT
├── install.sh                # Installer
├── repos.conf                # Project registry (pipe-delimited)
├── .claude/
│   ├── skills/               # 17 slash-command skills
│   └── agents/               # 12 specialist sub-agents
├── hooks/                    # 7 safety hooks (bash)
├── knowledge/                # Cross-project patterns and gotchas
├── projects/                 # Per-project instruction files
├── templates/                # Settings templates
├── scripts/                  # discover-repos.sh and other helpers
├── mcp/                      # MCP server config templates
└── docs/                     # Skill, agent, hook, MCP, customisation docs
```

---

## Documentation

- `docs/SKILLS.md` — detailed skill reference
- `docs/AGENTS.md` — agent activation triggers and capabilities
- `docs/HOOKS.md` — hook lifecycle and implementation details
- `docs/MCP-SETUP.md` — MCP server configuration
- `docs/CROSS-PROJECT.md` — multi-project workflow patterns
- `docs/CUSTOMIZATION.md` — adding skills, agents, hooks, knowledge
- `docs/TROUBLESHOOTING.md` — common issues and fixes

---

## Contributing / forking

This is a personal toolkit I share as a template. If you want to fork and
adapt it:

1. Replace `repos.conf` with your own projects
2. Rewrite `projects/*.md` files with your stacks' conventions
3. Edit or delete example skills that don't map to your stack
4. Drop your own knowledge files into `knowledge/` — `CLAUDE.md` points Claude there automatically

See `docs/CUSTOMIZATION.md` for the full guide.
