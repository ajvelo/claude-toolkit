## What?

<!-- 1-3 bullets describing the change. -->

## Why?

<!-- Problem solved or motivation. -->

## Test plan

<!-- How did you verify this works? -->
- [ ] `shellcheck --severity=warning hooks/*.sh scripts/*.sh install.sh` passes
- [ ] `jq empty` succeeds on any changed JSON
- [ ] Installer smoke test runs clean (see CONTRIBUTING.md)
- [ ] Manually verified in a Claude Code session (for skill / agent changes)
- [ ] Updated `CHANGELOG.md` under `[Unreleased]`

## Notes for the reviewer

<!-- Design notes, open questions, follow-up work. -->
