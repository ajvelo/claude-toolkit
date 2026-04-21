---
name: start
description: Start work on a ticket — auto-detects project, handles single- or multi-repo tickets
disable-model-invocation: false
argument-hint: "<TICKET-KEY> [project-shortname(s)] [module]"
---

## Start Ticket

**Arguments:** $ARGUMENTS

Use the **project registry** and **dependency map** in the toolkit
`CLAUDE.md` for shortname → path → tech → base branch mapping. Read
`validation-commands.md` and `ticket-routing.md` in this skill directory
for reference tables.

## Step 1 — parse input

Extract: ticket key, project shortname(s), optional module. If no
shortname is provided, read `ticket-routing.md` to infer from the ticket
prefix. If ambiguous, ask the user.

If multiple repos are specified (e.g. `API-42 server,api,web`), go to
**Multi-repo mode** (Step 2b).

## Step 2 — fetch the ticket

Pull summary, description, acceptance criteria, issue type.

**Sparse ticket?** If there are no ACs and the description is vague, use
`AskUserQuestion` to clarify requirements before proceeding.

### Step 2a — auto-investigate (bug / support tickets)

For ticket prefixes that represent bug reports (configurable — see
`ticket-routing.md`), run the `/investigate` flow first:

1. Full investigation: ticket context, error-tracker, codebase search, data
2. Present the report — root cause, affected code, suggested fix
3. The investigation determines the **actual repo(s)** to work in
4. Confirm the fix plan and target repo(s) before proceeding to Step 3

### Step 2b — detect multi-repo scope

If repos were explicitly listed in arguments, use those. Otherwise apply
these heuristics:

| Ticket signal                                           | Likely repos              |
|---------------------------------------------------------|---------------------------|
| UI-only mention                                         | `web` or `mobile`         |
| "API", "endpoint" + backend logic                       | `api` + `server`          |
| Payment/billing/invoice                                 | `server` + `api`          |
| New feature with UI + API + DB                          | `server` → `api` → `web`/`mobile` |
| Infra / IAM / DB change                                 | `infra` + affected service |

If multi-repo is detected, confirm via `AskUserQuestion`, then go to
**Multi-repo mode**.

If single-repo, continue to Step 3.

## Step 3 — create branch

```bash
git -C {project-path} fetch origin {base-branch}
git -C {project-path} checkout -b {type}/{TICKET-KEY}-{slug} origin/{base-branch}
```

Branch type from the ticket's issue type:
- Story / Feature → `feat/`
- Bug → `fix/`
- Task / Sub-task → `chore/`
- Improvement → `refactor/`

Some projects enforce a different separator (e.g. `type/TICKET-KEY/slug`
with slashes). Check `projects/{shortname}.md` if the branch push fails.

## Step 4 — deep analysis

Before writing code, spawn **2 parallel Explore agents** — a Pattern Scout
and an Impact Analyzer. See `agent-prompts.md` for full prompt templates.

Combine reports into an implementation plan:
1. **Files to create / modify** — with rationale and order
2. **Patterns to follow** — with file references
3. **Test files needed** — mirroring source paths
4. **Risk areas** and **scope estimate** (small: 1–3 files, medium: 4–8, large: 9+)

**Present plan and wait for user confirmation** via `AskUserQuestion`
before implementing.

## Step 5 — implement

1. **Code + tests together** — follow patterns from Step 4, keep changes minimal
2. **Run validation** — read `validation-commands.md` for the project's command. Fix every failure.
3. **Diff check** — `git -C {project-path} diff --name-only` — verify no unplanned files changed

## Step 6 — self-review

Read `git -C {project-path} diff` and check for:
- **Bugs** — null safety, unhandled errors, edge cases, off-by-one
- **Side effects** — broken callers, missing migrations/flags, compatibility breaks
- **Minimality** — no dead code, no formatting-only churn, no scope creep
- **Architecture** — correct patterns, layer placement, no circular deps

Fix issues. Re-run validation if code changed.

## Step 7 — parallel verification

**Skip for trivially small changes** (<20 lines) → go to Step 8.

Spawn 2–3 agents in parallel: test-verifier, code-quality-reviewer,
ticket-matcher. See `agent-prompts.md` for prompt templates and verdict
logic.

## Step 8 — finalise

- **READY** → Show report, confirm, then `git add` → `git commit` → `git push` → `gh pr create --draft`. For UI changes, remind the user: "Run `/verify --visual-only` to double-check the UI."
- **NEEDS WORK** → Show issues, fix, re-validate. Re-run Step 7 only for substantial changes.
- **BLOCKED** → Show blockers, resolve, re-run from Step 7.

## Rules

- Always confirm before `git add`, `git commit`, `git push`, `gh pr create`
- Always create DRAFT PRs
- Present implementation plan and wait for confirmation before coding (Step 4)
- For UI changes, defer visual verification to `/verify --visual-only`
- Some projects enforce Conventional Commits on commit messages (via `commitlint` + a pre-commit or CI check) — respect the project's rule

---

## Multi-repo mode

When a ticket spans multiple repos, orchestrate implementation across all of them.

### M1 — plan implementation order

**Rule: implement bottom-up (backend first, client last).**

```
1. server     — if DB / model changes are needed
2. api        — endpoints, DTOs, mappers
3. web / mobile — UI implementation
```

For each repo, plan:
- **What changes** (new endpoint, new field, UI component, …)
- **Files to modify** (use Explore agents per repo)
- **Branch name** (same ticket key, different repo)
- **Dependencies** (e.g. "api needs server PR merged first")

Present the full plan via `AskUserQuestion` and wait for approval.

### M2 — execute per repo (sequential)

For each repo in dependency order, run Steps 3–8 from the single-repo flow
(branch → analyse → implement → review → finalise).

**Checkpoint after each repo:** show diff summary and ask:
- "Ready to move to {next-repo}?"
- "Want to commit and create the draft PR for {current-repo} first?"

### M3 — cross-repo verification

After all repos are done:

1. **Contract alignment** — DTO fields match across layers:
   - Server model → API DTO → client model
   - Check snake_case vs camelCase mapping annotations
2. **Deploy order** — remind which PRs should merge first
3. **Missing pieces** — check for: feature flags, translations, migration
   files, config changes, documentation updates

### M4 — summary report

```markdown
# Multi-service implementation: {TICKET-KEY}

**Ticket:** [{KEY}]($JIRA_HOST/browse/{KEY}) — {summary}

## Repos changed

| # | Repo    | Branch             | PR    | Status |
|---|---------|--------------------|-------|--------|
| 1 | server  | fix/KEY-...        | #123  | Draft  |
| 2 | api     | fix/KEY-...        | #456  | Draft  |
| 3 | web     | fix/KEY-...        | #789  | Draft  |

## Deploy order
1. server #123 (first — DB/model change)
2. api #456 (depends on server)
3. web #789 (depends on api)

## Cross-repo contracts
| Field   | server (Python)  | api (Kotlin DTO) | web (TypeScript) |
|---------|------------------|------------------|------------------|
| {field} | snake_case       | @JsonProperty    | camelCase        |

## Remaining
- [ ] {Any follow-up items}
```
