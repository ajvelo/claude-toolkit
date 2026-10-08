---
name: monitor
description: Post-merge monitoring for a /ship ticket - runs the Monitoring spec from its state file against Sentry, a read-only SQL source, PostHog and GitHub, logs results, and flags regressions.
when_to_use: User asks "how is {TICKET} doing in prod", "check monitoring for {TICKET}", or /ship tick finds a ticket in `ship-state due`. `/monitor due` runs every due ticket.
disable-model-invocation: false
argument-hint: "<TICKET-KEY | due>"
---

## Monitor

**Arguments:** $ARGUMENTS

Read-only apart from the state file. `due` → run the steps below for each key in `ship-state due`.

## Steps

1. `ship-state claim KEY monitor 30` (skip if locked). Read `## Monitoring spec`, `merged_at` and `monitor_until`.
2. **Empty or vague spec?** Don't make one up. Log one `unavailable` row, put the problem in `## Open questions`, set `awaiting: clarification`, and stop.
3. Run each check against its `source`:

   | Source | How | Notes |
   |---|---|---|
   | `sql` | `$SHIP_SQL "<SQL>"`, a wrapper you provide that runs one query against a **read-only** replica or warehouse and prints JSON lines | Never point it at a writable primary. The loop's guard blocks interactive database shells, so the wrapper must be its own script. Window starts at `merged_at` |
   | `sentry` | `sentry-cli` or the Sentry API with `SENTRY_ORG` and the project slug from the CLAUDE.md mapping. **New issues**: unresolved issues first seen since `merged_at` matching the query. **Counts**: event and user counts for the query over the window | Counts only cover projects your token's team can see. **A project missing from the result is `unavailable`, never 0.** Baseline is the same query over the window before `merged_at`. If a project reports every environment as `production`, filter by time, not environment |
   | `posthog` | `curl -s -H "Authorization: Bearer $POSTHOG_PERSONAL_API_KEY" -H 'Content-Type: application/json' "$POSTHOG_HOST/api/projects/$POSTHOG_PROJECT_ID/query/" -d '{"query":{"kind":"HogQLQuery","query":"<HogQL>"}}'` | Needs a personal API key with query read access; without one the check is `unavailable`. Low-volume events are noisy per day: compare multi-day totals |
   | `gh` | `gh run list`, `gh api` (deploy workflows, GitOps image bumps) | Use to confirm the change has actually **deployed** before trusting a "clean" result. GitHub search is fuzzy, so a no-revert check uses exactly `gh pr list -R <repo> --state all --search 'Revert <KEY> in:title' --json number,title --jq '[.[] \| select(.title \| test("^Revert"; "i"))]'`, regression if non-empty |

   Compute `baseline` exactly as the spec says (default: the same query over the 7 days before `merged_at`, normalised per day).
4. Append one row per check to `## Monitoring log`: `ok`, `regression`, or `unavailable` (with the reason, e.g. "sentry token expired", "SHIP_SQL not set"). **`unavailable` never counts as `ok`.**
5. Decide:
   - Any `regression` → queue the one-line regression comment (`.claude/skills/ship/stages.md` → *Jira mirror*) in `## Pending Jira writes`, set `awaiting: jira-write`, and put the evidence in `## Next step`. Keep monitoring.
   - The same source `unavailable` on 2 runs in a row → `awaiting: clarification`, because nobody is actually watching.
   - Past `monitor_until`, no regressions, and every check has at least one `ok` → queue the "clean" mirror line, `stage: close`, `awaiting: close`.
   - Otherwise → `next_check = now + check_every_hours`.
6. On every path above, including the parking ones, set `next_check = now + check_every_hours`, so a parked ticket isn't re-checked on every tick. Update `## Next step`, append to `## Log`, `ship-state release KEY monitor`. Report one line: `KEY: <n> ok, <n> regression, <n> unavailable, next <time>`.

## Rules

- Never post to Jira, reopen tickets, or touch PRs here. Regressions go through /ship's `jira-write` gate.
- Never widen a query to make a check pass. If the spec looks wrong, record it under `## Open questions`.
