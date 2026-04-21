# MCP server setup

This guide covers configuring the MCP (Model Context Protocol) servers the
toolkit's skills reference. None are strictly required — every skill has
a graceful "not configured" path — but most skills are more useful with
their corresponding server connected.

All servers below use the SSE transport (they run as HTTP endpoints you
authenticate against in a browser) except where noted.

## Anthropic / context7 — library docs

No account required.

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
```

## Atlassian — Jira and Confluence

Host is your Atlassian cloud URL (`your-org.atlassian.net`). Surface it to
skills via `JIRA_HOST` env var.

```bash
claude mcp add --transport sse atlassian-mcp-server https://mcp.atlassian.com/v1/sse
```

Authorise in the browser; grant access to the site your team uses.

## Sentry — error tracking

```bash
claude mcp add --transport sse sentry https://mcp.sentry.dev/mcp
```

Configure `SENTRY_ORG` as the slug your team uses.

## PostHog — feature flags & analytics

PostHog has EU and US regions — use the one your account is on:

```bash
# EU
claude mcp add --transport sse posthog https://mcp-eu.posthog.com/mcp
# US
claude mcp add --transport sse posthog https://mcp.posthog.com/mcp
```

## Notion — docs, specs, meeting notes

```bash
claude mcp add --transport sse notion https://mcp.notion.com/mcp
```

## Figma — design context

```bash
claude mcp add --transport sse figmaRemoteMcp https://mcp.figma.com/mcp
```

## Chrome DevTools — lightweight browser inspection

```bash
claude mcp add chrome-devtools -- npx -y @anthropic-ai/chrome-devtools-mcp@latest
```

## Playwright — full browser automation

```bash
claude mcp add playwright -- npx -y @anthropic-ai/playwright-mcp@latest
```

## SonarQube / SonarCloud — code quality

Set `SONARQUBE_ORG` to your org slug. The SonarQube MCP server is
community-maintained — see the latest `mcp__sonarqube__*` tool docs for
the current setup steps.

## Snowflake — analytics

The toolkit's `/snowflake` skill uses the `snowsql` CLI rather than an MCP
server (it's simpler to authenticate via SSO + a local config). Install
`snowsql` and set up a named connection — see the `snowflake` skill.

---

## Verifying setup

After adding servers, check which are configured:

```bash
claude mcp list
```

Or inspect `~/.claude/settings.json` → `mcpServers`.

If a skill complains about a missing server, re-run the `claude mcp add`
command and authenticate in the browser.
