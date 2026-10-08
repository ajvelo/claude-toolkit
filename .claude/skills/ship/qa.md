# /ship QA reference

QA is not optional: every ticket that changes behaviour a user can see gets visual and functional checks before its PR is proposed as ready. A check that can't run is `unavailable`, never `pass`.

## The QA plan (written at `plan`)

`## QA plan` in the state file, one block per check:
```
- id: empty-cart-banner
  surface: web-preview | web-local | ci | manual
  where: /cart                  # path, CI job name, or device flow
  steps: remove the last item
  expect: banner "Your cart is empty"; checkout button disabled; no console errors
  data: staging test user qa+cart@example.com (seeded by the e2e fixtures)
```
- **Pick real staging data** and write down how it was found (query, fixture or route), so later runs can find it again. If none exists, say so; don't fake it.
- **Cover the change, not the whole app:** the screens the diff touches, one unhappy path, and the regression the ticket is about.
- **Mobile:** name the existing UI-test flows (Maestro, XCUITest, Espresso) that cover the area and run them as `ci` checks. Anything only a person can check is `manual`, listed in the PR body for the reviewer.

## Surfaces

| Surface | How |
|---|---|
| `web-preview` | `ship-qa preview-url <repo> <pr>` gives the URL once the preview deploy check passes. `ship-qa web <KEY> <url> <sha>` runs every `~/.claude/work/<KEY>/qa/web/*.cjs` |
| `web-local` | Start the repo's dev server in the worktree and run the same scripts against `http://localhost:<port>` before publish. Repos without a preview URL rely on this. Stop the server afterwards and revert any files it generated in the worktree before parking `publish` |
| `ci` | Named CI jobs that must pass on the head SHA |
| `manual` | Listed in the PR body; never recorded as `pass` by the pipeline |

## Writing a web QA script

`~/.claude/work/<KEY>/qa/web/<check-id>.cjs`, plain Playwright, run by `ship-qa web` with `PW_LIB`, `BASE_URL`, `OUT` and `CHECK` set. Exit non-zero on failure with a one-line reason on stderr; print a JSON summary on stdout; save `${OUT}/${CHECK}.png`.
- Phone viewport (390×844) unless the change is desktop-only.
- Record a video of the flow (`recordVideo: { dir: OUT }`, renamed to `${OUT}/${CHECK}.webm`) with pauses on each state a reviewer should see. Take a screenshot only where an assertion needs evidence.
- Assert on the DOM (text, roles, element counts), collect `console` errors and `pageerror`, and normalise whitespace before comparing text (formatted prices often use non-breaking spaces).
- `ship-qa web` refuses any host that isn't localhost or matched by `SHIP_QA_ALLOWED_HOSTS`.
- **Never** submit a payment, place an order or change account data unless the check is about exactly that and runs on staging with test credentials named in the plan. Read-only by default.
- Use the CLI, not the Playwright MCP tools: explore with a throwaway script run through `ship-qa web`, and keep it as a check if it's worth repeating.

## Before/after videos in the PR

Every PR that changes something visible gets two `.webm` videos of the same flow: **before** (the base branch on staging) and **after** (the PR preview), with the same data. GitHub has no API for attachments, so **the user posts the videos as a PR comment**:
1. QA scripts record video. Run them twice: `ship-qa web <KEY> "$(ship-qa base-url <repo>)" before` and `ship-qa web <KEY> <preview-url> <sha>`.
2. Copy both to `~/.claude/work/<KEY>/qa/media/<check>-before.webm` and `<check>-after.webm`.
3. In the PR body's `## QA evidence`, give the preview URL, test data and check results, and say whether the change is visible. If before and after look the same, say so.
4. In `## Next step` and the publish summary, give the command to run: `ship-media <KEY>` (copies the videos to `~/Downloads/<KEY>-qa` and opens the folder), then "drag both videos into one PR comment".

If the "after" video comes from `web-local` rather than the preview, name the file `-after-local` and say so in `## QA evidence`. Repos without a `base-url` get the after video only. Screenshots stay in `~/.claude/work/<KEY>/qa/results/` as evidence for `qa-failed`.

## Results and failures

- Record every run in `## QA results`: check id, surface, commit SHA, pass/fail/unavailable, screenshot path.
- Re-run preview checks on every new head SHA; a result is only valid for the SHA it ran on.
- Write a `## QA results` row for **every** head SHA, even when nothing applies (`n/a`, with the reason). `ship-state pending` treats a head SHA missing from the state file as needing QA and wakes the loop each tick until it's recorded.
- Any `fail` → `awaiting: qa-failed` with the failing check, its screenshot path and a proposed fix in `## Next step`.
- A planned check that can't run at all → `awaiting: clarification`. A sub-assertion that staging data can't exercise, for behaviour the diff doesn't change and unit tests cover, is `unavailable` with the reason and doesn't block `publish`; flag it in the publish summary.
- The PR description lists the QA checks and their results. A draft is never proposed as ready while a planned check is failing or unrun for the head SHA.
