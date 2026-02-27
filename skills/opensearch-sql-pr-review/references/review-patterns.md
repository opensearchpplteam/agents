# Review Patterns (OpenSearch SQL)

Use these patterns to produce precise, high-signal findings.

## High-value finding patterns
- Behavior changed without corresponding test updates.
- Behavior changed without `integ-test` or `yamlRestTest` coverage.
- Linked issue has explicit examples, but one or more examples have no direct test coverage.
- Snapshot/expected output changed without semantic explanation.
- Cleanup path moved or removed in pagination/PIT logic.
- Pushdown or rule-order change can alter plan/results in edge cases.
- Exception conversion loses root cause or actionable context.
- Permission-sensitive path changed without integration coverage.
- New branching/flags make control flow harder to validate.
- User-facing syntax or behavior changed without docs/doctest updates.

## Comment framing pattern
- Lead with impact, not implementation detail.
- Keep tone concise and engineer-to-engineer, not formal.
- Include one concrete next step.
- Keep each finding focused on one risk.
- Use `question` severity only for genuine uncertainty.

## Example phrasing snippets
- `Impact: This can leak PIT handles when the fetch path throws before close.`
- `Next step: Add cleanup in the exception branch and cover with an integration test.`
- `Impact: Rule ordering may skip projection trimming for nested fields.`
- `Next step: Add a regression test with nested alias + aggregate pipeline.`

## Anti-patterns to avoid
- Vague comments without path/line references.
- Multiple unrelated concerns in one finding.
- Style-only feedback when major risk remains unresolved.
- Asking for refactors without explaining risk or benefit.
- Reporting merge-conflict status as a code-quality finding instead of merge-readiness info.
