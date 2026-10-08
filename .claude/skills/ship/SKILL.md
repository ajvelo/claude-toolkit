---
name: ship
description: End-to-end ticket pipeline - pickup, plan, implement, draft PR, post-merge monitoring, close - resumable from any stage via a per-ticket state file. Has an unattended `tick` mode for a 24/7 /loop.
when_to_use: User says "ship {TICKET}", "resume {TICKET}", "what's in flight", "what's waiting on me", or wants a ticket carried from Jira to monitored production. Also the body of the 24/7 loop (`/loop /ship tick`).
disable-model-invocation: false
argument-hint: "[TICKET-KEY [repos] | tick | TICKET-KEY abandon]"
---

## Ship

**Arguments:** $ARGUMENTS

State lives in `~/.claude/work/{KEY}.md`, managed through `ship-state` (`scripts/ship-state.sh`, on PATH via install.sh). **Read the state file before acting and update it before stopping**: the `## Next step` section must always tell a cold session exactly what to do next. Stage details, gates and the Jira mirror format are in `stages.md`; QA plans, web scripts and before/after videos are in `qa.md`. Jira is reached through `ship-jira` (`scripts/ship-jira.sh`, Jira Cloud REST), because the loop's shell scripts can't call an MCP server.

## Mode by argument

| Argument | Mode |
|---|---|
| *(none)* | **Queue**: start with `ship-state digest --mark` and summarise what happened since the user last looked (one line per ticket). Then run `ship-state list` fresh (never answer from an earlier read) and `ship-state awaiting`. Offer to resume the parked tickets one at a time, and flush pending Jira writes in one confirmation. If `ship-loop status` prints `loop: running`, don't suggest starting it; the tmux session alone proves nothing, because `ship-down` keeps it |
| `KEY [repos]` | **Interactive**: `ship-state init KEY`, claim the lock as `interactive`, resume at `stage`. Clear any `awaiting` gate by asking the user |
| `tick` | **Unattended**: see below. Never calls `AskUserQuestion` |
| `KEY abandon` | Set `stage: done`, log the reason, release the lock, `ship-state archive KEY` |

## Interactive mode

0. **Not yet tracked** (no file at `ship-state path KEY`, nor in `done/`): before `ship-state init`, run `ship-jira search "key = KEY AND assignee = currentUser()"`. Empty means it isn't yours: show the assignee (`ship-jira view KEY`) and ask "KEY is assigned to <name>, not you. Continue anyway?" No → stop without creating anything. Yes → `init`, then `ship-state set KEY assignee_override yes`.
1. `ship-state claim KEY interactive 240` (4-hour TTL, so the loop doesn't take over while you're mid-stage). If the loop holds it, wait for that tick to finish instead of racing it. Claims aren't re-entrant: if `interactive` still holds it from an earlier step that didn't release, and no other session is working on the ticket, `ship-state release KEY interactive` and claim again.
2. Read the whole state file now, even if you read it earlier in this session, because the loop may have moved it on. If `awaiting` is set, resolve that gate first (see the gate table in `stages.md`). Never re-run a stage whose gate is set.
3. Run stages from `stage` onward until a gate the user declines, or until `stage: monitor`. Monitoring is the loop's job.
4. At every stage transition: update the frontmatter via `ship-state set`, rewrite `## Next step`, append a line to `## Log`, and queue the stage's Jira mirror line and status transition (see `stages.md`).
5. `ship-state release KEY interactive` when you stop.

## Unattended mode (`tick`)

Runs in the `loop` window that `ship-loop` starts, with `SHIP_UNATTENDED=1` set. In that mode `hooks/bash-safety.sh` **denies** commit/push/merge, PR and issue writes, `gh api` writes, `ship-jira` writes and database shells. If a command is denied, park the ticket; don't look for a workaround. You clear gates in the `work` window (`/ship`).

To find out which window you're in, run `ship-loop here` (prints `ship:loop` or `ship:work`). Don't use `tmux display-message -p` without `-t "$TMUX_PANE"`: it reports the window the user is looking at, not yours. `ship-loop status` says which windows are running Claude.

The loop session runs for days, so keep its own context small: **delegate every stage to a subagent** (`general-purpose`) and print one summary line per ticket.

**Start every tick with `ship-state pending`.** If it exits 1 (`idle`), reply with one line, schedule the next wakeup (3300s, inside the 1-hour prompt-cache lifetime) and stop: no Jira search, no subagents, no other reads. Otherwise do only what it lists (`intake`, `advance`, `monitor`). A PR waiting for review or CI shows as a `wait` line: no subagent for it.

0. **Jira sweep**: for tickets at `pickup`, `plan` or `implement` with `awaiting: none` (not `pr`: people often move a ticket to Done as they merge), run one search: `key in (<keys>) AND statusCategory = Done`. For each hit, set `awaiting: clarification` and add "Closed in Jira as <status>: abandon?" to `## Open questions`. Tickets at `monitor` are expected to be Done, so skip them. For each `reassigned KEY` line from `pending` (no longer assigned to you, before its PR exists): add "Reassigned in Jira to <assignee> while parked at `<current awaiting>`: continue or abandon?" to `## Open questions`, then set `awaiting: reassigned`. No subagent and no other work on that ticket this tick.
1. **Intake**: run the JQL in `stages.md` → *Label queue*. `ship-state init KEY label-queue` for each result (it's a no-op for keys it already knows, including archived ones).
2. **Advance**: for each ticket from `ship-state list` where `awaiting` is `none`, the stage can run unattended (the *Auto* column in `stages.md`), and the stage is not `monitor` (step 3 handles that):
   - `ship-state claim KEY loop 60`; skip the ticket if it's locked. The subagent runs `ship-state renew KEY loop` at least every 20 minutes during long stages (implement, QA), so a later tick can't take the lock mid-run.
   - Spawn one subagent per ticket with: the state-file path, "run stage `<stage>` of `.claude/skills/ship/` in UNATTENDED mode; read SKILL.md and stages.md first; never ask questions, never do a gated action; write the gate into `awaiting` and the exact proposed action into `## Next step`, then stop".
   - `ship-state release KEY loop` afterwards, even if the subagent failed. Log the failure in the state file.
3. **Monitor**: for each key in `ship-state due`, run `/monitor KEY` (also via a subagent).
4. **Report**: one line per ticket that changed, then `ship-state awaiting-count`.
5. **Pace** (`/loop` dynamic mode): 600s if `ship-state pending` printed a `ci-running` line; otherwise 3300s. Never 3600s: a wakeup at the full hour misses the prompt cache and rewrites the whole context.

Open the state file with the Read tool, not `cat`, before editing it, and read it again after any `ship-state set`/`claim`/`release`, which rewrite it: Edit refuses a file it hasn't read or that changed since. Write prose (state-file sections, PR bodies) with the Write/Edit tools, not Bash heredocs: the guard checks the start of every line of a Bash command, so a heredoc line that begins with a blocked command is denied.

A tick never commits, pushes, opens a PR, writes to Jira, or creates a branch outside a pre-approved worktree (see `stages.md` → *Worktrees*).

## Shared build machines

If the loop runs on a box other people also use, a runaway test suite takes everyone down with it. These rules apply to every build and test run, in both modes:

- **A ticket's tests run in one place.** Before running anything, check `pgrep -af "<worktree path>"` and the ticket's `lock:`. If the loop has a run going, the work window waits for its result in `## Verification` and never starts a second one.
- **One heavy build at a time**, box-wide: `pgrep -af '[G]radleDaemon|[f]lutter_tools|[p]npm'` must print nothing. Run it as its own Bash call: in a compound command, a later `pnpm`/`gradlew` in the same line matches it.
- **Check headroom first** (Linux): `awk '{print $1}' /proc/loadavg` and `free -m | awk '/^Swap/ {print ($2 ? $3*100/$2 : 0)}'`. If the 1-minute load is above the core count or swap is over 50%, don't build. Write "box busy (<reason>, <UTC time>): retry" into `## Next step` and `## Log`, leave `awaiting: none` and release the lock. The next tick retries. Don't set an `awaiting` value: `pending` skips parked tickets and `set awaiting` notifies the user.
- **Scope tests to the modules you touched.** Run the full suite only when the user asks for it, under `nice -n 10`.
- **Clean up afterwards**: stop build daemons (`./gradlew --stop`) and remove leftover test containers only if no other build is running.

## Rules

- All Autonomy Rules in the toolkit CLAUDE.md still apply. Unattended mode **parks** at a gate; it doesn't skip it.
- Idempotent: before creating anything, check whether it already exists (`git ls-remote --heads`, `gh pr list --head`, the `## Jira mirror` log).
- Reuse the existing skills: /start's analysis and verification steps, /pr's title and body rules, /investigate for bug tickets. Don't restate their rules here.
- Write absolute dates (UTC) everywhere in the state file.
- **Tests cover the change, not the QA plan.** For a bug fix, write one test that fails on the base branch and passes on the branch. Add a test for a nearby case only if the diff could plausibly break it. QA checks of unchanged behaviour stay QA checks; don't turn them into unit tests, and don't test components the diff doesn't touch.
- **Check the toolchain before writing code.** At the start of `implement`, run one cheap test task in the worktree. If it can't run (missing credentials, SDK or dependency), park `clarification` with the exact fix instead of implementing code you can't test.
- **Report pipeline problems.** If an instruction in these skill files (or /start, /pr, /monitor) turned out wrong, missing or ambiguous, or a command failed for a reason the skills didn't anticipate, log it with `ship-state issue <KEY> <stage> '<what happened> — <what the skill should say>'`. First `grep -i` `~/.claude/work/issues.log` for the problem: if it's already logged under another ticket, don't log it again. Exit 2 means that ticket and stage already has a line, which it prints: if it's the same problem, stop; add `--new` only for a different one. Fix the ticket as best you can, but don't edit the toolkit from a tick.
