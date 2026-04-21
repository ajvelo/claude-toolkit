# Architecture Gotchas

Cross-project pitfalls, surprising behaviours, and non-obvious conventions
worth remembering across sessions. This file is shipped mostly empty on
purpose — fill it in as you go. The `CLAUDE.md` auto-learning section
instructs Claude to append here when it discovers something surprising.

Each entry should be:
- **One line** stating the rule or observation
- Optional follow-up lines with *why* and *how to apply*
- No speculation — only things confirmed by reading code, docs, or a real
  incident

---

## Template entry

Use this shape when adding a new gotcha:

```
- **Short name in bold** — one-line description of the pitfall.
  Why: the reason it trips people up (past incident, protocol quirk, hidden default).
  How to apply: when/where this rule kicks in.
```

---

## General

- **Don't assume repo paths from shortnames** — the installer resolves paths
  dynamically; always read `~/.claude/project-repos.json` to get the actual path
- **Analyzer warnings are CI failures** — every project in the registry treats
  `info`/`warning`-level analyzer output as a failure. Run the local check
  command before committing; don't wait for CI.

---

## Flutter / Dart

*(Add gotchas about pubspec, codegen, widget lifecycle, localisation
workflow, platform channels, etc., as you discover them.)*

---

## TypeScript / Web

*(Add gotchas about SSR vs client boundaries, bundle size, type-only imports,
pnpm workspace quirks, etc.)*

---

## Kotlin / JVM

*(Add gotchas about coroutine scopes, DI lifecycle, ORM transaction
boundaries, JVM version matrix, Gradle daemon, etc.)*

---

## Python / Backend

*(Add gotchas about async session handling, dependency caching, Pydantic
v1→v2 migration, uvicorn worker lifecycle, etc.)*

---

## Infrastructure / Ops

*(Add gotchas about Terraform state locking, Helm upgrade semantics, GitOps
drift, secret rotation, etc.)*
