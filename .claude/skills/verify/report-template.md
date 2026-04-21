## Verification report template

```markdown
# Verification report: {TICKET-KEY} — {summary}

**Branch:** `{branch-name}`
**Project:** {shortname} ({project-type})
**Ticket:** [TICKET-KEY]($JIRA_HOST/browse/TICKET-KEY)
**Changed:** +{additions} / -{deletions} across {N} files

## Verdict: READY | NEEDS WORK | BLOCKED

| Check            | Status                 | Summary    |
|------------------|------------------------|------------|
| Tests & Analysis | PASS/FAIL              | {one-line} |
| Ticket Match     | {score}/100 or SKIPPED | {one-line} |
| Visual           | PASS/WARN/FAIL/SKIPPED | {one-line} |
| Browser Health   | PASS/WARN/FAIL/SKIPPED | {one-line} |

## Acceptance criteria

- [x] {criterion} — {evidence: screenshot #N / test name / file:line}
- [ ] {criterion} — {what's missing}

## Visual walkthrough

{`![description](image-url)` for each screenshot. Or "Skipped — not a UI change."}

## Browser health

{Errors / warnings, or "Clean." Or "Skipped."}

## Tests & analysis

{Validation summary + coverage table}

## Ticket match

{Score breakdown + requirement table}

## Action items

{Numbered list with file paths. Empty if READY.}
```

## Verdict logic

| Condition                                              | Verdict        |
|--------------------------------------------------------|----------------|
| All PASS, score ≥ 80, no visual issues                 | **READY**      |
| Warnings only, score 60–79, cosmetic visual issues     | **NEEDS WORK** |
| Validation failures (unfixed), score < 60, visual bugs | **BLOCKED**    |

Mixed results → verdict = worst result. Always explain the mismatch.

## Next steps

- **READY** → "Verified. `/pr` to create draft PR?"
- **NEEDS WORK** → "Found {N} issues. Want me to fix them?"
- **BLOCKED** → "{Blocker}. Fix and re-run `/verify`."
