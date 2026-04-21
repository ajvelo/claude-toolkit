# Postgres query patterns

Things that bite in application-code Postgres usage, independent of which
ORM or driver you use. Focus is on correctness and hot-path performance.

---

## `SELECT *` breaks migrations silently

**Symptom:** adding a column to a table causes a previously-green app to
start serialising unexpected fields, or an ORM to pull huge TOAST values
into memory.

**Why:** `SELECT *` binds the query to the table's *current* shape. A
migration that adds a `large_text` column instantly gets pulled into
every row-read, whether the app needs it or not.

**How to apply:** name columns explicitly in application code. Keep
`SELECT *` for ad-hoc psql sessions, never application queries. If the
ORM offers a projection mechanism (SQLAlchemy `load_only`, Exposed
`slice`, Ecto `select`), use it.

---

## Counting with `COUNT(*)` vs `COUNT(column)`

**Symptom:** the counts in your dashboard don't match expectations.

**Why:** `COUNT(*)` counts rows. `COUNT(column)` counts rows where
`column` is non-NULL. These can differ by a lot.

**How to apply:** use `COUNT(*)` for "how many rows." Use `COUNT(column)`
only when you deliberately want to exclude NULLs. For fast approximate
row counts on huge tables, use `pg_class.reltuples` (last ANALYZE
estimate) rather than a real count.

```sql
-- Exact, slow on big tables
SELECT COUNT(*) FROM orders;

-- Approximate, instant
SELECT reltuples::bigint AS approx_rows
FROM pg_class WHERE relname = 'orders';
```

---

## `IN (subquery)` vs `IN (list)` plan differently

**Symptom:** your query planner picks a hash join for a list but a nested
loop for a subquery, or vice versa, with a 10x latency difference.

**Why:** Postgres rewrites `IN (subquery)` as a semi-join, but the plan
depends heavily on the subquery's estimated row count. A large list is
treated as a value array.

**How to apply:** for small, known lists (< ~100), pass an array from
application code rather than subquery. For large sets, use `EXISTS`
instead of `IN` with a subquery:

```sql
-- Often faster for large correlated subqueries
SELECT * FROM orders o
WHERE EXISTS (SELECT 1 FROM users u WHERE u.id = o.user_id AND u.active);
```

`EXISTS` stops at the first match; `IN` may materialise the full list.

---

## `ORDER BY` + `LIMIT` without an index is a seq-scan

**Symptom:** a seemingly trivial "latest 10" query takes 2s.

**Why:** without an index on the order-by column, Postgres seq-scans the
table and sorts. `LIMIT` doesn't help the scan.

**How to apply:** every `ORDER BY ... LIMIT` on a large table needs an
index covering the order-by columns. For `ORDER BY created_at DESC
LIMIT 10`, a plain `CREATE INDEX ON orders (created_at DESC)` works;
Postgres can scan it backwards otherwise.

---

## `JOIN` on nullable foreign keys

**Symptom:** your report shows surprising row counts when users with no
orders should still appear.

**Why:** an inner `JOIN` drops rows without a match. If `orders.user_id`
is nullable and you want orphan orders included, you need a `LEFT JOIN`
from `orders`. If you want users with zero orders, you need a `LEFT JOIN`
from `users`.

**How to apply:** explicitly decide which side owns "include all rows"
and start the query from that table. Double-check after migrations that
change FK nullability.

---

## `DISTINCT` is expensive; `DISTINCT ON` is more expensive

**Symptom:** a query using `DISTINCT` or `DISTINCT ON` shows up at the
top of `pg_stat_statements`.

**Why:** both require a sort or hash of the full result set. `DISTINCT
ON (col)` needs the rows ordered by `col` first.

**How to apply:** first, ask whether `GROUP BY` with aggregates
(e.g. `MAX(created_at)`) gives you the same answer more cheaply. If you
genuinely need "the latest row per group," `DISTINCT ON` with a matching
index on `(group_col, order_col DESC)` is usually the fastest path:

```sql
CREATE INDEX ON orders (user_id, created_at DESC);

SELECT DISTINCT ON (user_id) user_id, created_at, total
FROM orders
ORDER BY user_id, created_at DESC;
```

---

## JSONB operators and indexes

**Symptom:** a JSONB query works but is slow; adding a GIN index doesn't
speed it up.

**Why:** GIN indexes on JSONB support `@>`, `?`, `?&`, `?|`, and the
`jsonb_path_ops` operator class for `@>` only. If you query with `->`
followed by a comparison, the index doesn't help.

**How to apply:** reshape the query to use `@>`:

```sql
-- Slow (can't use the GIN index)
SELECT * FROM events WHERE payload->>'type' = 'click';

-- Fast (uses jsonb_path_ops GIN index)
CREATE INDEX events_payload_gin ON events USING gin (payload jsonb_path_ops);
SELECT * FROM events WHERE payload @> '{"type": "click"}';
```

Or create a computed-column index on `(payload->>'type')` if you can't
change the query.

---

## `UPDATE` without `WHERE` is a career-limiting event

**Symptom:** you update every row in a table by accident.

**Why:** Postgres has no "safe mode" for interactive updates. `UPDATE
users SET email = 'foo'` runs happily.

**How to apply:** in psql, `\set ON_ERROR_STOP on` and get used to
wrapping destructive work in explicit `BEGIN; ... ROLLBACK;` to verify
the `UPDATE`'s row count before committing. In application code, never
construct an `UPDATE` without a `WHERE` clause unless you're explicitly
doing a full-table update (migrations only).

Most production ORMs have a safety check for full-table updates; leave
it on.

---

## `SERIAL` / `BIGSERIAL` vs identity columns

**Symptom:** sequences get out of sync after a `pg_restore`, and INSERTs
fail with "duplicate key value violates unique constraint."

**Why:** `SERIAL` creates a sequence owned by the column. `pg_restore`
may load data without advancing the sequence, leaving the sequence
pointing below the max existing value.

**How to apply:** use `GENERATED ALWAYS AS IDENTITY` (Postgres 10+)
instead of `SERIAL`. It's cleaner, handles restores correctly, and
prevents callers from overriding the value (which is usually what you
want). After restoring into a `SERIAL` column:

```sql
SELECT setval('table_id_seq', (SELECT MAX(id) FROM table));
```

---

## `NOT IN` and NULLs

**Symptom:** `WHERE x NOT IN (subquery)` returns zero rows when the
subquery contains a NULL.

**Why:** SQL's three-valued logic: `x NOT IN (1, NULL)` evaluates as
`x <> 1 AND x <> NULL`, and `x <> NULL` is `UNKNOWN`, which makes the
whole condition `UNKNOWN`, which filters out the row.

**How to apply:** use `NOT EXISTS` instead. It handles NULLs sanely and
is usually faster anyway.

```sql
-- Broken if any user.id is NULL
SELECT * FROM orders WHERE user_id NOT IN (SELECT id FROM users WHERE active);

-- Correct and typically faster
SELECT * FROM orders o
WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.id = o.user_id AND u.active);
```

---

## `EXPLAIN (ANALYZE, BUFFERS)` is the diagnostic

**Symptom:** you're guessing about why a query is slow.

**Why:** plain `EXPLAIN` shows the planner's estimate. `EXPLAIN ANALYZE`
runs the query and shows actual times. `BUFFERS` shows how many pages
were read from shared buffers vs disk.

**How to apply:** when in doubt, run:

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE) <your query>;
```

Key things to look for:
- **Rows Removed by Filter** — a filter that throws away most rows is a
  candidate for an index.
- **Buffers: shared read** — pages came from disk. If large, cache isn't
  helping; check `shared_buffers` sizing or the query's locality.
- **Actual time >> estimated time** — planner stats are stale; run
  `ANALYZE <table>` and retry.
