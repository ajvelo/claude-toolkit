---
name: pr
description: Combined PR workflow — commit, create draft PR, review comments, fix, check CI
disable-model-invocation: false
argument-hint: "[project-path or shortname] [action: create|review|fix|ci] [--watch]"
---

## PR Workflow

**Arguments:** $ARGUMENTS

Use the **project registry** in the toolkit `CLAUDE.md` for shortname →
path → base branch mapping.

## Step 1 — detect context

1. If a project shortname or path is provided, `cd` there
2. Otherwise detect from the current git repo (`git rev-parse --show-toplevel`)
3. Determine the base branch from the registry
4. `git branch --show-current`
5. Extract the ticket key from the branch name (regex `[A-Z]+-[0-9]+`)
6. Determine the GitHub repo (from remote URL)

## Step 2 — gather state

```bash
git -C {path} status
git -C {path} log {base-branch}..HEAD --oneline
git -C {path} diff {base-branch}...HEAD --stat
git -C {path} log @{u}..HEAD --oneline 2>/dev/null   # unpushed commits
```

## Step 3 — action

### `create` (default)

1. **Check the diff against the base branch** — `git -C {path} diff {base-branch}...HEAD` — review ALL changes that will be in the PR. Flag any unrelated files (formatting-only noise, generated code drift, accidentally committed files).
2. If the working tree has uncommitted changes, ask the user to confirm staging and committing.
3. Push the branch: `git -C {path} push -u origin HEAD`
4. Create a DRAFT PR:
   - Title format: `type: description (TICKET-KEY)` — max 90 characters (CI may enforce this)
   - Extract `type` from branch prefix (`feat/`, `fix/`, `chore/`, ...)
   - Base branch from the project registry
   - Always use `--draft`
5. Return the PR URL.

### `review`
1. Check for existing PR: `gh pr view --json url,title,state,reviews,comments`
2. Show review comments and requested changes
3. Summarise what reviewers want fixed

### `fix`
1. Read review comments from the PR
2. Implement requested changes
3. Show diff of fixes for user confirmation before committing

### `ci`
1. Check GitHub Actions runs:
   ```bash
   gh run list --branch {branch} --repo {owner/repo} --limit 5
   ```
2. If a specific run is failing:
   ```bash
   gh run view {run-id} --repo {owner/repo}
   gh run view {run-id} --repo {owner/repo} --log-failed
   ```
3. Check PR checks (if PR exists):
   ```bash
   gh pr checks {pr-number} --repo {owner/repo}
   ```
4. Report in this format:
   ```markdown
   ## CI Status: {branch}

   **Repo:** {owner/repo}
   **Branch:** {branch}
   **PR:** #{number} (if exists)

   | Workflow | Status | Duration | Link |
   |----------|--------|----------|------|
   | {name} | pass/fail/running | {time} | {url} |

   ### Failures (if any)
   {Failed step name + last 50 lines of the failing step}

   ### Suggested Fix
   {If the failure pattern is recognisable — lint, test, build — suggest a fix command}
   ```
5. **Watch mode** (`--watch`): if CI is still running, re-check every 30 seconds until all checks complete or 10 minutes elapse.

## PR body format

```markdown
- **Ticket**: [TICKET-123](https://$JIRA_HOST/browse/TICKET-123)

## What?
- [2-4 concise bullets — no file lists]

## Why?
- [1-2 sentences]
```

`$JIRA_HOST` is the Atlassian host configured in `docs/MCP-SETUP.md`.

## Important

- ALWAYS create DRAFT PRs (never ready PRs) unless explicitly asked
- ALWAYS confirm before `git add`, `git commit`, `git push`
- ALWAYS check diff against the base branch before creating — catch unrelated changes
- Base branch varies by project — always resolve from the registry
- Some CIs enforce a 90-character title limit — keep titles short
