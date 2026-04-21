---
name: sonarqube
description: Check SonarCloud code quality metrics, issues, and quality gates
disable-model-invocation: false
argument-hint: "<project-shortname or sonar-key> [metrics|issues|gate|vulnerabilities]"
---

## SonarCloud Quality Check

**Arguments:** $ARGUMENTS

Query SonarCloud (or a self-hosted SonarQube) for code-quality metrics,
issues, and quality gates. The org is configured in your SonarQube MCP
server connection (`docs/MCP-SETUP.md`) via `SONARQUBE_ORG` — typically your
GitHub org or user.

## Project key mapping

SonarCloud conventionally names a project `{org}_{repo}`. Maintain the
mapping below as projects are onboarded:

| Shortname | SonarCloud key              |
|-----------|-----------------------------|
| mobile    | `{ORG}_demo-mobile`         |
| web       | `{ORG}_demo-web`            |
| api       | `{ORG}_demo-api`            |
| server    | `{ORG}_demo-server`         |

If the shortname isn't in the table, try `{ORG}_{repo-name}` directly or
list all projects.

## Actions

### Default (no action specified)
Quality-gate status + key metrics (coverage, duplications, issues by severity).

### `metrics`
```
mcp__sonarqube__sonarqube_get_project_metrics
```
Core metrics: coverage, bugs, vulnerabilities, code_smells, duplicated_lines_density, sqale_rating, reliability_rating, security_rating.

### `issues`
```
mcp__sonarqube__list_issues
```
Filter by severity (BLOCKER, CRITICAL, MAJOR, MINOR, INFO), type (BUG, VULNERABILITY, CODE_SMELL), or file path.

### `gate`
```
mcp__sonarqube__get_quality_gate
```
Pass/fail status and which conditions failed.

### `vulnerabilities`
```
mcp__sonarqube__get_security_vulnerabilities
```
Security-focused view of issues.

## Output format

```markdown
## SonarCloud: {project}

**Quality Gate:** PASS / FAIL
**Last Analysis:** {date}

| Metric          | Value | Rating |
|-----------------|-------|--------|
| Coverage        | {X}%  | {A-E}  |
| Bugs            | {N}   | {A-E}  |
| Vulnerabilities | {N}   | {A-E}  |
| Code Smells     | {N}   | {A-E}  |
| Duplications    | {X}%  | —      |

### Top issues (if any)
| Severity | Type | File | Message |
|----------|------|------|---------|
```
