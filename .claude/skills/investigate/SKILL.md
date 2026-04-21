---
name: investigate
description: Investigate bugs across projects — ticket system, error tracking, codebase search, data, fix plan
argument-hint: "<TICKET-KEY | ERROR-ID | description>"
---

## Cross-project investigation

**Input:** $ARGUMENTS

Trace an issue across the project boundary: from the surface symptom down
through the request path to the root cause, and produce a fix plan.

## Dependency map

Resolve all project paths from `~/.claude/project-repos.json`. The map
below is the *example* topology shipped with this toolkit — replace it in
`knowledge/service-dependency.md` for your actual system.

```
        FRONTEND                API                 SERVICE
    ┌────────────┐          ┌─────────┐         ┌───────────┐
    │   mobile   │ ──┐      │         │         │           │
    │  (Flutter) │   ├────▶ │   api   │ ──────▶ │  server   │
    └────────────┘   │      │ (Kotlin)│         │ (Python)  │
    ┌────────────┐   │      │         │         │           │
    │    web     │ ──┘      └─────────┘         └───────────┘
    │ (Next.js)  │
    └────────────┘
```

## Step 1 — identify & gather context (parallel)

Detect the input type and fetch in parallel:

**Ticket key** (e.g. `MOB-1234`, `API-42`):
- Fetch: summary, description, comments, linked issues, labels
- Check for any `escalated` / `ai-analyzed` labels

**Error tracker ID** (Sentry, etc.):
- Stack trace, affected users, frequency
- Seer AI analysis if available

**Free-text description**:
- Search both ticket system and error tracker for matches

**Also check for duplicates** — e.g. an open ticket with overlapping symptoms.

## Step 2 — identify the layer

| Symptom                                     | Layer   | Shortname          |
|---------------------------------------------|---------|--------------------|
| Flutter stack trace, widget errors          | client  | `mobile` or `web`  |
| "Web", "dashboard", UI component bug        | client  | `web`              |
| "App", "mobile", screen names               | client  | `mobile`           |
| HTTP 4xx/5xx from API calls                 | gateway | `api`              |
| Business logic, state machine, payment     | service | `server`           |
| DB errors, SQL issues                       | service | `server`           |
| Auth, sessions, tokens                      | service | `server` or `api`  |
| Webhook or integration errors               | service | `server`           |

## Step 3 — trace through layers

Starting from the identified layer, work your way down the chain:

1. **Client layer** — search for the failing code path
   - API client calls, error handling, model parsing
2. **API / gateway layer** — search the endpoint handler
   - Controller, service, DTO definitions
   - Verify request/response mapping (snake/camel, nullable fields)
3. **Service layer** — search business logic
   - State machines, data access, transaction boundaries
4. **Cross-cutting**
   - Compare DTO fields between layers
   - Check schema/contract files on both sides of a boundary

## Step 4 — check production data (if specific IDs are mentioned)

If your Snowflake/Bigquery/etc. is configured, run a scoped query via the
`/snowflake` skill. Keep the window narrow — no full-table scans.

## Step 5 — check recent changes

For each affected file:
```bash
git -C {repo-path} log --oneline -20 -- {affected-files}
```

Look for recent modifications that could have introduced the bug.

## Step 6 — report

```markdown
## Investigation: {KEY} — {summary}

**Priority:** {P1/P2/P3}
**Impact:** {users affected, frequency}
**Origin layer:** {mobile | web | api | server}
**Impact path:** {e.g. mobile → api → server}

### Root cause
- **What:** {description}
- **Where:** {file:line}
- **Why:** {mechanism}

### Evidence
- **Error tracker:** {issue link, event count, trace summary}
- **Code:** {file:line}
- **Recent change:** {commit that may have introduced it}
- **Data:** {query findings, if any}

### Affected code locations
| Layer | File | Line | Description |
|-------|------|------|-------------|
| {layer} | {path} | {line} | {what this code does} |

### Suggested fix
1. {step-by-step}
2. {which files to modify in which project}

### Related tickets / issues
- {links}
```

## Step 7 — offer next steps

- **Fix it now** → route to `/start {KEY} {repo1,repo2,...}`
- **Need more info** → what to check next
- **Duplicate** → link to the existing ticket
