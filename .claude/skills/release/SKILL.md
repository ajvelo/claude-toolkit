---
name: release
description: Create a release tag for a project
disable-model-invocation: false
argument-hint: "<shortname> [module] [version]"
---

## Release tagging

**Arguments:** $ARGUMENTS

Creates a semantic-version tag for a project, with a changelog preview
before tagging. Does **not** push — you review and push manually.

## Supported layouts

Resolve the project path from `~/.claude/project-repos.json`. The skill
handles two common layouts:

| Layout                 | Tag format                      | Example               |
|------------------------|---------------------------------|-----------------------|
| Single-artifact repo   | `v{major}.{minor}.{patch}`      | `v1.2.3`              |
| Multi-module repo      | `{module}/v{major}.{minor}.{patch}` | `api-v1.2.3`      |

For multi-module projects, specify the module as the second argument.

## Process

### Step 1 — context

1. Parse project shortname, optional module, optional version from arguments
2. `cd` to the project path
3. Verify base branch is clean and up to date:

```bash
git fetch origin main
git status
```

Abort if the working tree is dirty or not on the base branch.

### Step 2 — version

If a version wasn't provided:

1. Find the latest relevant tag:
```bash
git tag --list --sort=-version:refname | head -10
```

For multi-module repos, filter by prefix:
```bash
git tag --list "{module}/*" --sort=-version:refname | head -10
```

2. Show commits since last tag:
```bash
git log {last-tag}..HEAD --oneline
```

3. Ask the user for the next version using `AskUserQuestion` (patch / minor
   / major / custom).

### Step 3 — confirm

Show:
- Commits that will be included
- Proposed tag
- Module (if any)

Ask the user to confirm before creating the tag.

### Step 4 — create (but do not push)

```bash
git tag -a {version} -m "Release {version}"
```

Then print, for the user to run manually:

```
Tag created: {version}
To push:
  git push origin {version}
```

## Safety rules

- **Never** push tags automatically — always hand off to the user
- **Never** run on a dirty working tree
- **Never** run off the base branch
- Show the changelog before tagging — no silent tags
