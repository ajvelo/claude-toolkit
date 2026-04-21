# Skills reference

17 skills organised by workflow. Skills support auto-triggering, per-skill
tool restrictions, and isolated execution.

---

## Skill features

| Feature | What it does | Skills that use it |
|---------|--------------|--------------------|
| **Auto-trigger** | Claude invokes from natural language | `jira`, `sentry`, `investigate`, `explore-repo`, `posthog`, `onboard` |
| `disable-model-invocation: true` | Only runs when you type `/skill-name` | All others |
| `context: fork` | Runs in an isolated sub-agent, keeps main context clean | `explore-repo` |
| `allowed-tools` | Restricts which tools the skill can use | Most skills |

---

## Onboarding

### `/onboard` *(auto-trigger)*
Full guided onboarding. Assesses current state, installs toolkit, clones
projects (respects custom paths), configures MCP servers, runs
stack-specific setup, and verifies everything works.

```
/onboard                          # Guided setup (asks what to clone)
/onboard core                     # Clone 5 core projects from the registry
/onboard all                      # Clone everything in repos.conf
/onboard api,web                  # Clone specific projects
```

Auto-triggers on: "onboard me", "set me up", "get started".

---

## Workflow

### `/start`
Ticket-to-PR workflow. Fetches ticket, creates a branch, spawns parallel
exploration agents, plans implementation, writes code + tests, validates,
self-reviews, and offers to create a draft PR. Auto-detects stack (Flutter,
Kotlin, Python, Node, Go, …). Also handles **multi-repo tickets** — plans
deploy order (backend-first), implements sequentially with checkpoints, and
verifies cross-repo contracts. **Bug / support tickets** auto-investigate
first (error tracker, codebase search, data layer) to determine root cause
and target repo(s) before planning.

```
/start WEB-1246 web
/start API-456 api
/start MOB-123 mobile
/start INF-99 api,infra                   # multi-repo
/start BUG-663                            # auto-investigates first
```

### `/pr`
Commit + draft PR + CI status. Reviews diff against the base branch to
catch unrelated changes, confirms staging, pushes, creates a draft PR with
a formatted title. Also supports reading review comments, implementing
fixes, and watching CI.

```
/pr web create
/pr api review
/pr api fix
/pr ci --watch
```

### `/verify`
Parallel implementation verification. Spawns up to 3 agents:
`test-analyzer`, `ticket-matcher`, `visual-health`. Flags: `--quick`,
`--fix`, `--visual-only`.

```
/verify web /dashboard
/verify api --quick
/verify --visual-only
```

### `/review-pr`
Team-based PR review. Spawns UX, Code, and QA reviewer agents in parallel.
Auto-detects UI changes for a Playwright visual walkthrough. Posts the
review directly to the PR.

```
/review-pr <owner>/<repo>#42
/review-pr https://github.com/<owner>/<repo>/pull/1847
```

---

## Investigation

### `/investigate` *(auto-trigger)*
Cross-project bug investigation. Checks ticket system, error tracker,
codebase, optionally data warehouse; produces a triage report + fix plan.

```
/investigate MOB-4521
/investigate BUG-6463
/investigate "payment fails after selecting option X"
```

### `/jira` *(auto-trigger)*
Ticket lookup. Maps prefixes to codebases.

```
/jira WEB-1246
/jira "my open issues"
```

### `/sentry` *(auto-trigger)*
Error tracker. Maps shortnames to projects.

```
/sentry api
/sentry "NullPointerException in ChargeService"
```

### `/explore-repo` *(auto-trigger, fork)*
Repository onboarding. Detects stack, structure, entry points, deps.

```
/explore-repo demo-api
/explore-repo <owner>/<repo>
```

### `/snowflake`
Query Snowflake for debugging and analytics. Uses `snowsql` with SSO.

```
/snowflake "top users by activity this week"
/snowflake "SELECT * FROM PROD.DOMAIN.USERS WHERE id = 12345 LIMIT 10"
```

### `/posthog`
Query PostHog for feature flags, experiments, events.

```
/posthog <flag-name>
/posthog "conversion funnel for checkout"
```

### `/sonarqube`
Code-quality metrics, issues, and quality gates.

```
/sonarqube api
/sonarqube web issues
```

---

## Build / Test / Analyze

### Kotlin
```
/kt build api
/kt build api some-module
/kt test api --tests "PaymentServiceTest"
/kt analyze api --auto-correct
/kt docker api postgres
```

### Flutter
```
/flutter build mobile
/flutter test mobile test/features/account/
/flutter analyze mobile
```

### Python server
```
/server test -k users
/server analyze
/server docker
```

### E2E
```
/e2e-test web --headed
```

---

## Release

### `/release`
Create release tags. Never pushes automatically.

```
/release api v1.15.0
/release api module-name v1.8.0
```

---

## Prerequisites

All skills require:
- GitHub CLI (`gh`) authenticated
- Relevant repos cloned locally (auto-discovered by `install.sh` — repos can live anywhere)

Some skills additionally need:
- **Jira / Sentry / Figma / PostHog / Notion**: MCP servers configured (`docs/MCP-SETUP.md`)
- **Kotlin skills**: correct JDK for the target project
- **Flutter skills**: FVM installed with correct Flutter SDK
- **Snowflake**: `snowsql` installed with a named connection configured
- **Visual review**: Playwright MCP server
