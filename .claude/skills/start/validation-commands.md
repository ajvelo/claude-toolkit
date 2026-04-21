## Validation commands reference

The per-project validate command used by `/start`, `/verify`, and `/pr ci`.
Keep in sync with `projects/{shortname}.md`.

| Shortname  | Validate command                                      | Stack tool version                              |
|------------|-------------------------------------------------------|-------------------------------------------------|
| `mobile`   | `fvm flutter analyze && fvm flutter test`             | FVM / Flutter (see `.fvmrc`)                    |
| `web`      | `pnpm run check && pnpm test`                         | pnpm + Node (see `.nvmrc`)                      |
| `api`      | `./gradlew check` (tests + detekt + ktlint)           | JDK 21 (set `JAVA_HOME`)                        |
| `server`   | `uv run ruff check . && uv run mypy app && uv run pytest` | Python 3.12 + uv                                |
| `infra`    | `terraform fmt -check -recursive && helm lint charts/*` | Terraform 1.7+                                  |

Set JDK before Kotlin commands:
```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
```

### Notes

- All commands must succeed before creating a PR — CI replicates these.
- Some projects treat warnings as failures (Flutter `info`-level
  diagnostics, Kotlin detekt). Fix the lot — don't leave trails for CI.
- If a project needs an extra step (e.g. `make br` for codegen), document
  it in `projects/{shortname}.md` and the skill will pick it up.
