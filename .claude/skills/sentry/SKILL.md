---
name: sentry
description: Check Sentry for production errors across all projects
argument-hint: "[issue-id, search-query, or project-shortname]"
---

## Sentry Production Monitoring

**Organization:** set via `SENTRY_ORG` env var (or configured in your
Sentry MCP server connection — see `docs/MCP-SETUP.md`).

**Argument:** $ARGUMENTS

## Project Mapping

Resolve repo paths from `~/.claude/project-repos.json`. The Sentry project
slug may differ from the repo shortname — maintain the mapping below as
projects are added.

| Shortname | Sentry project slug |
|-----------|---------------------|
| mobile    | `demo-mobile`       |
| web       | `demo-web`          |
| api       | `demo-api`          |
| server    | `demo-server`       |

(Infra / Terraform has no Sentry project; add/remove rows to match yours.)

## Actions

### No argument — recent issues across projects
Search for recent unresolved issues across all monitored projects.

### Project shortname (e.g. `api`, `web`)
Show recent issues for that specific project.

### Issue ID
Get detailed information:
- Full stack trace
- Affected users count
- First/last seen dates
- Seer AI analysis (if available)

### Search query (e.g. `payment failed`, `null pointer`)
Search across projects for matching issues.

## Analysis Steps

1. **Identify** — get issue details and stack trace
2. **Assess impact** — users affected, frequency, trend
3. **Root cause** — use Seer AI analysis if available
4. **Locate in code** — find the relevant code using the resolved repo path
5. **Suggest fix** — provide an actionable next step

## Output Format

For each issue:
- **ID & Title**
- **Project:** [shortname] ([sentry slug])
- **Impact:** X users, Y events
- **Stack trace summary**
- **Relevant code location** (absolute path from the project registry)
- **Suggested fix**
