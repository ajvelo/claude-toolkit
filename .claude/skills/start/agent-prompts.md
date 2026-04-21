## Agent Prompt Templates for /start

### Agent 1: Pattern Scout (Explore)

Prompt the agent with the project path, tech stack, ticket key+summary+description, and ask it to:

1. Find 2-3 **analogous implementations** (similar endpoints, views, services) and read them fully
2. Document **naming conventions**, **DI/wiring patterns**, **error handling patterns** with file references
3. List **reusable utilities** — existing helpers, extensions, base classes

Report: patterns found, reference files to read before implementing, reusable code with paths.

### Agent 2: Impact Analyzer (Explore)

Prompt the agent with the project path, tech stack, ticket key+summary+description+ACs, and ask it to:

1. Identify **files to modify** — search for relevant classes, endpoints, models
2. Find **callers and dependents** — grep for usages of methods/classes that will change
3. Map **API contracts** — DTOs, request/response models, serialization boundaries
4. Check **existing test coverage** — what tests exist, what gaps are there
5. Note **related config** — feature flags, route definitions, DI registrations

Report: affected files with risk level, caller graph, API contracts, test coverage table, risk areas.

---

## Verification Agent Prompts (Step 7)

### Agent: test-verifier (general-purpose)

Prompt with project path, type, changed files list, and validate command. Ask it to:

1. Set JDK if Kotlin, then run validation with 5-minute timeout
2. **Flutter gotcha**: `make validate` runs `dart fix --apply` which may mutate files outside the branch diff — `git diff --name-only` after and separate pre-existing issues from branch issues
3. Check test coverage: for each changed source file, does a test file exist and exercise the new behavior?

Report: PASS/FAIL with details, pre-existing issues if any, coverage table.

### Agent: code-quality-reviewer (Explore)

Prompt with project path and base branch. Ask it to read all changed files and review for:

1. Architectural soundness, dead code, error handling
2. Naming consistency, hardcoded values, serialization correctness

Rate issues as critical/major/minor. Report: issues list with file:line, overall PASS/NEEDS WORK/BLOCKED.

**Important:** This is an Explore agent — it has no Bash access. Provide the list of changed files directly in the prompt.

### Agent: ticket-matcher (Explore) — skip if no ticket

Prompt with ticket details, project path, base branch, and changed files. Ask it to:

1. Extract requirements from ACs (or infer from description)
2. Read each changed source file, map requirements → DONE/PARTIAL/MISSING/UNCLEAR
3. Check for scope creep
4. Score 0-100: requirement coverage /40, scope alignment /30, completeness /20, quality /10

Report: score, requirements table, scope analysis, gaps.

### Verdict

| Condition | Verdict |
|-----------|---------|
| Validation passes, no critical/major issues, ticket score ≥ 80 | **READY** |
| Passes but has major issues or score 60-79 | **NEEDS WORK** |
| Validation fails, critical issues, or score < 60 | **BLOCKED** |
