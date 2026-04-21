# demo-web — TypeScript / Next.js

Loaded by the claude-toolkit when Claude Code runs inside the `web` project.

## Stack

- **Framework:** Next.js (App Router)
- **Language:** TypeScript (strict)
- **Package manager:** pnpm (workspaces)
- **Styling:** Tailwind CSS
- **Testing:** Vitest (unit) + Playwright (E2E)
- **Base branch:** `main`
- **Jira prefix:** `WEB-`

## Commands

| Task              | Command                           |
|-------------------|-----------------------------------|
| Dev               | `pnpm dev`                        |
| Build             | `pnpm build`                      |
| Unit tests        | `pnpm test`                       |
| E2E tests         | `pnpm playwright test`            |
| Lint              | `pnpm lint`                       |
| Typecheck         | `pnpm typecheck`                  |
| Format            | `pnpm format`                     |
| All checks        | `pnpm run check`                  |

**Run `pnpm run check` before every commit.** It runs format, lint, and
typecheck in one pass. CI fails on any warning.

## Conventions

- Route segments live in `app/` following Next.js App Router conventions
- Shared components in `components/`
- Server actions in `app/**/_actions.ts`
- Data fetching: prefer React Server Components; client components are `"use client"` only when needed
- API routes in `app/api/`
- Types live alongside code — only extract to `types/` when shared across features
- Tests mirror source paths (`foo.ts` → `foo.test.ts`)

## Gotchas

- Environment variables prefixed `NEXT_PUBLIC_` are exposed to the client
  bundle — never put secrets behind that prefix
- Server components cannot use hooks or client-only APIs
- Dynamic route params are async in the App Router — `await params`
- `next.config.js` image domains must be allow-listed for remote `<Image>`
