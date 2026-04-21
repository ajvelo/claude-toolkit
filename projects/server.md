# demo-server — Python / FastAPI service

Loaded by the claude-toolkit when Claude Code runs inside the `server`
project.

## Stack

- **Framework:** FastAPI (ASGI via uvicorn)
- **Language:** Python 3.12
- **Package manager:** uv (replaces pip/poetry/pyenv)
- **ORM:** SQLAlchemy 2 async
- **Testing:** pytest + pytest-asyncio + httpx
- **Base branch:** `main`
- **Jira prefix:** `SRV-`

## Commands

| Task              | Command                                      |
|-------------------|----------------------------------------------|
| Dev               | `uv run uvicorn app.main:app --reload`       |
| Run tests         | `uv run pytest`                              |
| Coverage          | `uv run pytest --cov=app --cov-report=term`  |
| Lint              | `uv run ruff check .`                        |
| Format            | `uv run ruff format .`                       |
| Typecheck         | `uv run mypy app`                            |
| All checks        | `uv run ruff check . && uv run mypy app && uv run pytest` |

**Run the full check command before every commit.** Mypy is strict-mode.

## Conventions

- Feature layout: `app/{feature}/{router.py,service.py,models.py,schemas.py}`
- `router.py` = FastAPI router + DTO wiring
- `service.py` = business logic (pure functions where possible)
- `models.py` = SQLAlchemy ORM models
- `schemas.py` = Pydantic v2 request/response models
- Tests live in `tests/{feature}/test_{file}.py`
- All DB access goes through async sessions — no sync queries in request paths
- Use `Depends` for auth and session injection; don't pull from global state

## Gotchas

- FastAPI's `Depends` is evaluated per-request; expensive deps should cache
  at app scope with `lru_cache`
- SQLAlchemy 2 async requires `AsyncSession` everywhere — mixing sync and
  async sessions silently deadlocks
- Pydantic v2 renamed `Config` → `model_config` and `validator` → `field_validator`
- `uv` locks happen in `uv.lock` — commit it; don't edit by hand
