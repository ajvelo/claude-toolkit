# /ship stage reference

## Stages

| Stage | Auto | Does | Exits to |
|---|---|---|---|
| `pickup` | yes | `ship-jira view KEY`, fill `## Ticket`, `summary`, `type`. Route repos with `/start`'s `ticket-routing.md` + Step 2b. Bug tickets → run the `/investigate` flow and record the root cause. Sparse ticket with no ACs → write the questions into `## Open questions` | `plan`, or park `clarification` |
| `plan` | yes | `/start`'s analysis step. Write `## Plan`, `## Decisions`, the `## QA plan` (see `qa.md`), and the `## Monitoring spec`: this is the only stage that understands the change well enough to say what "broken" looks like. Before writing the spec, read `.claude/skills/monitor/SKILL.md` and use only the query shapes in its source table | park `plan-approval`, with the → In Progress transition queued (see *Jira status*) |
| `implement` | if `mode: loop` | `/start`'s implementation steps: code + tests, the project's own check command (`/start/validation-commands.md`), self-review, verification agents. Then **QA before publish**: write the web QA scripts from the `## QA plan`, run the `web-local` checks, and record them in `## QA results` (`qa.md`). Record everything in `## Verification` | park `publish`, or `qa-failed` |
| `pr` | partly | After `publish`: draft PR via `/pr` rules. Then **auto**: watch `gh pr checks`; on a red check, fix it in the worktree and park `push`. **QA after publish**, for every new head SHA: once the preview is live, run the `web-preview` checks (`qa.md`). A failing check parks `qa-failed`. Detect merge with `gh pr view --json state,mergedAt`. A PR closed without merging → `awaiting: clarification` ("PR closed unmerged: reopen, replace or abandon?") | `monitor` once every PR is merged |
| `monitor` | yes | `/monitor KEY` whenever `ship-state due` lists it | `close`, or park `jira-write` on regression |
| `close` | no | Post the final mirror line, remove worktrees, add any gotchas to `knowledge/`, `ship-state archive KEY` | `done` |

On merge: set `merged_at`, `monitor_until = merged_at + watch_days`, `next_check = now`, `stage: monitor`. For multi-repo tickets, wait until the **last** PR merges; keep `/start`'s deploy order in `## Repos`.

## Gates

Unattended mode writes the gate into `awaiting` and the exact proposed action into `## Next step`, then stops. Interactive mode asks with `AskUserQuestion`.

| `awaiting` | Ask | Options → effect |
|---|---|---|
| `clarification` | the `## Open questions` | answers into `## Ticket` → `stage: plan` |
| `reassigned` | who it's assigned to now, from `## Open questions` | **Continue anyway** → `assignee_override: yes`, `awaiting` back to the gate named in the question (`none` if it was `none`) · **Abandon** → `KEY abandon` |
| `plan-approval` | show `## Plan` + `## Monitoring spec`, plus the queued → In Progress transition | **Approve, loop implements** → `mode: loop`, `stage: implement` (this also approves creating the branch in a worktree) · **Approve, I'll drive** → `mode: interactive` · **Revise** → feedback into `## Decisions`, back to `plan` · **Drop** → abandon |
| `publish` | diff stat, commit message, branch, PR title + body. Write the body from the target repo's `.github/pull_request_template.md` when it has one (re-read it every time), otherwise `/pr`'s format. Include the QA checks and results. Add the `## QA evidence` section and tell the user how to copy the before/after videos and post them as one PR comment (`qa.md`) | **Commit + push + draft PR** · **Commit only** · **Revise** |
| `push` | the CI fix diff | push / revise |
| `qa-failed` | the failing check, its screenshot path and the proposed fix | fix (back to `implement`, loop mode) · accept with a reason in `## Decisions` · drop |
| `jira-write` | every item in `## Pending Jira writes`, together | post all / edit / drop |
| `close` | outcome summary + proposed knowledge/ edits | close / keep monitoring N more days |

Gate approval only covers the action that was asked about. Nothing carries over to the next gate.

## Label queue (intake)

```bash
ship-jira search 'assignee = currentUser() AND labels = claude-ready AND statusCategory = "To Do" ORDER BY priority DESC'
```
At most **2 new tickets per tick**. Never remove the label: that's a Jira write. Whether a state file exists is the dedupe check (look in `done/` too). Tickets already In Progress are skipped, because the pipeline assumes you're working on them yourself.

## Worktrees

Loop-mode implementation never touches your checkout:
```bash
git -C {repo} fetch origin {base}
git -C {repo} worktree add ~/.claude/work/trees/{KEY}-{shortname} -b {branch} origin/{base}
```
- Branch shape follows `/start`'s branch step.
- Install dependencies in the worktree before checking (`pnpm install`, `fvm flutter pub get`, `uv sync`).
- Project instructions don't auto-load for the worktree path. Read `projects/<file>` (column 3 of `repos.conf`) explicitly.
- A repo whose checks run inside a container that mounts your main checkout can't be checked from a worktree. Mark it `mode: interactive` in its `projects/*.md`, and park when the plan touches it.
- At close: `git -C {repo} worktree remove <path>`. Only delete the branch once its PR is merged.

## Jira mirror

**One line per comment.** Comment at exactly two moments, queued in `## Pending Jira writes` and posted only through the `jira-write` gate:

| Moment | Text |
|---|---|
| Draft PR opened | `[claude] Draft PR: <url>` (one URL per repo, space-separated) |
| Monitoring ended | `[claude] Monitored <N>d after merge: clean.` or `[claude] Regression after merge: <check id> <value> vs <baseline>.` |

No plans, no summaries, no lists. Before posting, check `ship-jira comments KEY` for an existing comment with the same `[claude]` prefix and moment. Post with `ship-jira comment KEY "<line>"`, then record the returned id in `## Jira mirror`.

## Jira status

Queue a transition in `## Pending Jira writes` at each of these moments. Post it through the same gate as the mirror line, or ask in the same confirmation when interactive:

| Moment | Move to |
|---|---|
| Plan approved | `In Progress` |
| Draft PR opened | `In Review` |
| Closed after monitoring | `Done` |

```bash
ship-jira view KEY | jq -r .status        # check first
ship-jira transition KEY "<status name>"
```
- Skip the transition if the ticket is already in that status or further along (someone may have moved it by hand).
- Projects name statuses differently. Use that project's equivalent, and if the transition fails, log it and drop it rather than guessing.
