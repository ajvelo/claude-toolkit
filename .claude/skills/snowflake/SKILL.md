---
name: snowflake
description: Query Snowflake production data for debugging, investigations, and analytics
disable-model-invocation: false
argument-hint: "<query-description or SQL>"
---

## Snowflake Query Runner

**Arguments:** $ARGUMENTS

Query production data in Snowflake for debugging, investigations, and
analytics. Uses the `snowsql` CLI with SSO authentication.

## Connection

Set up a named connection in `~/.snowsql/config` and invoke it by name:

```bash
snowsql -c my_connection -q "{SQL}" --output-format=json
```

The connection name should point at your SSO-authenticated account. The
first query opens a browser for authentication; subsequent queries reuse
the session token.

## Schema reference

Keep a schema map in `knowledge/snowflake-reference.md` (project-owned).
Typical layout:

| Database  | Purpose                                               |
|-----------|-------------------------------------------------------|
| `PROD`    | Raw production data (replicated from services)        |
| `DATA`    | Curated analytics data (dbt-transformed)              |
| `ANALYSIS`| Ad-hoc analysis                                       |

**Always fully qualify:** `DATABASE.SCHEMA.TABLE`.

## Example queries

Replace the table names below with the ones in your schema reference.

### Lookup by ID
```sql
SELECT *
FROM PROD.DOMAIN.ENTITY
WHERE id = {id}
LIMIT 50
```

### Recent activity for an entity
```sql
SELECT id, state, created_at, updated_at
FROM PROD.DOMAIN.ENTITY
WHERE user_id = {user_id}
ORDER BY created_at DESC
LIMIT 20
```

### Cross-table join
```sql
SELECT e.id, e.state, u.email_hash, u.locale
FROM PROD.DOMAIN.ENTITY e
JOIN PROD.DOMAIN.USERS u ON u.id = e.user_id
WHERE e.id = {id}
```

## Process

1. **Parse the request** — determine what data is needed
2. **Check the schema reference** — read `knowledge/snowflake-reference.md` for the correct table/column names
3. **Build the query** — always use fully qualified names, add `LIMIT` to prevent runaway queries
4. **Execute** — run via `snowsql` with JSON output
5. **Present results** — format as a readable table with brief analysis

## Safety rules

- **Read-only** — restrict the Snowflake role to `SELECT`
- **Always add `LIMIT`** — default LIMIT 50, never run unbounded queries
- **No PII in output** — redact email addresses, phone numbers, full names. Show IDs and aggregates only.
- **Qualify all tables** — always `DATABASE.SCHEMA.TABLE`
