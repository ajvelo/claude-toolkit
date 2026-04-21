---
name: server
description: Test, analyze, or start Docker for the server project
disable-model-invocation: false
argument-hint: "<test|analyze|docker> [test-path or filter]"
---

## Server

**Arguments:** $ARGUMENTS

**Path:** resolve from `~/.claude/project-repos.json` using shortname
`server`. The example registry ships a Python / FastAPI project; adjust the
commands below if your `server` shortname points at a different stack.

All commands assume `uv` is installed. If the project uses a different
runner (poetry, pip, docker compose exec), update `projects/server.md` and
this file together.

## Actions

### `test`

```bash
# All tests:
cd {server-path} && uv run pytest

# Specific file:
cd {server-path} && uv run pytest tests/{path}.py

# Filter (substring match on test id):
cd {server-path} && uv run pytest -k "{filter}"

# With coverage:
cd {server-path} && uv run pytest --cov=app --cov-report=term
```

### `analyze`

Ruff + mypy:
```bash
cd {server-path} && uv run ruff check .
cd {server-path} && uv run ruff format --check .
cd {server-path} && uv run mypy app
```

Fix with:
```bash
cd {server-path} && uv run ruff check --fix .
cd {server-path} && uv run ruff format .
```

### `docker`

If the project ships a `docker-compose.yml` for local dev (Postgres, Redis,
LocalStack, etc.):

```bash
cd {server-path} && docker compose up -d
```

Migrations (example with Alembic):
```bash
cd {server-path} && uv run alembic upgrade head
```

## Process

1. Parse arguments: action (`test` / `analyze` / `docker`), optional test filter
2. If `docker` action and containers aren't running, start them first
3. Run the command
4. Report result (summary of passed/failed, or first analyzer errors)
