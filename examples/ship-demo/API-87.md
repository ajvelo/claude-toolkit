---
ticket: API-87
summary: Return 409 when a coupon is already redeemed
type: Bug
source: label-queue
stage: pr
awaiting: none
mode: loop
repos: api
merged_at: 
monitor_until: 
next_check: 
lock:
assignee_override:
created: 2026-10-06T08:12:00Z
updated: 2026-10-08T13:40:00Z
---

## Next step
Watch CI on https://github.com/example/demo-api/pull/31; on red, fix in the worktree and park push.

## Repos
| Repo | Branch | Worktree | PR | CI | Merged |
|------|--------|----------|----|----|--------|
| api | fix/API-87-coupon-409 | ~/.claude/work/trees/API-87-api | https://github.com/example/demo-api/pull/31 | green | |

## QA results
| When (UTC) | Check | Surface | SHA | Result | Evidence |
|------------|-------|---------|-----|--------|----------|
| 2026-10-08T11:05Z | redeemed-coupon-409 | ci | 4f1c2ab | pass | CI job api-tests |

## Log
- 2026-10-08T10:41Z pr: draft PR opened, Jira moved to In Review
- 2026-10-08T11:05Z pr: CI green on 4f1c2ab, waiting for review
