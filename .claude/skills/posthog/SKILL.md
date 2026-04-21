---
name: posthog
description: Query PostHog for feature flags, experiments, error rates, and analytics. Use when investigating feature rollouts or user behavior.
argument-hint: "[feature-flag-name | experiment-name | analytics-query]"
---

## PostHog Analytics

**Arguments:** $ARGUMENTS

Query PostHog for feature flags, experiments, error tracking, and analytics.

## Actions

### Feature Flags
- **List all flags**: `mcp__posthog__feature-flag-get-all`
- **Get flag definition**: `mcp__posthog__feature-flag-get-definition` with flag key
- **Check flag status**: `mcp__posthog__feature-flags-status-retrieve`

### Experiments
- **List experiments**: `mcp__posthog__experiment-get-all`
- **Get experiment**: `mcp__posthog__experiment-get`
- **Get results**: `mcp__posthog__experiment-results-get`

### Analytics
- **Trends**: `mcp__posthog__query-trends` for time series data
- **Funnels**: `mcp__posthog__query-funnel` for conversion analysis
- **Custom**: `mcp__posthog__query-generate-hogql-from-question` to generate HogQL from natural language

### Error Tracking
- **List errors**: `mcp__posthog__list-errors`
- **Error details**: `mcp__posthog__error-details`

### Users
- **Search**: `mcp__posthog__entity-search`
- **Person details**: `mcp__posthog__persons-retrieve`

## Common Queries

### Check if a feature flag is enabled for a user
1. Get the flag definition to see rollout conditions
2. Check if the user matches the conditions

### Check experiment results
1. Get the experiment by name
2. Fetch results to see variant performance

### Wiring a new flag into code
Most projects keep a typed wrapper over PostHog flags (constants module,
or a generated file via code-gen):

1. Add the flag key to the project's central flag list (e.g. `flags/feature_flags.json`)
2. Regenerate / update typed wrappers (e.g. `build_runner` for Flutter code-gen)
3. Register in DI if runtime evaluation is needed

## Output Format

```markdown
### {Flag/Experiment/Query} Results

**Name:** {key}
**Status:** {active/inactive}
**Rollout:** {percentage or conditions}

{Results table or summary}
```
