# Cross-project workflow

The toolkit is designed for working across multiple repositories from a
single Claude Code session. This document explains how path resolution
works and how to leverage cross-project capabilities.

---

## Auto-discovery

Repos can live anywhere on disk. The installer (`install.sh`) searches
common directories (`$HOME`, `$HOME/code`, `$HOME/projects`, …) and writes
resolved paths to:

- `~/.claude/project-repos.env` — shell variables sourced by hooks
- `~/.claude/project-repos.json` — JSON read by Claude for path resolution

```
# Example: repos in various locations all work
~/code/my-org/mobile/
~/projects/my-web/
~/work/my-api/
~/demo-server/
```

Every skill, agent, and hook resolves project paths dynamically from these
files. When you say "api", the toolkit looks up `api` in
`project-repos.json`.

To customise discovery:
- `PROJECT_REPOS_DIR` env var — primary search directory
- `~/.claude/project-repos.local.env` — per-repo overrides (e.g. `PROJECT_REPO_API=/custom/path`)
- `./install.sh --search-dir /custom/path` — additional search paths
- `./install.sh --deep-scan` — find repos by git remote (useful after renames)

---

## The project registry

`repos.conf` is the central source of truth for project metadata —
shortnames, GitHub repo names, tech stacks, base branches, Jira prefixes,
build tools. During install, `repos.conf` is combined with auto-discovery
to produce `~/.claude/project-repos.json` with resolved paths.

Skills use the registry to:
- Resolve shortnames → absolute paths
- Determine the build tool
- Know the correct base branch for PRs
- Select the right Jira prefix for tickets

---

## How commands resolve projects

When you run `/kt build api`, the resolution chain is:

1. Skill receives `build api` as arguments
2. Looks up `api` in `~/.claude/project-repos.json`
3. Resolves to the discovered path (e.g. `/Users/you/code/demo-api`)
4. Uses `./gradlew` as the build tool
5. Sets `JAVA_HOME` to the JDK declared in `projects/api.md`
6. Runs the build from that absolute path

This works from any directory — you don't need to `cd` into the project first.

---

## Working across repos without `cd`

Every skill accepts a project shortname and operates on the correct repo
regardless of your current directory:

- `/kt build api` — builds the api service
- `/kt test api` — runs api tests
- `/jira API-1234` — fetches a ticket and can search the api codebase
- `/sentry web` — queries Sentry for web errors

Claude can also read and search multiple repos in the same conversation:

```
"Compare the DTO in api/handlers with the model in the web app"
```

Claude reads files from both repos in parallel, using paths resolved from
`~/.claude/project-repos.json`.

---

## Accessing repos not in the registry

### Remote exploration (no clone needed)

Use `/explore-repo` to discover and understand any repository:

```
/explore-repo <repo>
/explore-repo <owner>/<repo>
```

This reads the repo remotely via `gh` — checks build files, entry points,
configuration, and produces a structured summary of the tech stack and
architecture.

For quick lookups, Claude can use `gh api repos/{owner}/{repo}/contents/{path}`
to read individual files.

### Local work (clone first)

When you need to build, test, or make changes locally:

```bash
gh repo clone <owner>/<repo>
```

Then re-run `install.sh` to discover the new repo:

```bash
cd ~/claude-toolkit && ./install.sh
```

Claude auto-detects the tech stack by checking for build files
(`build.gradle.kts`, `pubspec.yaml`, `package.json`, `go.mod`, `composer.json`,
`pyproject.toml`, `Cargo.toml`, …) and applies matching conventions.

---

## Cross-service tracing

The toolkit includes purpose-built skills for tracing issues across
service boundaries.

### `/investigate`

Given a ticket, error ID, or plain description, `/investigate` automatically:

1. Identifies which layer the issue originates from
2. Looks up the error in the error tracker (if applicable)
3. Searches related tickets
4. Traces the request path through the service dependency chain
5. Searches each relevant codebase for the affected code

### `/start` (multi-repo mode)

For tickets spanning multiple repos, `/start TICKET-123 server,api,web`
plans the implementation order (backend-first), creates branches in each
repo, implements sequentially with checkpoints, and verifies cross-repo
contracts. It auto-detects multi-repo scope from the ticket content if
repos aren't specified.

### Manual cross-service debugging

For ad-hoc investigation:

1. Identify where the error surfaces
2. Check the error tracker with `/sentry`
3. Check the ticket system with `/jira`
4. Trace the request path using the dependency map
5. Search each layer's codebase using Grep/Glob with absolute paths
6. Check API contracts — DTOs and schemas at every boundary
7. Verify data flow at each service boundary

---

## Example workflows

### Check an API contract across layers

> "I'm in web but need to verify the API contract for team search."

Claude reads the TypeScript model in the web repo, the DTO in the api
repo's handler, and the server-side response in the server repo —
comparing field names, types, and serialisation annotations across all
three. Paths are resolved from `~/.claude/project-repos.json`.

### Trace a failing transaction

> "Transactions fail with INSUFFICIENT_FUNDS but the account shows a positive balance."

Using `/investigate`, Claude searches the error tracker for the issue,
finds the endpoint that returns it, traces into the service's balance
check logic, then into the authorisation flow — identifying where the
discrepancy occurs.

### Discover an unfamiliar service

> "What does demo-worker do?"

Using `/explore-repo demo-worker`, Claude reads the repo remotely,
identifies the stack, finds the main entry points and API endpoints,
checks the README and configuration, and produces a structured summary.
