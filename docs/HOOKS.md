# Hooks reference

The toolkit ships seven hooks. Each entry below describes what the hook
does, when it fires, what it blocks or allows, and how to customise it.

| # | Hook                | Lifecycle     | Trigger         |
|---|---------------------|---------------|-----------------|
| 1 | `bash-safety.sh`    | PreToolUse    | Bash            |
| 2 | `write-guard.sh`    | PreToolUse    | Write, Edit     |
| 3 | `auto-format.sh`    | PostToolUse   | Write, Edit     |
| 4 | `bash-triage.sh`    | PostToolUse   | Bash            |
| 5 | `notification.sh`   | Notification  | All events      |
| 6 | `statusline.sh`     | StatusLine    | Continuous      |
| 7 | `pre-compact.sh`    | PreCompact    | Before compaction |

---

## `bash-safety.sh`

**What it does:** intercepts every Bash command before execution and
blocks dangerous git and deployment operations. Stderr is suppressed;
fails open if the hook itself errors.

| Operation                                | Pattern                                                                         | Reason                     |
|------------------------------------------|---------------------------------------------------------------------------------|----------------------------|
| Force-push to protected branches         | `git push --force` targeting `main`/`master`/`develop`/`dev`/`release*`         | Protects shared history    |
| Force-push without explicit branch       | `git push --force` with no branch target                                        | Current branch might be protected |
| `git reset --hard` on protected branch   | On `main`/`master`/`develop`/`dev`/`release*`                                   | Prevents accidental loss   |
| `git add .` with `.env*` files present   | `.env*` found within 3 levels (excluding `.git/`, `node_modules/`)              | Prevents secret leaks      |
| Deleting a protected branch              | `git branch -d` / `-D` on a protected branch                                    | Prevents accidents         |
| Direct production deploys                | `kubectl --context prod`, `helm install prod`, `docker push prod`               | Force CI/CD path           |
| `--no-verify` on commits                 | `git commit --no-verify` (or `-n`)                                              | Don't bypass pre-commit hooks |

### Customisation
- Adjust `PROTECTED_BRANCHES` (pipe-separated regex) to match your workflow
- Add rules by appending `if` blocks that check `$COMMAND` and emit a JSON block decision
- Hook reads JSON tool input from stdin; the command is at `.tool_input.command`

---

## `write-guard.sh`

**What it does:** intercepts Write and Edit before execution and blocks
modifications to sensitive files.

| Category                | Pattern                                                     | Reason |
|-------------------------|-------------------------------------------------------------|--------|
| Env files               | `.env`, `.env.*`                                            | Secrets must be edited manually |
| Keys / certs            | `.keystore`, `.jks`, `.pem`, `.key`, `.p12`, `.pfx`         | Cryptographic material edited manually |
| Credentials             | `credentials.json`, `secrets.yaml/yml`, `service[_-]account.json` | Secrets edited manually |
| Committed migrations    | `/db/migration/*.sql`, `/flyway/*.sql`, `/resources/db/*.sql` **with** existing git history | Migrations are immutable once committed; create a new one |

New, uncommitted migration files are allowed (they have no history yet).

### Customisation
- Add patterns by appending `if` blocks checking `$FILENAME` / `$FILE_PATH`
- Migration paths use `git log --oneline -1` to check commit history — adjust path globs to match your layout

---

## `auto-format.sh`

**What it does:** formats files after Write/Edit, using the right
formatter per extension. Runs silently; skips files that don't exist.

| Extension       | Formatter       | Command                     |
|-----------------|-----------------|-----------------------------|
| `*.dart`        | dart formatter  | `fvm dart format <file>` (or `dart format`) |
| `*.kt`, `*.kts` | ktlint          | `ktlint -F <file>`          |
| `*.go`          | gofmt           | `gofmt -w <file>`           |
| `*.ts`, `*.tsx` | prettier        | `prettier --write <file>`   |
| `*.py`          | ruff            | `ruff format <file>`        |

Each tool is invoked via `command -v` first — if it's not on PATH, the
formatting step is silently skipped (so you can install formatters
incrementally).

### Customisation
- Add an extension by appending a case in the hook and the matching `command -v` check
- Skip a whole project by checking the file path against the registry and returning early

---

## `bash-triage.sh`

**What it does:** inspects Bash output after execution. On non-zero exit
it looks for known failure patterns and injects a diagnostic hint as a
`systemMessage`. No-op on success. Fails open.

| Failure                     | Pattern                                                | Hint                                                  |
|-----------------------------|--------------------------------------------------------|-------------------------------------------------------|
| JDK version mismatch        | `unsupported class file`, `UnsupportedClassVersionError` | Set `JAVA_HOME` to the correct version                |
| Gradle daemon               | `could not connect to daemon`, `daemon stopped`, `OOME` | `./gradlew --stop` and retry                          |
| GPG signing                 | `gpg failed to sign`, `No secret key`                  | Restart gpg-agent; set `GPG_TTY`                      |
| Flutter pub get             | `pubspec.yaml file has changed`, `could not find package` | `fvm flutter pub get`                                 |
| Dart codegen                | `.g.dart does not exist`, `.freezed.dart does not exist`, `build_runner` | `fvm dart run build_runner build --delete-conflicting-outputs` |
| Port in use                 | `EADDRINUSE`, `address already in use`, `bind failed`  | `lsof -i :<port>` to find the claimant                |
| Docker not running          | `Cannot connect to the Docker daemon`                  | Start Docker Desktop                                  |
| FVM issues                  | `fvm: command not found`, `Could not find Flutter SDK` | `fvm install && fvm use`                              |
| Kotlin compilation          | `COMPILATION ERROR`, `Unresolved reference`, `Type mismatch` | Fix errors; run `./gradlew detekt` before committing  |
| Node modules missing        | `Cannot find module`, `ERR_MODULE_NOT_FOUND`           | `pnpm install`                                        |

The hint is delivered to the agent as a system message, not shown to the
user — the agent can self-correct on the next turn.

### Customisation
- Add patterns by appending `if` blocks checking `$OUTPUT` with `grep -qiE` and emitting a JSON `systemMessage`

---

## `notification.sh`

**What it does:** sends a desktop notification on notification events
(typically task completion). Extracts the message from the JSON input
(checks `message`, `title`, `notification`, `content` in order; falls back
to "Task completed"). Truncates to 200 characters.

| Platform  | Method                                  | Sound        |
|-----------|-----------------------------------------|--------------|
| macOS     | `osascript display notification`        | Glass        |
| Linux     | `notify-send`                           | System default |

### Customisation
- Change the title by editing the `"Claude Code"` string
- Change the macOS sound (`Glass` → `Ping`, `Hero`, `Tink`, …)
- Add Windows support with `New-BurntToastNotification`

---

## `statusline.sh`

**What it does:** renders the status bar with project context. Format:
`icon project > branch (TICKET) | Model | context-bar %`. Detects the
current project by matching the working directory against paths from
`~/.claude/project-repos.env`.

Examples:
- `api > feat/API-456-add-refund-endpoint (API-456) | Opus 4.5 | ░░░████ 42%`
- `web > main | Sonnet 4.6 | ░░████ 30%`
- `~ | Opus 4.5 | ░░░░░░░ 5%`

Ticket key extraction uses the regex `[A-Z]+-[0-9]+`.

### Customisation
- Add projects to `repos.conf` and re-run `./install.sh` — the hook picks them up automatically
- Adjust the ticket regex if your keys use a different pattern

---

## `pre-compact.sh`

**What it does:** runs before Claude Code compacts context. Injects a
reminder to flush any newly discovered patterns, gotchas, or conventions
into `knowledge/*.md` *before* they get collapsed into a summary. This
keeps the auto-learning system honest — discoveries don't rot through
compaction.
