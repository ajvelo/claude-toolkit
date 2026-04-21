## Verify Agent Prompt Templates

### Agent: test-analyzer (general-purpose)

> Run the project's validation suite and assess test coverage for the branch.
>
> **Project:** {shortname} at {project-path}
> **Project type:** {Flutter/Kotlin/Node/Go/PHP}
> **Changed files:** {name-only list}
> **Fix mode:** {true/false}
> **Validate command:** {from validation strategy table}
>
> 1. Set up environment if needed (JDK version for Kotlin projects).
> 2. Run validation with 5-minute timeout:
>    ```bash
>    cd {project-path} && timeout 300 {validate-command} 2>&1
>    ```
> 3. **Flutter GOTCHA:** `make validate` runs `dart fix --apply` which may mutate files outside the branch diff. After it completes, `git -C {project-path} diff --name-only` — files not in branch diff = pre-existing issues.
> 4. **If it fails AND fix mode is ON:** Flutter: `make format && fvm dart fix --apply`. Kotlin: `./gradlew ktlintFormat`. Then re-validate.
> 5. **If it fails (no fix / still failing):** Categorize: format/lint → list files. Analyzer → severity + file:line. Tests → name, assertion, in-diff or not.
> 6. **Coverage check:** For each changed source file, does a corresponding test file exist and exercise the new behavior?
>
> **Report:** `## Validation: PASS | FAIL` + summary, coverage table, missing coverage list.

---

### Agent: ticket-matcher (general-purpose) — skip if no ticket

> Score how well the implementation matches the Jira ticket.
>
> **Ticket:** {key}: {summary}
> **Description + ACs:** {full description}
> **Project:** {shortname} at {project-path}
> **Diff stats + commits:** {provided}
>
> 1. Extract requirements from ACs (or infer)
> 2. Read each changed source file, map requirements → DONE/PARTIAL/MISSING/UNCLEAR
> 3. Check for scope creep
> 4. Score 0-100: coverage /40, scope /30, completeness /20, quality /10
>
> **Report:** `## Score: XX/100` + requirements table, scope analysis, gaps.

---

### Agent: visual-health (general-purpose, portal only)

> Verify the portal UI renders correctly and check browser health.
>
> **Changed UI/ViewModel files:** {lists}
> **Target URLs:** {mapped routes from route-mapping.md}
> **ACs:** {if available}
>
> ## Flutter Web CanvasKit
> Portal renders to `<canvas>`, not DOM. `browser_snapshot` returns accessibility tree. Only Playwright screenshots verify visual rendering.
>
> ## Setup
> 1. `mkdir -p /tmp/verify-{key}`
> 2. Resize to 1728x1117
> 3. Navigate to `http://localhost:8080`
> 4. Wait for load (~10s), snapshot to verify content (not login wall)
>
> ## Navigation (CRITICAL)
> - ALWAYS snapshot before clicking — get refs
> - ALWAYS click via `browser_click` with `ref`
> - NEVER `browser_navigate` to new URL after initial load — triggers DDC recompile
> - After clicking, snapshot again to confirm
>
> ## For Each Surface
> 1. Navigate via in-app clicks
> 2. Snapshot → confirm correct page
> 3. Screenshot (JPEG, element-level via `ref`, save to `/tmp/verify-{key}/`)
> 4. Walk through states: default, populated, error/validation, tabs
> 5. Collect: `browser_console_messages` (flag errors, ignore Flutter noise), `browser_network_requests` (flag 4xx/5xx, slow >3s)
>
> ## Error Recovery
> | Problem | Action |
> |---------|--------|
> | Can't connect to 8080 | Report blocker: dev server not running |
> | Loading spinner >15s | Screenshot, refresh once, report if persists |
> | Login wall | Report blocker with proxy start instructions |
> | Click timeout | Re-snapshot, retry with updated ref |
>
> **Report:** Screenshots table, AC visual check, browser health (console errors, failed requests), issues list.
