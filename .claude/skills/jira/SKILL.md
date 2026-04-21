---
name: jira
description: Look up or work with Jira issues across all projects
argument-hint: "[issue-key or search query]"
---

## Jira Integration

**Query:** $ARGUMENTS

## Ticket prefix → project mapping

Resolve repo paths from `~/.claude/project-repos.json`. The `JIRA_HOST`
env var controls the Atlassian host (see `docs/MCP-SETUP.md`).

| Prefix  | Jira project | Codebase (shortname)          |
|---------|--------------|-------------------------------|
| `MOB-`  | MOB          | mobile (Flutter)              |
| `WEB-`  | WEB          | web (Next.js)                 |
| `API-`  | API          | api (Kotlin/Ktor)             |
| `SRV-`  | SRV          | server (Python/FastAPI)       |
| `INF-`  | INF          | infra (Terraform/Helm)        |

Customise this table to match your projects.

## Actions

### Issue key (e.g. `MOB-1234`, `API-42`)
Show:
- Summary + description
- Status + assignee
- Priority + labels
- Linked issues + comments
- Which codebase it maps to (from the table above)

### Search query
Natural language or JQL:
- "my open issues"
- "bugs in api"
- `project = MOB AND status = "In Progress"`
- `assignee = currentUser() AND sprint in openSprints()`

## Output format

For each issue:
- **Key:** TICKET-123
- **Summary:** brief title
- **Status:** current status
- **Assignee:** who's working on it
- **Priority:** priority level
- **Project:** which codebase (from mapping)
- **Link:** `https://$JIRA_HOST/browse/TICKET-123`

If the issue relates to code, suggest searching the relevant codebase paths.
