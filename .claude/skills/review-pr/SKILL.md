---
name: review-pr
description: Team-based PR review - UX, code quality, and QA agents review in parallel
disable-model-invocation: false
argument-hint: "<owner/repo#number | PR-URL> [--visual]"
---

## PR Review Team

**Input:** $ARGUMENTS

You are the **team lead** for a parallel PR review. You coordinate three specialized reviewers (UX, Code Quality, QA) to produce a comprehensive assessment.

Use the **Project Registry** from the toolkit CLAUDE.md for shortname → path → tech → base branch mapping.

## Process

### Step 1: Parse Input & Fetch PR Context

Parse the input to extract `owner/repo` and PR number. Accept formats:
- `owner/repo#123`
- `https://github.com/owner/repo/pull/123`
- `#123` (infer repo from current git directory)
- `123` (infer repo from current git directory)

Fetch in parallel:
```bash
gh pr view {number} --repo {owner/repo} --json title,body,additions,deletions,changedFiles,files,baseRefName,headRefName,labels,state
gh pr diff {number} --repo {owner/repo}
gh api repos/{owner/repo}/pulls/{number}/files --paginate
```

Extract the Jira ticket key from the PR title/body/branch (pattern: `[A-Z]+-[0-9]+`) and fetch it via MCP if found.

Identify which project from the registry (if any) matches the repo. This determines tech stack conventions.

### Step 2: Create Review Team

Create a team: `TeamCreate` with name `review-{repo-name}-{number}`.

Create 3 tasks:
1. **UX Review** — assigned to `ux-reviewer`
2. **Code Review** — assigned to `code-reviewer`
3. **QA Review** — assigned to `qa-reviewer`

### Step 3: Spawn Reviewers (in parallel)

Spawn all 3 teammates in a **single message** using the `Task` tool:

Each teammate receives:
- The full PR diff
- The file list with stats
- The PR description and test plan
- The Jira ticket context (if found)
- The project path (from registry) so they can search the full codebase
- Tech stack context (Flutter/Kotlin, conventions, patterns)

#### UX Reviewer (`subagent_type: "ux-reviewer"`)
- Focus: consistency across surfaces, user flow, component patterns, accessibility
- Should search codebase for related UI surfaces not in the diff

#### Code Reviewer (`subagent_type: "code-reviewer"`)
- Focus: architecture, conventions, dead code, null safety, data flow
- Should search for usages of deleted/modified code, verify no orphans

#### QA Reviewer (`subagent_type: "qa-reviewer"`)
- Focus: test coverage, edge cases, regression risk, test plan completeness
- **For UI changes:** Must use Playwright to verify the changed UI renders correctly

### Step 4: Visual walkthrough (auto-detected for UI changes)

**Auto-detection:** run the walkthrough if any changed file matches UI
patterns for the project's stack:

| Stack              | UI patterns                                                     |
|--------------------|-----------------------------------------------------------------|
| Flutter (Dart)     | `*_view.dart`, `*_page.dart`, `*_dialog.dart`, `*_modal.dart`, `*_widget.dart`, `*_screen.dart`, `*_sheet.dart` |
| React / Next.js    | `*.tsx` in `components/`, `app/**/page.tsx`, `routes/**`        |

If the PR contains UI changes or `--visual` is set:

#### Local dev setup

Use the project's declared dev command (from `projects/{shortname}.md`):
1. Check the dev server is running at the project's declared port
2. If not: start it in the background (`pnpm dev &`, `fvm flutter run -d chrome &`, …)
3. Wait until the server is reachable (network-idle signal, or a health endpoint)
   - Flutter web with DDC can take up to 45 seconds on a cold boot

#### Screenshots
1. **Set a consistent viewport** (e.g. `1440x900` desktop, `390x844` mobile) via `mcp__playwright__browser_resize`
2. **Prefer in-app navigation** — avoid full page reloads that trigger bundler re-compiles
3. Take **element-level screenshots** when possible (smaller, easier to review)
4. Name: `{step}-{surface}-{state}.jpeg`
5. Save to `/tmp/pr-{number}-screenshots/`

#### Uploading screenshots for inline PR comments

GitHub's REST API does not expose attachment uploads, and `gh` CLI
doesn't support binary attachments. For public-repo PRs you can use a
throwaway file host; for private repos, consider whether the content is
sensitive before uploading. A typical flow:

```bash
curl -sF "reqtype=fileupload" -F "time=72h" -F "fileToUpload=@{path}" \
  https://litterbox.catbox.moe/resources/internals/api.php
```

Verify each upload returns a real content-length before including the URL.

### Step 5: Synthesize & Post Report

Post as a **PR review** via:
```bash
gh api repos/{owner/repo}/pulls/{number}/reviews -f event="COMMENT" -f body="..."
```

**CRITICAL: ALWAYS use `event="COMMENT"`.** NEVER use `APPROVE` or `REQUEST_CHANGES`.

```markdown
# PR Review: [PR Title]

**PR:** [URL]
**Ticket:** [Jira link if found]
**Stats:** +[additions] / -[deletions] across [N] files

## Verdict

| Reviewer | Assessment | Critical | Major | Minor |
|----------|-----------|----------|-------|-------|
| UX | APPROVE/CHANGES/COMMENT | 0 | 0 | 0 |
| Code | APPROVE/CHANGES/COMMENT | 0 | 0 | 0 |
| QA | APPROVE/CHANGES/COMMENT | 0 | 0 | 0 |

**Overall:** [APPROVE | REQUEST_CHANGES | COMMENT]

## Critical & Major Findings

| # | Reviewer | Severity | Issue | File:Line |
|---|----------|----------|-------|-----------|

## Visual Walkthrough
[Screenshots with litterbox URLs]

## Action Items
[Prioritized list of changes needed]
```

### Step 6: Cleanup
1. Shut down teammates via `SendMessage` with `type: "shutdown_request"`
2. `TeamDelete`
3. `rm -rf /tmp/pr-{number}-screenshots`
4. `mcp__playwright__browser_close`
