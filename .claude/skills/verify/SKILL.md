---
name: verify
description: Verify the current branch implementation — tests, ticket match, visual review, in parallel
disable-model-invocation: false
argument-hint: "[project-shortname] [surface-hint or URL path] [--quick] [--fix] [--visual-only]"
---

## Implementation Verifier

**Input:** $ARGUMENTS

You are the **team lead** for an implementation verification. Coordinate up
to 3 agents in parallel. Supporting files in this skill directory:
`agent-prompts.md`, `route-mapping.md`, `report-template.md`.

Use the **project registry** in the toolkit `CLAUDE.md` for shortname →
path → base-branch mapping.

### Flags

| Flag            | Effect                                            |
|-----------------|---------------------------------------------------|
| `--quick`       | Tests + ticket match only. Skip visual.           |
| `--fix`         | Auto-fix format/analyzer failures, then re-check. |
| `--visual-only` | Visual + health only. Skip tests and ticket match.|

---

## Step 1 — detect project & gather context

1. Identify project from `$ARGUMENTS` or the current git repo
2. In parallel: `git branch`, `git status`, `git fetch`, `git diff --stat`, `git diff --name-only`, `git log`
3. Extract the ticket key from the branch name; fetch the ticket via MCP if present
4. Check the project's dev server (port comes from `projects/{shortname}.md`)
5. **Pre-flight:** empty diff → abort; uncommitted changes → warn and proceed

## Step 2 — validation strategy

Read `start/validation-commands.md` for the project's validate command.

### Classify changed files

The agent-prompts file contains classification rules for:
- **Flutter** — UI (`*_view.dart`, `*_page.dart`, `*_widget.dart`, etc.), state (`*_view_model.dart`, `*_cubit.dart`), generated (ignore `*.g.dart`, `*.freezed.dart`)
- **TypeScript / React / Next.js** — UI (`*.tsx` in `components/`, `app/`, `features/`), hooks (`use-*.ts`), schemas (`*.schema.ts`), routes (`app/**/page.tsx`, `routes/**`)
- **Kotlin / Python / Go** — backend routes, handlers, DTOs, services

### Agents to spawn

| Condition                                        | test-analyzer | ticket-matcher | visual-health |
|--------------------------------------------------|:-:|:-:|:-:|
| Default (UI files changed in a web/mobile repo)  | yes | yes (if ticket) | yes |
| Default (no UI files, or backend/infra repo)     | yes | yes (if ticket) | no  |
| `--quick`                                        | yes | yes (if ticket) | no  |
| `--visual-only`                                  | no  | no              | yes |

The visual agent applies to any project with a local dev server that
renders HTML/canvas — typically the `web` and `mobile` (Flutter web)
projects.

## Step 3 — start the dev server (if visual needed)

Each project declares its dev command and port in `projects/{shortname}.md`.
If the server is down:

1. Start in the background (e.g. `pnpm dev &` or `fvm flutter run -d chrome &`)
2. Wait ~5–10s and re-check the health endpoint
3. Retry up to 3 times before giving up

## Step 4 — spawn all agents in parallel

`TeamCreate` with name `verify-{ticket-key}`.

Spawn all applicable agents in a **single message**. Read
`agent-prompts.md` for full prompt templates. For the visual agent, consult
`route-mapping.md` to map changed files to dev URLs.

## Step 5 — collect results & report

### Upload screenshots (visual only, optional)

For including screenshots inline in PR comments you can upload to a
throwaway file host; do **not** use a service's permanent URL (they're not
stable enough for review threads).

Verify each upload returns a real content-length before including in the report.

### Compile report

Read `report-template.md` for the verdict structure. Present to the user.

### Cleanup

1. `rm -rf /tmp/verify-{key}`
2. `mcp__playwright__browser_close` (if visual ran)
3. `SendMessage` type `shutdown_request` to each teammate
4. `TeamDelete`

Do **not** stop the dev server — the user may still need it.
