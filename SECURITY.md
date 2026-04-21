# Security Policy

## Supported versions

Only the `main` branch receives security updates.

## Reporting a vulnerability

Please **do not** open a public issue for suspected security problems.

Report privately via GitHub Security Advisories:
https://github.com/ajvelo/claude-toolkit/security/advisories/new

Include:
- A description of the issue and its impact
- Steps to reproduce
- The affected commit SHA

You'll receive an initial response within a few days. Once confirmed, a
fix is developed privately and a coordinated disclosure is published.

## Scope

This toolkit ships shell scripts (hooks, installer, discover-repos) that
run on the developer's machine. In-scope: command injection, arbitrary
file writes outside the install targets, privilege escalation via the
hooks. Out-of-scope: Anthropic API behaviour, third-party MCP server
bugs, and security of the repositories the user points the toolkit at.
