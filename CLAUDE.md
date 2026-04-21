# Claude Code Toolkit

An opinionated Claude Code workspace for orchestrating a multi-language project
setup. This file is the toolkit-level instruction layer; it is loaded whenever
Claude Code is started from this directory.

Working directory: `~` (home). All project references below use absolute paths
resolved from the project registry — do **not** assume `$HOME/{repo-name}`.

---

## Autonomy Rules

- **NEVER** auto-commit, auto-push, or auto-merge without explicit confirmation
- **NEVER** force-push to protected branches (`main`, `master`, `develop`, `dev`, `release/*`)
- **NEVER** edit `.env*`, `.keystore`, `.jks`, `.pem`, `.key`, `.p12`, `credentials.json`, `secrets.yaml`
- **ALWAYS** create **draft** PRs (never ready PRs) unless explicitly asked
- **ALWAYS** confirm before `git add`, `git commit`, `git push`
- **ALWAYS** confirm before `gh pr create`, `gh pr merge`
- **ALWAYS** use absolute paths resolved from the project registry (below)
- **ALWAYS** interview the user before starting complex tasks — clarify scope,
  edge cases, and preferences before writing code. Simple fixes and one-liner
  changes can skip this.

---

## Implementation Standards

- **ALWAYS** write unit tests for any new public method, extension, or
  behavioural change — do not wait for the user to ask. Tests ship in the same
  commit as the implementation.
- Mirror source paths in the test tree (e.g. `src/foo.ts` → `tests/foo.test.ts`).
- When modifying existing code that lacks tests, add tests for the changed
  behaviour.
- **ALWAYS** run the project's local validation command before confirming a
  commit — the specific command is encoded per-project in `projects/*.md`.
  Fix **all** analyzer warnings, not just errors — CI treats them as failures.
- **No unnecessary comments.** Don't add docstrings, inline comments, or
  section markers unless the logic is non-obvious (protocol quirks, workarounds,
  hidden invariants). Method and test names should self-document.
- **PR descriptions must be concise** — max 3-5 bullet summary, link to the
  ticket, short test plan. No file-change tables, no implementation prose.

---

## Project Registry

Repo paths are auto-discovered by `install.sh` and stored in two files:
- `~/.claude/project-repos.env` — shell variables sourced by hooks
- `~/.claude/project-repos.json` — JSON consumed by Claude for path resolution

**Always read `~/.claude/project-repos.json` to resolve shortnames to paths.**
Never assume repos are at `$HOME/{repo-name}` — the user can clone repos anywhere.

| Shortname | Repo                | Tech                                | Base   | Jira   | Build                 |
|-----------|---------------------|-------------------------------------|--------|--------|-----------------------|
| mobile    | demo-mobile         | Flutter (FVM)                       | main   | `MOB-` | `fvm flutter`         |
| web       | demo-web            | TypeScript / Next.js (pnpm)         | main   | `WEB-` | `pnpm`                |
| api       | demo-api            | Kotlin / Ktor (Gradle)              | main   | `API-` | `./gradlew`           |
| server    | demo-server         | Python 3.12 / FastAPI (uv)          | main   | `SRV-` | `uv` / `pytest`       |
| infra     | demo-infra          | Terraform + Helm                    | main   | `INF-` | `terraform` / `helm`  |

This is the **example registry** that ships with the toolkit. Replace entries
in `repos.conf` with your own projects and re-run `./install.sh`.

---

## Request Flow (example)

```
     FRONTEND            API GATEWAY                SERVICES
  ┌──────────┐         ┌─────────────┐         ┌──────────────┐
  │  mobile  │──┐      │             │         │    server    │
  │  (app)   │  ├────▶ │     api     │ ──────▶ │  (python)    │
  └──────────┘  │      │  (kotlin)   │         │              │
  ┌──────────┐  │      │             │         └──────────────┘
  │   web    │──┘      └─────────────┘
  │ (next)   │
  └──────────┘                                 ┌──────────────┐
                                               │    infra     │
                                               │ (terraform)  │
                                               └──────────────┘
```

This is the **illustrative** topology used by example skills. Replace with
your actual architecture by updating `knowledge/service-dependency.md`.

---

## Cross-Project Tracing

When debugging a bug that spans projects:

1. **Identify the symptom layer** — where does the error surface?
2. **Check the originating project's error-tracking** (Sentry via `/sentry`)
3. **Check the ticket system** (Jira via `/jira`)
4. **Trace the request path** using the dependency map
5. **Search each layer's codebase** with Grep/Glob against the resolved paths
6. **Check API contracts** — DTOs/schemas at every boundary
7. **Verify data flow** — follow the data transformation at each hop

---

## Conventions

### Branch naming
```
{type}/{TICKET-KEY}-{slug}
```
Types: `feat/`, `fix/`, `chore/`, `refactor/`, `docs/`, `test/`

### Commit format
```
type: description (TICKET-KEY)
```

### PR title format
```
type: description (TICKET-KEY)
```
`feat` and `fix` PRs should include the ticket key; other types optional.

---

## Skill Auto-Routing

When a natural-language request clearly matches a skill, proactively invoke it
via the Skill tool — don't wait for explicit `/command` syntax.

| User says...                                  | Route to        | Guardrail                     |
|-----------------------------------------------|-----------------|-------------------------------|
| Mentions a ticket key (`MOB-123`, `API-45`)   | `/jira`         | Read-only                     |
| "check sentry", "what's failing in prod"      | `/sentry`       | Read-only                     |
| Describes a bug, mentions tracing             | `/investigate`  | Read-only                     |
| "what's in X", "explore X", "onboard X"       | `/explore-repo` | Read-only                     |
| "start working on {TICKET}"                   | `/start`        | Confirm before branch + code  |
| "create PR", "push", "commit"                 | `/pr`           | Confirm every git mutation    |
| "check CI"                                    | `/pr ci`        | Read-only                     |
| "run tests" / "analyze" + project             | `/flutter`, `/kt`, `/server`, etc. | Local commands  |
| "verify", "visual review"                     | `/verify`       | Read-only + local commands    |
| "review PR"                                   | `/review-pr`    | Read-only                     |
| "release", "tag a release"                    | `/release`      | Confirm before tag + push     |
| "query snowflake", "check the data"           | `/snowflake`    | Read-only                     |
| "sonarqube", "code quality", "quality gate"   | `/sonarqube`    | Read-only                     |
| "onboard me", "set me up"                     | `/onboard`      | Confirm before clone + install|

### Guardrail rules

All skills inherit the global autonomy rules above. Additionally:

- **Branch-creating skills** (`start`): confirm project + branch name before `git checkout -b`
- **Git-mutating skills** (`pr`, `release`): confirm before every `git add`, `commit`, `push`, and `gh pr create`
- **Code-writing skills** (`start`): present the plan and wait for confirmation before writing code
- Read-only and local-command skills may run without confirmation.

---

## Library documentation

Prefer `mcp__context7__resolve-library-id` then `mcp__context7__query-docs`
for library and API documentation — do not rely on training data for version-
sensitive APIs. Use context7 automatically when a task involves a library,
framework, SDK, or CLI tool.

---

## Integrations (optional)

| MCP server       | What it does                                                 |
|------------------|--------------------------------------------------------------|
| Sentry           | Error triage, issue search, release tracking                 |
| Atlassian        | Jira ticket lookup, Confluence search                        |
| PostHog          | Feature flags, experiments, analytics queries                |
| Notion           | Docs, specs, meeting notes                                   |
| context7         | Library documentation                                        |
| Figma            | Design-to-code: screenshots, variables, component specs      |
| Chrome DevTools  | Lightweight browser inspection (console, network, DOM)       |

See `docs/MCP-SETUP.md`. All remote MCP servers are opt-in; nothing sends
traffic off-machine by default.

---

## Repo Path Resolution

When a command or operation targets a specific project:

1. Read `~/.claude/project-repos.json` to get the project's actual path
2. Use that path when running project-specific commands or searches

Engineers clone repos wherever they prefer:

```bash
gh repo clone my-org/demo-api ~/code/demo-api
gh repo clone my-org/demo-web ~/projects/demo-web
./install.sh        # re-discovers the new paths
```

Discovery can be customised via:
- `PROJECT_REPOS_DIR` env var — primary search directory
- `~/.claude/project-repos.local.env` — per-repo path overrides
- `./install.sh --search-dir /custom/path` — additional search paths
- `./install.sh --deep-scan` — find repos by git remote (useful after renames)

---

## Working with an unlisted repository

The project registry covers the projects you've told the toolkit about. For
any other repo:

### Remote (no clone needed)
- `gh repo view` / `gh api repos/{owner}/{name}/contents/{path}` — inspect any repo
- `gh search code --owner {org} {query}` — search across an organisation
- `gh api` endpoints for branches, commits, PRs

### Local (auto-clone)
When local work is needed:
1. Clone into `$HOME` or `$PROJECT_REPOS_DIR`
2. Add an entry in `repos.conf`, re-run `./install.sh`
3. Auto-detect stack by checking for build files:
   - `pubspec.yaml` → Flutter/Dart
   - `package.json` → Node/TypeScript
   - `pyproject.toml` / `requirements.txt` → Python
   - `go.mod` → Go
   - `build.gradle{.kts}` / `pom.xml` → JVM
   - `composer.json` → PHP
   - `Cargo.toml` → Rust

---

## Auto-Learning

This toolkit gets smarter with every session. Save learnings **immediately**
when discovered — don't defer.

**When to save:**
- Immediately when discovering a gotcha, silent failure, or unexpected behaviour
- Immediately when a mistake is made and corrected
- On task completion (after PR created, bug fixed, investigation done) — capture
  patterns, conventions, and API contracts discovered during the work

**What to capture:**
- Gotchas, silent failures, unexpected behaviours
- Naming conventions, API contracts, or serialization rules discovered by reading code
- Patterns that worked (or didn't) across project boundaries
- Infrastructure/tooling quirks (env vars, Docker, build tools)

**Where to save:**
- **`knowledge/*.md`** — long-lived cross-project patterns (architecture
  gotchas, language idioms, integration quirks). Keep factual and actionable.
- **Per-project instructions** (`projects/{shortname}.md`) — project-specific
  conventions. Auto-loaded when Claude works in that repo.
- **Per-user memory** (`~/.claude/projects/.../memory/`) — personal
  preferences, per-session context. Not checked in.

**When NOT to save:**
- Session-specific context (current task details, temp state)
- Anything already documented in this file or in `knowledge/`
- Speculative conclusions from a single observation

---

## GPG signing (optional)

If your commits require GPG signing and signing is failing:

```bash
gpgconf --kill gpg-agent && gpg-agent --daemon
export GPG_TTY=$(tty)
```

To disable signing per-repo: `git config commit.gpgsign false`.
