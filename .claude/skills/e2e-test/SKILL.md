---
name: e2e-test
description: Run Playwright end-to-end tests
disable-model-invocation: false
argument-hint: "[suite-name] [--headed] [--debug]"
---

## E2E Test Runner

**Arguments:** $ARGUMENTS

Runs Playwright E2E tests in whichever repo holds your E2E suites. If your
repo registry contains a dedicated e2e project, use its shortname; otherwise
run from the project where Playwright is configured.

## Project path

Resolve from `~/.claude/project-repos.json`. The default shortname used by
example configurations is `e2e` (add an entry in `repos.conf` if you have a
dedicated test repo) or `web` (if Playwright lives alongside the web app).

## Suites

Suite mapping is project-specific. Example layouts:

| Layout                       | Command                                  |
|------------------------------|------------------------------------------|
| Suite per folder             | `pnpm playwright test tests/e2e/<suite>` |
| Suite per npm script         | `pnpm test:<suite>`                      |
| All suites                   | `pnpm playwright test`                   |

Document your actual suites in `projects/e2e.md` (or wherever Playwright lives).

## Process

1. `cd` to the resolved project path
2. Parse the suite name and any `--headed` / `--debug` flags
3. Run the command; pass flags through to Playwright
4. Surface failures (test name + the first screenshot/trace path Playwright emits)

## Error recovery

- Browser not installed: `pnpm exec playwright install chromium`
- Deps missing: `pnpm install`
- Tests time out: verify the target environment (staging URL, localhost port) is reachable
