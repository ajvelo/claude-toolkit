---
name: kt
description: Build, test, analyze, or start Docker for a Kotlin project
disable-model-invocation: false
argument-hint: "<build|test|analyze|docker> <shortname> [module] [--tests filter]"
---

## Kotlin build / test / analyze / docker

**Arguments:** $ARGUMENTS

## Project paths & JDK

Resolve project paths from `~/.claude/project-repos.json`. A Kotlin project
is any registry entry whose root contains `build.gradle` or `build.gradle.kts`.

JDK version is per-project and should be declared in the project's
`projects/{shortname}.md`. Set it before invoking Gradle:

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v {version})
```

## Actions

### `build`

```bash
cd {repo-path} && ./gradlew build -x test
# Multi-module projects:
cd {repo-path} && ./gradlew :{module}:build -x test
```

On failure, suggest `./gradlew --refresh-dependencies` for dependency
errors. For compilation errors, quote the file/line and the offending type.

### `test`

```bash
# All tests:
cd {repo-path} && ./gradlew test

# A specific module:
cd {repo-path} && ./gradlew :{module}:test

# A filter (uses JUnit's `--tests`):
cd {repo-path} && ./gradlew test --tests "{filter}"

# Module + filter:
cd {repo-path} && ./gradlew :{module}:test --tests "{filter}"
```

If the project uses TestContainers, ensure Docker is running first.

Report: total / passed / failed / skipped. For failures, show class,
method, assertion error, and the first few lines of stack trace.

### `analyze`

Detekt (common):
```bash
cd {repo-path} && ./gradlew detekt
cd {repo-path} && ./gradlew :{module}:detekt
cd {repo-path} && ./gradlew detekt --auto-correct
```

ktlint (alternative):
```bash
cd {repo-path} && ./gradlew ktlintCheck
cd {repo-path} && ./gradlew ktlintFormat
```

Report issues with: rule name, file:line, message, severity.

### `docker`

Starts the project's `docker-compose.yml` services (Postgres, Redis, any
stub/mock servers):

```bash
# All services:
cd {repo-path} && docker compose up -d

# Specific service:
cd {repo-path} && docker compose up -d {service}
```

After start, wait ~5s and check health:
```bash
docker compose -f {repo-path}/docker-compose.yml ps
```

If any container is unhealthy:
```bash
docker compose logs --tail=20 {service}
```

Common fixes:
- Port conflict: `docker ps` to find the claimant
- Stale volumes: `docker compose down -v && docker compose up -d`

## Process

1. Parse arguments: action, shortname, optional module/filter/flags
2. Set JDK (skip for `docker`)
3. `cd` to the resolved project path
4. Run the command
5. Report result
