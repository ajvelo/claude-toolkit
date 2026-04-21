## Route mapping (file path → URL)

When the `visual-health` agent needs to navigate to the right page, map
changed source paths to the dev-server URLs. This file is the *mapping* —
keep it next to actual app structure, not as abstract rules.

### Flutter web (example layout)

| Source path pattern                            | URL path                           |
|------------------------------------------------|------------------------------------|
| `lib/features/dashboard/`                      | `/dashboard`                       |
| `lib/features/settings/`                       | `/settings`                        |
| `lib/features/<feature>/` (list screen)        | `/<feature>`                       |
| `lib/features/<feature>/detail/`               | `/<feature>/{id}/overview`         |

### Next.js (App Router, example layout)

| Source path                         | URL                         |
|-------------------------------------|-----------------------------|
| `app/dashboard/page.tsx`            | `/dashboard`                |
| `app/settings/page.tsx`             | `/settings`                 |
| `app/<segment>/[id]/page.tsx`       | `/<segment>/:id`            |
| `app/<segment>/[id]/edit/page.tsx`  | `/<segment>/:id/edit`       |
| `components/**`                     | (navigate to any page that uses the component) |

### Tips for the visual-health agent

- **Routes with `{id}` / `:id`:** navigate to the list page first and click
  the first item. Never hard-code real IDs — they rot.
- **Auth:** the dev server is typically pointed at staging via a proxy;
  authentication is already handled by the proxy. If a page renders a blank
  state, check the network panel for 401/403 before assuming a rendering bug.
- **Router transitions:** wait for the network-idle signal or the specific
  element before screenshotting; canvas-based frameworks (Flutter web) don't
  fire DOMContentLoaded reliably.
