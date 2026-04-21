## Ticket prefix → project routing

Match the ticket prefix against the table to infer the default project.
Adjust this table as you add projects to `repos.conf`.

| Prefix   | Default project | Ambiguous?                                        |
|----------|-----------------|---------------------------------------------------|
| `MOB-`   | `mobile`        | No                                                |
| `WEB-`   | `web`           | Sometimes — may also need `api` if the UI consumes a new endpoint |
| `API-`   | `api`           | Sometimes — may also need `server` if a new service call is required |
| `SRV-`   | `server`        | No                                                |
| `INF-`   | `infra`         | No                                                |

**Bug/support prefixes** — add any prefixes your organisation uses for bug
reports (e.g. `BUG-`, `SUPPORT-`). The `start` skill auto-runs
`/investigate` for these before planning implementation.

If the prefix is ambiguous, `start` asks the user with the candidate
projects listed explicitly.
