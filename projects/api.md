# demo-api — Kotlin / Ktor API

Loaded by the claude-toolkit when Claude Code runs inside the `api` project.

## Stack

- **Framework:** Ktor
- **Language:** Kotlin (JVM 21)
- **Build:** Gradle (Kotlin DSL)
- **DI:** Koin
- **Database:** PostgreSQL via Exposed ORM
- **Testing:** Kotest + MockK + TestContainers
- **Base branch:** `main`
- **Jira prefix:** `API-`

## Commands

| Task            | Command                              |
|-----------------|--------------------------------------|
| Run             | `./gradlew run`                      |
| Build           | `./gradlew build`                    |
| Unit tests      | `./gradlew test`                     |
| Integration     | `./gradlew integrationTest`          |
| Lint (detekt)   | `./gradlew detekt`                   |
| Format          | `./gradlew ktlintFormat`             |
| All checks      | `./gradlew check`                    |

**Run `./gradlew check` before every commit.** It wraps tests + detekt +
ktlint. Keep detekt clean — CI treats warnings as failures.

## Conventions

- Package layout: `com.example.api.{feature}.{api|domain|data}`
- Request/response DTOs live in `api/dto/`; domain models in `domain/`
- Ktor routes registered in `plugins/Routing.kt`; per-feature routing in
  `{feature}/api/{Feature}Routes.kt`
- Every public route has a corresponding integration test with a real
  Postgres container
- `BigDecimal` for all money — never `Double` or `Float`
- Use `suspend` functions inside routes; don't block the event loop

## Gotchas

- Exposed ORM's `transaction {}` block is synchronous — wrap in
  `newSuspendedTransaction` for use inside suspending code
- TestContainers start-up adds ~5s per test class; prefer shared fixtures
- `Application.configure*()` plugin functions run in order — DB and Koin
  must be wired before routing
