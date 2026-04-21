# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-04-21

### Added
- 17 slash-command skills covering ticket-to-PR workflow, investigation, build/test, release, onboarding
- 12 specialist sub-agents (Kotlin, Flutter, TypeScript, Python, E2E, code/qa/ux review, database, Kafka)
- 7 safety hooks: bash-safety, write-guard, auto-format, bash-triage, notification, statusline, pre-compact
- Generic installer with auto-discovery of repo paths across `$HOME`, `~/code`, `~/projects`, custom search paths
- 5 example project instruction files (mobile, web, api, server, infra)
- Knowledge base with starter gotchas and a worked Python-async reference
- MCP server templates for Sentry, Atlassian, Figma, PostHog, Notion, context7, Chrome DevTools, Playwright
- GitHub Actions CI: shellcheck, JSON validation, SKILL/agent frontmatter validation, installer smoke test

[Unreleased]: https://github.com/ajvelo/claude-toolkit/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/ajvelo/claude-toolkit/releases/tag/v0.1.0
