# PostHog Tracking Patterns

Conventions for PostHog feature flags and analytics events, applicable to
any project that integrates with PostHog.

---

## Feature flags

### Adding a new flag (generic workflow)

1. Add the flag key to your project's central flag list (e.g. a JSON file
   consumed by code generation, or a constants module)
2. Regenerate / update any typed wrappers so the flag is referenceable by
   constant instead of string literal
3. Register in DI / context if the flag needs runtime checking

### Flag naming convention

```
{scope}.{snake_case_name}
```

Prefixing by scope keeps flags grouped in the PostHog UI and makes it
obvious which team or surface owns a flag.

| Example prefix | Scope                                       |
|----------------|---------------------------------------------|
| `web.`         | Web frontend features                       |
| `mobile.`      | Mobile app features                         |
| `api.`         | Server-side / API features                  |
| `billing.`     | Billing / payment features                  |
| `auth.`        | Authentication and identity features        |

### Flag File

`flags/feature_flags.json` — flat JSON array of flag strings. Code-generated via `@Flags` annotation into `feature_flags.flags.g.dart`.

---

## Analytics Events

### Architecture

```
Analytics (interface)
  └── PosthogAnalytics (implementation, uses posthog_flutter)
```

- `analytics.track(event, eventVersion:, properties:)` — main tracking method
- `analytics.trackPageViewed(name)` — page view tracking
- `analytics.trackDrawerViewed(name)` — drawer view tracking
- `analytics.setIdentity(user)` — identify user (id, email, locale, and any relevant custom properties such as role or plan)

### Event Naming Convention

- **snake_case** — enforced at runtime by `_assertSnakeCase()`
- Format: `{feature}_{action}` (e.g., `bilateral_agreement_cancelled`)
- Always include `eventVersion` (start at 1, increment on schema changes)

### Analytics Class Pattern

Each feature has its own analytics class:

```dart
class MyFeatureAnalytics {
  const MyFeatureAnalytics({required this.analytics});
  final Analytics analytics;

  /// @posthog event: my_feature_action_taken
  /// @posthog motivation: Why we track this
  /// @posthog trigger: Where/when it fires
  /// @posthog tags: feature_area
  void trackActionTaken({required int entityId}) {
    analytics.track(
      'my_feature_action_taken',
      eventVersion: 1,
      properties: {'entity_id': entityId},
    );
  }
}
```

### Docstring Convention

Every tracking method MUST have `@posthog` docstring tags:

| Tag | Purpose |
|-----|---------|
| `@posthog event:` | Event name (snake_case) |
| `@posthog motivation:` | Why this event matters for product decisions |
| `@posthog trigger:` | Where in code it fires (ViewModel method + condition) |
| `@posthog tags:` | Feature area for grouping in PostHog |

### Property Naming

- Keys: `snake_case` strings
- Values: primitives (string, int, bool) — no nested objects
- Define property keys as `static const` in the analytics class

---

## Wiring a New Feature's Analytics

1. Create `{feature}_analytics.dart` in the feature's presentation directory
2. Add `@posthog` docstrings on every tracking method
3. Register in DI (feature's `presentation_dependencies.dart`)
4. Inject into ViewModels that need tracking
5. Call tracking methods at the appropriate trigger points (after successful interactor calls, not before)

---

## PostHog MCP Integration

Use the `/posthog` skill to:
- List and inspect feature flags
- Check experiment results
- Query analytics data
- Search for error tracking events
