# demo-mobile — Flutter mobile app

Loaded by the claude-toolkit when Claude Code runs inside the `mobile`
project.

## Stack

- **Framework:** Flutter (managed via FVM — use `fvm flutter ...`)
- **Language:** Dart 3
- **State management:** Riverpod (example — adjust to your pick)
- **Routing:** go_router
- **Testing:** `flutter_test` + `integration_test`
- **Base branch:** `main`
- **Jira prefix:** `MOB-`

## Commands

| Task             | Command                                   |
|------------------|-------------------------------------------|
| Dev              | `fvm flutter run`                         |
| Unit tests       | `fvm flutter test`                        |
| Integration      | `fvm flutter test integration_test`       |
| Analyze          | `fvm flutter analyze`                     |
| Format           | `fvm dart format .`                       |
| Build iOS        | `fvm flutter build ipa --release`         |
| Build Android    | `fvm flutter build appbundle --release`   |
| All checks       | `fvm flutter analyze && fvm flutter test` |

**Run `fvm flutter analyze && fvm flutter test` before every commit.** CI
treats `info` diagnostics as failures.

## Conventions

- Widgets live in `lib/features/{feature}/widgets/`
- Feature state in `lib/features/{feature}/state/` as Riverpod providers
- Data layer in `lib/data/` — repositories + models + DTOs
- Shared UI primitives in `lib/ui/` (design-system widgets)
- Tests mirror `lib/` paths under `test/`

## Gotchas

- Never edit `lib/l10n/app*.arb` or generated `app_localizations*.dart` by
  hand — use the translation workflow (create keys, sync, regenerate)
- `fvm flutter clean` wipes generated code; re-run codegen afterward
  (`fvm dart run build_runner build --delete-conflicting-outputs`)
- Keep generated files (`*.g.dart`, `*.freezed.dart`) out of manual edits —
  always regenerate
