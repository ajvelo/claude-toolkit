# API Contract Patterns

Cross-boundary data serialization gotchas when one project calls another.
These apply whenever JSON crosses a language/runtime boundary.

## Naming convention mismatches

Different stacks pick different defaults. Wire up the translation at the
boundary DTO, not deep inside business logic.

| Layer                  | Typical convention | Example           |
|------------------------|--------------------|-------------------|
| Python (FastAPI)       | snake_case         | `user_id`         |
| Kotlin                 | camelCase          | `userId`          |
| Flutter / Dart         | camelCase          | `userId`          |
| TypeScript (JSON APIs) | camelCase          | `userId`          |
| Database (Postgres)    | snake_case         | `user_id`         |
| Kafka / event payloads | camelCase          | `userId`          |

## DTO patterns at the boundary

### Request flow (frontend → gateway → service)
```
Client model → JSON (camelCase) → Gateway DTO → Service DTO (whatever) → Service model
```

### Response flow (service → gateway → frontend)
```
Service model → Service response → Gateway DTO → JSON (camelCase) → Client model
```

Keep the mapping explicit at the *gateway* layer, not at the service. That
way the service owns its own convention, and the gateway normalises to
whatever the frontend expects.

### Jackson / Kotlin DTO annotations
- `@JsonProperty("snake_case_field")` when a property name differs between Kotlin and JSON
- `@JsonIgnoreProperties(ignoreUnknown = true)` on *all* DTOs — lets the service add fields without breaking clients
- `@JsonAnySetter` for dynamic / open-ended properties

### Pydantic (Python) DTO patterns
- Use `alias` + `populate_by_name=True` to accept either form
- `model_config = ConfigDict(extra="ignore")` on response models for forward-compat

## Common gotchas

- **Nullable mismatch** — the producer returns `null`/`None` for a field the
  consumer's type says is non-null; result: crash on deserialization. Treat
  every field as nullable until you control both ends.
- **Date formats** — stick to ISO 8601 UTC (`2026-01-15T10:30:00Z`). Avoid
  library-specific conventions (epoch millis, "pretty" formats).
- **Empty array vs object** — some languages serialize an empty associative
  collection as `{}` (Python, PHP), others as `[]`. Pick a shape at the DTO
  layer and don't let the producer's choice leak through.
- **Boolean strings** — some legacy JSON APIs return `"true"` / `"false"`.
  Coerce at the DTO layer.
- **Enum growth** — new enum values on the producer break strict-deserializing
  consumers. Either: make the client enum open (accept unknown → "other"),
  or bump a version and run both old + new.
- **Decimal precision** — monetary values must travel as strings. Floats lose
  precision across JSON boundaries silently.

## Adding a new endpoint across a boundary

1. Define the DTO in the calling layer matching the service's response
2. Use whatever per-language annotation maps snake_case ↔ camelCase
3. Mark unknown-field tolerance (`@JsonIgnoreProperties`, `extra="ignore"`, etc.)
4. Test round-trip with a sample payload the service actually returns
5. Mark every field nullable until proven otherwise
6. Document what happens when the producer adds/removes fields — forward
   compatibility is a contract, not an afterthought
