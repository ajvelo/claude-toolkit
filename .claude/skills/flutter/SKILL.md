---
name: flutter
description: Build, test, or analyze a Flutter project
disable-model-invocation: false
argument-hint: "<build|test|analyze> <shortname> [test-path]"
---

## Flutter Build / Test / Analyze

**Arguments:** $ARGUMENTS

Resolve project paths from `~/.claude/project-repos.json`. Any registry
entry with `pubspec.yaml` at the root is treated as a Flutter project.

## Actions

### `build`

```bash
cd {repo-path} && fvm flutter build
```

If the build fails on missing dependencies, run `fvm flutter pub get` first.
If codegen outputs are missing (`*.g.dart`, `*.freezed.dart`), run:

```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

Projects with a `Makefile` often expose a `make br` target that wraps
`pub get` + `build_runner` + platform builds — prefer that when available.

### `test`

```bash
# all tests
cd {repo-path} && fvm flutter test

# a single file or pattern
fvm flutter test path/to/some_test.dart
```

Projects with `Makefile` usually expose `make test` — prefer when present.

### `analyze`

```bash
cd {repo-path} && fvm flutter analyze
```

**Fix every analyzer diagnostic**, including `info`-level warnings (import
ordering, unnecessary lambdas, discarded futures) — CI treats them all as
failures.

## Process

1. Parse arguments: action, project shortname, optional test path
2. Read `~/.claude/project-repos.json` to resolve the project path
3. `cd` to the path
4. Run the command
5. Report success/failure with error details (trimmed to the relevant lines)
