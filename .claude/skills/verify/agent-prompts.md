## Verify agent prompt templates

### Agent: `test-analyzer` (general-purpose)

> Run the project's validation suite and assess test coverage for the branch.
>
> **Project:** {shortname} at {project-path}
> **Project type:** {Flutter / Kotlin / TypeScript / Python / Go}
> **Changed files:** {name-only list}
> **Fix mode:** {true/false}
> **Validate command:** {from validation strategy table}
>
> 1. Set up the environment if needed (e.g. JDK version for Kotlin, `uv sync` for Python).
> 2. Run validation with a 5-minute timeout:
>    ```bash
>    cd {project-path} && timeout 300 {validate-command} 2>&1
>    ```
> 3. **Flutter gotcha:** `make validate` runs `dart fix --apply`, which may mutate files outside the branch diff. After it completes, `git -C {project-path} diff --name-only` — files not in the branch diff are pre-existing issues.
> 4. **If it fails AND fix mode is on:**
>    - Flutter: `make format && fvm dart fix --apply`
>    - Kotlin: `./gradlew ktlintFormat`
>    - TypeScript: `pnpm format`
>    - Python: `uv run ruff format . && uv run ruff check --fix .`
>    Then re-validate.
> 5. **If it still fails:** categorise — format/lint → list files; analyzer → severity + file:line; tests → name, assertion, in-diff or not.
> 6. **Coverage check:** for each changed source file, does a corresponding test file exist and exercise the new behaviour?
>
> **Report:** `## Validation: PASS | FAIL` + summary, coverage table, missing-coverage list.

---

### Agent: `ticket-matcher` (general-purpose) — skip if no ticket

> Score how well the implementation matches the ticket.
>
> **Ticket:** {key}: {summary}
> **Description + ACs:** {full description}
> **Project:** {shortname} at {project-path}
> **Diff stats + commits:** {provided}
>
> 1. Extract requirements from ACs (or infer)
> 2. Read each changed source file, map requirements → DONE / PARTIAL / MISSING / UNCLEAR
> 3. Check for scope creep
> 4. Score 0–100: coverage /40, scope /30, completeness /20, quality /10
>
> **Report:** `## Score: XX/100` + requirements table, scope analysis, gaps.

---

### Agent: `visual-health` (general-purpose) — UI-rendering projects only

> Verify the UI renders correctly and check browser health. This agent
> applies to any project that has a local dev server rendering HTML or
> canvas (e.g. `web`, `mobile` when running on Flutter web).
>
> **Changed UI / state files:** {lists}
> **Target URLs:** {mapped routes from route-mapping.md}
> **ACs:** {if available}
>
> ## Framework notes
>
> **Flutter web (CanvasKit):** renders to `<canvas>`, not DOM.
> `browser_snapshot` returns the accessibility tree — only Playwright
> screenshots verify visual rendering.
>
> **React / Next.js (DOM):** `browser_snapshot` is authoritative;
> screenshots are optional but helpful for PR comments.
>
> ## Setup
> 1. `mkdir -p /tmp/verify-{key}`
> 2. Resize to a consistent viewport (e.g. `1440x900` desktop, `390x844` mobile)
> 3. Navigate to the project's dev URL (from `projects/{shortname}.md`)
> 4. Wait for load (per-project; Flutter web DDC can take ~45s cold), snapshot to verify content loaded (not a login wall)
>
> ## Navigation
> - ALWAYS snapshot before clicking — get refs
> - ALWAYS click via `browser_click` with `ref`
> - AVOID `browser_navigate` to new URLs after initial load for canvas-based apps — triggers a dev-bundler recompile
> - After clicking, snapshot again to confirm the new state
>
> ## For each surface
> 1. Navigate via in-app clicks
> 2. Snapshot → confirm the correct page
> 3. Screenshot (JPEG, element-level via `ref`, save to `/tmp/verify-{key}/`)
> 4. Walk through states: default, populated, error/validation, tabs
> 5. Collect: `browser_console_messages` (flag errors, ignore framework noise), `browser_network_requests` (flag 4xx/5xx, slow >3s)
>
> ## Error recovery
> | Problem                 | Action                                                    |
> |-------------------------|-----------------------------------------------------------|
> | Can't connect to dev port | Report blocker: dev server not running                  |
> | Loading spinner >15s    | Screenshot, refresh once, report if still loading        |
> | Login wall              | Report blocker with auth setup instructions              |
> | Click timeout           | Re-snapshot, retry with updated ref                      |
>
> **Report:** screenshot table, AC visual check, browser health (console errors, failed requests), issues list.
