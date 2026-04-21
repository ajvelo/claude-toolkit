---
name: explore-repo
description: Discover and onboard any repository — tech stack, structure, build system, entry points
argument-hint: "<repo-name or owner/repo>"
---

## Repository Explorer

**Arguments:** $ARGUMENTS

Explore any repository (remote or local) and produce a structured onboarding
summary so the next task in that repo starts informed.

## Process

### Step 1: identify the repo
Accept:
- `<owner>/<repo>`
- Bare `<repo-name>` (resolves against `$GITHUB_OWNER` env var if set, else asks)
- `https://github.com/<owner>/<repo>`

### Step 2: gather metadata
```bash
gh repo view <owner>/<repo> --json name,description,defaultBranchRef,languages,updatedAt,isArchived
```

### Step 3: detect tech stack
Read build manifests from the default branch:

| File                            | Stack                | Build tool        |
|---------------------------------|----------------------|-------------------|
| `build.gradle.kts` / `build.gradle` | Kotlin / Java / JVM  | Gradle            |
| `pom.xml`                       | Java / JVM           | Maven             |
| `pubspec.yaml`                  | Flutter / Dart       | FVM + Flutter     |
| `package.json`                  | Node / TypeScript    | pnpm / npm / yarn |
| `pyproject.toml` / `requirements.txt` | Python         | uv / pip          |
| `go.mod`                        | Go                   | `go build`        |
| `Cargo.toml`                    | Rust                 | `cargo`           |
| `composer.json`                 | PHP                  | Composer          |
| `main.tf` / `*.tf`              | Terraform            | `terraform`       |
| `Dockerfile`                    | Containerised        | Docker            |

Use `gh api repos/{owner}/{repo}/contents/{path}` (or `mcp__github__get_file_contents` if configured) to read files remotely.

### Step 4: explore structure
- `README.md` — project overview
- `Makefile` / `Taskfile.yml` / `justfile` — available commands
- `.github/workflows/` — CI/CD
- `src/` / `lib/` / `app/` / `pkg/` — main source
- `test/` / `tests/` / `__tests__/` — tests

### Step 5: identify entry points

| Stack             | Common entry points                                       |
|-------------------|-----------------------------------------------------------|
| Kotlin            | `Application.kt`, framework-specific application class    |
| Flutter           | `main.dart`, router configuration                         |
| Node/TypeScript   | `index.ts`, route definitions, `app/` for Next.js         |
| Python            | `main.py`, `app/__init__.py`, `wsgi.py`/`asgi.py`         |
| Go                | `main.go`, handler registrations                          |
| PHP               | `public/index.php`, `routes/`, `app/Http/Controllers/`    |
| Terraform         | `main.tf`, `envs/{env}/main.tf`                           |

### Step 6: dependencies
- Check the build manifest for notable deps (framework, DB client, HTTP client, messaging)
- Look for cross-service references: HTTP client configs, message broker topics, shared libraries

## Output

### Repository Summary: {repo-name}

**Description:** [from GitHub]
**Tech Stack:** [detected]
**Build Tool:** [detected]
**Default Branch:** [branch name]
**Last Updated:** [date]
**Archived:** [yes/no]

### Directory Structure
```
[top-level tree]
```

### Key Entry Points
| File  | Purpose     |
|-------|-------------|
| [path] | [description] |

### Build & Test
```bash
# Build
[detected build command]

# Test
[detected test command]

# Run locally
[detected run command]
```

### Notable Dependencies / Connections
| Purpose         | Dep / service | Reference              |
|-----------------|---------------|------------------------|
| [DB, HTTP, ...] | [name]        | [file:line]            |

### CI/CD
[Summary of GitHub Actions workflows or other CI configs]

### Quick Start
1. `gh repo clone <owner>/<repo> ~/code/<repo>` (or wherever you keep repos)
2. Add an entry to `repos.conf` and re-run `./install.sh` to register the path
3. [Stack-specific setup steps]
4. [How to run]
