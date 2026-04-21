# Agents reference

The toolkit ships 12 specialist sub-agents. Each entry below describes
when the agent is triggered, what tools it uses, which model it runs on,
and example scenarios.

| # | Agent                     | Colour | Memory scope |
|---|---------------------------|--------|--------------|
| 1 | `kotlin-debugger`         | red    | user         |
| 2 | `kotlin-test-writer`      | green  | user         |
| 3 | `api-debugger`            | orange | user         |
| 4 | `portal-debugger`         | blue   | project      |
| 5 | `flutter-mobile-debugger` | cyan   | user         |
| 6 | `e2e-debugger`            | green  | user         |
| 7 | `database-specialist`     | yellow | user         |
| 8 | `kafka-debugger`          | orange | user         |
| 9 | `php-debugger`            | red    | user         |
|10 | `code-reviewer`           | orange | user         |
|11 | `qa-reviewer`             | green  | user         |
|12 | `ux-reviewer`             | purple | user         |

All agents run on Opus by default.

---

## `kotlin-debugger`

**When it triggers:** Kotlin debugging tasks involving stack traces, DI
bean injection failures, ORM issues (Exposed / JPA), state-machine errors,
`BigDecimal` arithmetic problems, coroutine scope/cancellation issues.

**Tools:** Read, Grep, Glob, Bash, Sentry MCP, context7 MCP.

**Debugging process:**
1. Classify the error type from the stack trace or description
2. Locate the source file and line in the relevant project
3. Analyse surrounding code, recent git changes, related tests
4. Diagnose root cause with a specific explanation
5. Provide concrete code changes

---

## `kotlin-test-writer`

**When it triggers:** writing Kotlin tests. Covers Kotest 5, MockK,
TestContainers, Strikt, Konsist.

**Tools:** Read, Write, Grep, Glob, Bash.

**Writing process:**
1. Read the code under test
2. Discover existing test patterns in the project
3. Plan test cases: happy path, edge cases, error conditions
4. Write tests following the project's conventions
5. Verify with `./gradlew test --tests "ClassName"`

---

## `api-debugger`

**When it triggers:** API gateway debugging — HTTP 4xx/5xx, auth failures
(session, CSRF, cookies), routing/parameter binding, mock servers,
caching, DTO mapping, downstream service connectivity.

**Tools:** Read, Grep, Glob, Bash.

**Process:**
1. Understand the failing request
2. Locate the handler for the route
3. Trace handler → service → client / repository
4. Identify where the error originates
5. Provide specific code changes

---

## `portal-debugger`

**When it triggers:** Flutter web app debugging — ViewModel state,
`auto_route` navigation, `get_it` DI, proxy/session, web-specific issues,
build system (FVM, `build_runner`).

**Memory scope:** `project` — this agent's learned context is scoped to a
specific project rather than shared across sessions.

**Tools:** Read, Grep, Glob, Bash.

---

## `flutter-mobile-debugger`

**When it triggers:** Flutter mobile app debugging — crashes, navigation
(`go_router`), state management, platform channels, connectivity,
lifecycle issues.

**Tools:** Read, Grep, Glob, Bash.

---

## `e2e-debugger`

**When it triggers:** Playwright E2E test failures — selectors, timeouts,
auth flows, cross-browser issues, flaky tests.

**Tools:** Read, Grep, Glob, Bash.

---

## `database-specialist`

**When it triggers:** database debugging — schema, migrations, query
optimisation, analytics databases, data consistency across services.

**Tools:** Read, Grep, Glob, Bash, Snowflake (via `snowsql`).

---

## `kafka-debugger`

**When it triggers:** Kafka / event-driven debugging — consumer lag,
deserialisation, topic routing, dead-letter queues, ordering guarantees,
async workflow issues.

**Tools:** Read, Grep, Glob, Bash.

---

## `php-debugger`

**When it triggers:** PHP / Laravel debugging — Eloquent ORM, middleware,
service container, queue jobs, validation, routing.

**Tools:** Read, Grep, Glob, Bash.

---

## `code-reviewer`

**When it triggers:** spawned by `/review-pr` as one of three parallel
review agents. Reviews PR changes for code quality and architectural fit.

**Review dimensions:**
1. Architecture — established patterns, layer separation
2. Conventions — naming, imports, file organisation, project lint rules
3. Dead code — orphaned files, unused imports, unreachable code
4. Null safety — proper nullable types, no unnecessary `!`
5. DRY — duplicated logic across surfaces
6. State management — proper transitions, correct initialisation / cleanup
7. Data flow — type changes propagated to all consumers
8. Edge cases — off-by-one, empty collections, boundary conditions

**Severity levels:** Critical → Major → Minor → Nit.

**Process:** reads the full diff, verifies deleted code has no remaining
references, checks additions follow existing patterns, traces data flow
through all consumers, searches for inconsistencies where a pattern
changed in one place but the same pattern exists elsewhere.

---

## `qa-reviewer`

**When it triggers:** spawned by `/review-pr`. Reviews PR changes for
test quality and regression risk.

**Review dimensions:**
1. Test coverage — tests for every changed behaviour
2. Test plan completeness — the PR's stated test plan vs actual changes
3. Edge cases — empty inputs, boundaries, null / undefined states
4. Regression risk — existing functionality that could break
5. Test quality — descriptive names, correct assertions, isolation
6. Integration points — cross-surface interactions tested

**For UI changes:** must use Playwright or Chrome DevTools MCP to verify
the UI renders correctly in a running app, interact with the affected
surface, and confirm behaviour.

**Process:** maps every behavioural change from the diff, inventories
related tests, gap-analyses coverage, validates the stated test plan,
identifies regression scenarios, suggests concrete test code for
uncovered cases.

---

## `ux-reviewer`

**When it triggers:** spawned by `/review-pr`. Reviews PR changes purely
from a user-experience perspective.

**Review dimensions:**
1. Consistency — similar surfaces handled identically
2. User flow — changes make sense from the user's perspective; no dead ends
3. Component choice — correct UI components, proper spacing and sizing
4. Accessibility — labels, required indicators, error messages, keyboard nav, screen readers
5. Visual hierarchy — proper spacing, dividers, grouping, density
6. Error states — empty, loading, validation, disabled, read-only

**Severity levels:** Critical → Major → Minor → Nit.

**Process:** reads the PR description and ticket context to understand
intent, maps all affected UI surfaces, cross-references each surface for
consistent handling, checks component-library patterns in the codebase,
identifies missing states.
