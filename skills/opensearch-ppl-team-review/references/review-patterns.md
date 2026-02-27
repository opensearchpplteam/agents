# PPL Review Patterns

Patterns to produce precise, high-signal findings in OpenSearch PPL reviews.

## High-Value Finding Patterns

1. PPL command behavior changed without corresponding test updates
2. Behavior changed without integ-test or yamlRestTest coverage
3. Linked issue has explicit PPL examples, but one or more examples have no
   direct test coverage
4. Snapshot/expected output changed without semantic explanation
5. Cleanup path moved or removed in pagination/PIT logic
6. Pushdown or rule-order change can alter plan/results for PPL queries in
   edge cases (nested fields, multi-valued, null-heavy)
7. Exception conversion loses root cause or actionable context
8. Permission-sensitive path changed without integration coverage
9. New branching/flags make PPL command control flow harder to validate
10. User-facing PPL syntax or behavior changed without docs/doctest updates
11. Join/lookup/subquery scope change can leak or shadow field names
12. Aggregation pushdown in stats/rare/top alters null-handling semantics
13. Parse/patterns/grok regex change can silently change extraction results
14. Fillnull/flatten/expand changes affect downstream command assumptions
15. New class in an existing package skips defensive patterns used by sibling
    classes (e.g., NaN/Infinity handling, null guards, logging conventions)

## Team-Specific Patterns

### ppl-logic teammate should watch for

- Grammar ambiguity introduced by new syntax rules
- Visitor not handling a new AST node type (ClassCastException risk)
- Analyzer allowing type mismatch that will fail at runtime
- Plan shape change breaking existing Calcite rule assumptions
- Null semantics inconsistency across PPL command boundaries
- New parser/handler class not following sibling class patterns (see
  "Sibling Class Pattern Consistency" below)

### test-integration teammate should watch for

- Test names that do not match actual test behavior
- Snapshot updates that silently accept regression
- Missing negative-path tests for new error conditions
- Docs showing old syntax/output after behavior change
- yamlRestTest missing for new PPL command features

### security-perf teammate should watch for

- PIT handle leak on exception path
- Field-level security bypassed by new projection logic
- Unbounded materialization in join/subquery execution
- Resource cleanup skipped when cursor fetch fails mid-stream
- Permission check removed or weakened in code reorganization

## Comment Framing

- Lead with impact, not implementation detail
- Keep tone concise and engineer-to-engineer (not formal)
- Include one concrete next step
- Keep each finding focused on one risk
- Use `question` severity only for genuine uncertainty

## Example Phrasing

- "This can leak PIT handles when the fetch path throws before close."
- "Rule ordering may skip projection trimming for nested fields in PPL join."
- "Add cleanup in the exception branch and cover with an integration test."
- "The stats pushdown drops null groups; add a test with null-only partition."
- "Parse pattern changed but existing tests still pass with old regex; add
  a case that would catch the semantic difference."

## Sibling Class Pattern Consistency

When a PR adds a new class to an existing package, every reviewer must check
how sibling classes in that package handle cross-cutting concerns. The new
class should follow the same defensive patterns unless there is an explicit
reason to diverge.

**Checklist for new classes in existing packages:**

1. Identify all sibling classes that implement the same interface or extend the
   same base class.
2. Scan siblings for shared utilities or defensive calls (e.g.,
   `Utils.handleNanInfValue`, null guards, logging, metric collection).
3. Verify the new class uses those same utilities in equivalent code paths.
4. If the new class intentionally skips a pattern, flag it as a `question` for
   the author to confirm the omission is deliberate.

**Lesson learned (PR #5189):** `SumStatsParser` was added to the
`response.agg` package alongside `SingleValueParser` and `StatsParser`. Both
siblings use `Utils.handleNanInfValue()` to convert NaN/Infinity to null, but
`SumStatsParser` omitted this call. The review team focused on the core logic
(`count == 0 → null`) and missed the pattern inconsistency because they
analyzed the new file in isolation rather than comparing it against sibling
classes in the same package.

**How to avoid:** When reviewing a new class, always read at least two sibling
classes that implement the same interface. Look for shared utility calls,
defensive checks, and error handling patterns. This cross-file comparison
catches omissions that are invisible when reviewing the new file alone.

## Anti-Patterns to Avoid

1. Vague comments without path/line references
2. Multiple unrelated concerns in one finding
3. Style-only feedback when major risk remains unresolved
4. Asking for refactors without explaining risk or benefit
5. Reporting merge-conflict status as code-quality finding
6. Duplicating findings already covered by another teammate
7. Speculating about issues without inspecting the actual code in the worktree
