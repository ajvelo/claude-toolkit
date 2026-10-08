---
ticket: {{KEY}}
summary:
type:
source: {{SOURCE}}
stage: pickup
awaiting: none
mode:
repos:
merged_at:
monitor_until:
next_check:
lock:
assignee_override:
created: {{NOW}}
updated: {{NOW}}
---

## Next step
Run PICKUP: fetch the ticket, classify it, resolve target repo(s).

## Ticket
<!-- summary, ACs, links; filled at PICKUP -->

## Plan
<!-- approved implementation plan; filled at PLAN -->

## Decisions
<!-- - YYYY-MM-DD: decision — reason -->

## Open questions

## Repos
| Repo | Branch | Worktree | PR | CI | Merged |
|------|--------|----------|----|----|--------|

## QA plan
<!-- written at PLAN; format in .claude/skills/ship/qa.md -->

## QA results
| When (UTC) | Check | Surface | SHA | Result | Evidence |
|------------|-------|---------|-----|--------|----------|

## Verification
<!-- check commands run + result, /verify verdicts -->

## Monitoring spec
<!-- written at PLAN by the session that understands the change. One block per check:
- id: <slug>
  source: sentry | sql | posthog | gh
  query: <exact query / SQL / event>
  baseline: <how to compute it, e.g. same query over the 7 days before merged_at>
  regression_if: <concrete threshold>
-->
watch_days: 7
check_every_hours: 6

## Monitoring log
| When (UTC) | Check | Value | Baseline | Result |
|------------|-------|-------|----------|--------|

## Pending Jira writes
<!-- - [ ] comment|transition: <exact text or target status> -->

## Jira mirror
<!-- - <stage>: comment <id> posted <date> -->

## Log
<!-- - YYYY-MM-DDTHH:MMZ <stage>: what happened -->
