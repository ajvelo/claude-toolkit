# Troubleshooting

Common issues when using the toolkit and how to fix them.

---

## Hooks not firing

**Symptom:** Auto-format or bash-safety don't trigger.

1. Check hooks are installed:
   ```bash
   ls -la ~/.claude/hooks/
   ```
   You should see symlinks pointing at `~/claude-toolkit/hooks/*.sh`.

2. Check they're in `~/.claude/settings.json`:
   ```bash
   jq '.hooks' ~/.claude/settings.json
   ```

3. Re-run the installer if either is missing:
   ```bash
   cd ~/claude-toolkit && ./install.sh
   ```

---

## Auto-format isn't formatting a file

**Symptom:** You edit a file and the formatter doesn't touch it.

The formatter only runs for file extensions it recognises. For each language
the hook calls out to the standard tool:

| File                       | Formatter                         |
|----------------------------|-----------------------------------|
| `*.dart`                   | `fvm dart format` / `dart format` |
| `*.kt` / `*.kts`           | `ktlintFormat`                    |
| `*.go`                     | `gofmt`                           |
| `*.ts` / `*.tsx`           | `prettier`                        |
| `*.py`                     | `ruff format`                     |

If the formatter isn't installed locally, the hook silently skips it — run
the formatter manually once to confirm it's on PATH.

---

## `/verify` can't find the dev server

**Symptom:** `visual-health` agent fails with `APP_DOWN`.

1. The dev server must be running on the port declared in `projects/{shortname}.md`
2. For Flutter web on slow cold-starts, give it ~45s after boot before navigating
3. Check the project's dev command manually:
   ```bash
   cd {repo-path} && <dev-command>   # e.g. pnpm dev, fvm flutter run -d chrome
   ```

---

## Toolkit can't find a repo

**Symptom:** Skills complain about an unresolved shortname.

1. Check `repos.conf` has an entry for that shortname
2. Re-run the installer to refresh discovery:
   ```bash
   cd ~/claude-toolkit && ./install.sh
   ```
3. Inspect what was discovered:
   ```bash
   cat ~/.claude/project-repos.json | jq '.repos'
   ```
4. If the repo is in an unusual location, add an override to
   `~/.claude/project-repos.local.env`:
   ```
   PROJECT_REPO_API=/custom/path/to/api
   ```

---

## Validation command fails

Run each stage independently to see which specific step is failing:

### Flutter
```bash
cd {repo-path}
fvm flutter analyze     # lint
fvm flutter test        # unit tests
```

### TypeScript / Next.js
```bash
cd {repo-path}
pnpm format             # formatter
pnpm lint               # linter
pnpm typecheck          # tsc
pnpm test               # vitest / jest
```

### Kotlin
```bash
cd {repo-path}
./gradlew detekt        # linter
./gradlew test          # tests
./gradlew ktlintCheck   # formatter
```

### Python
```bash
cd {repo-path}
uv run ruff check .
uv run mypy app
uv run pytest
```

---

## GPG signing

If commits fail with GPG errors:

```bash
gpgconf --kill gpg-agent
gpg-agent --daemon
export GPG_TTY=$(tty)
```

To disable signing for a single repo:

```bash
git config commit.gpgsign false
```

---

## Port conflicts

Common development ports. If something is already using a port, either
stop the other process or change the dev server's port in your project:

| Port | Typical use                              |
|------|------------------------------------------|
| 3000 | Next.js / React dev servers              |
| 3005 | Alt Next.js / Vite dev port              |
| 5173 | Vite default                             |
| 5432 | PostgreSQL                               |
| 6379 | Redis                                    |
| 8000 | FastAPI / Django dev                     |
| 8080 | Flutter web dev, generic backend         |

---

## Fresh reinstall

```bash
rm -rf ~/.claude/hooks/
rm -f ~/.claude/project-repos.env ~/.claude/project-repos.json
cd ~/claude-toolkit && ./install.sh
```

This re-symlinks hooks, re-discovers repo paths, and re-merges settings.
