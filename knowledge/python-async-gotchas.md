# Python async gotchas

Things that bite when working across FastAPI, SQLAlchemy async, pytest-asyncio,
and uvicorn. Each entry lists the symptom, why it happens, and how to
avoid it.

---

## Mixing sync and async SQLAlchemy sessions

**Symptom:** requests hang or deadlock intermittently under load. Tests
pass locally but time out in CI. No obvious error in logs.

**Why:** SQLAlchemy 2's async engine and sync engine use different
connection pools and locking primitives. A sync call inside an async
context holds the GIL and blocks the event loop; an async call from sync
code deadlocks on the loop it doesn't own.

**How to apply:** pick one. If you go async, `AsyncSession` everywhere,
`select(...)` results with `.scalars()`, and never call `session.execute`
from a sync helper. If a background script needs sync access, give it a
separate sync engine rather than reaching into the async one.

---

## `Depends` runs per request, cached only per dependency chain

**Symptom:** an expensive factory (HTTP client, big JSON schema, warm
cache) is being constructed on every request and your p99 is terrible.

**Why:** `fastapi.Depends(factory)` is evaluated once per *request*, not
once per app. Within the same request chain FastAPI deduplicates the same
dependency callable, but across requests each call is fresh.

**How to apply:** for app-scoped singletons, build the object at startup
(`@app.on_event("startup")` or the lifespan context) and stash it on
`app.state`; inject with a dependency that reads from `app.state`. For
expensive-but-idempotent factories, wrap in `functools.lru_cache()`.

---

## `asyncio.gather` swallows results when one task raises

**Symptom:** one of five parallel tasks fails, the other four completed
successfully, but you can't access their results.

**Why:** `gather(..., return_exceptions=False)` (the default) re-raises
the first exception and drops the whole result tuple on the floor.

**How to apply:** use `return_exceptions=True` and filter afterwards:

```python
results = await asyncio.gather(*tasks, return_exceptions=True)
ok = [r for r in results if not isinstance(r, Exception)]
errs = [r for r in results if isinstance(r, Exception)]
```

Or, on Python 3.11+, prefer `asyncio.TaskGroup` which gives you structured
concurrency and collects failures into an `ExceptionGroup`.

---

## Fire-and-forget tasks get garbage-collected

**Symptom:** you `asyncio.create_task(background_work())` and the work
silently stops halfway through. No error.

**Why:** asyncio only keeps a weak reference to tasks. If no strong
reference is held, the garbage collector can reap the task at any point.

**How to apply:** keep a reference:

```python
_bg_tasks: set[asyncio.Task] = set()

def fire_and_forget(coro):
    task = asyncio.create_task(coro)
    _bg_tasks.add(task)
    task.add_done_callback(_bg_tasks.discard)
    return task
```

Or use a `TaskGroup` and `await` it at a scope boundary.

---

## `CancelledError` is an exception, not a signal

**Symptom:** a cleanup handler swallows all exceptions with
`except Exception`, and task cancellation stops propagating. The task
continues doing work after the caller gave up.

**Why:** `asyncio.CancelledError` inherits from `BaseException`, not
`Exception`. That's deliberate. Catching `Exception` is almost always
what you want; catching `BaseException` is almost never what you want.

**How to apply:** if you must intercept cancellation (e.g. to run
cleanup), re-raise it:

```python
try:
    await long_running_call()
except asyncio.CancelledError:
    await cleanup()
    raise
except Exception:
    await error_path()
```

---

## pytest-asyncio event loop scope

**Symptom:** `RuntimeError: Task got Future attached to a different loop`
when a fixture creates an async resource used across several tests.

**Why:** pytest-asyncio creates a fresh event loop per test by default.
An async fixture with `scope="module"` that creates a connection pool
under loop A is used by tests running under loop B.

**How to apply:** either make the fixture `scope="function"`, or pin the
event loop with `asyncio_default_fixture_loop_scope = "module"` in
`pyproject.toml`'s pytest config, and ensure every fixture that holds
async state uses the same scope.

---

## uvicorn workers don't share state

**Symptom:** rate-limit counters or connection pools appear to reset
randomly. Works perfectly with `--workers 1`, breaks with `--workers 4`.

**Why:** each uvicorn worker is a separate process with its own memory.
In-process state is per-worker.

**How to apply:** for anything that must be shared across workers
(rate limits, distributed locks, session state), move to a shared store
(Redis, a database). For worker-local caching, measure before optimising;
it often doesn't need to be shared.

---

## `run_in_executor` with default executor blocks under load

**Symptom:** under sustained load, async handlers start timing out.
Profiling shows most time in executor-scheduled sync work.

**Why:** the default ThreadPoolExecutor is sized at `min(32, os.cpu_count() + 4)`.
Every `loop.run_in_executor(None, ...)` call shares that pool. One slow
blocking call can starve the rest.

**How to apply:** create a dedicated executor for known blocking work
(disk IO, legacy sync HTTP clients) and pass it explicitly:

```python
io_pool = ThreadPoolExecutor(max_workers=8, thread_name_prefix="io")
await loop.run_in_executor(io_pool, blocking_fn, arg)
```

---

## `aiohttp`/`httpx` client sessions need to outlive requests

**Symptom:** `ClientSession() not closed` warnings in logs; occasional
connection resets at high concurrency.

**Why:** creating a new session per request forfeits connection pooling
and pays TLS handshake overhead every time. Closing the session while a
response is still being streamed drops the connection mid-flight.

**How to apply:** create one client at startup (lifespan event) and
share it via `app.state`. Close it on shutdown. Async context managers
(`async with httpx.AsyncClient() as client`) are fine for scripts but
wrong for long-running services.
