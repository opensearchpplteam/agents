# OpenSearch SQL Review Checklist

Use this checklist during deep review. Prioritize correctness and regression risk over style.

## Planner and semantics
- PPL semantics preserved for filtering, projection, sorting, and aggregation.
- Calcite pushdown changes do not alter logical results.
- Rule interactions preserve plan shape invariants.
- Multi-valued and nested fields still produce expected semantics.
- Alias resolution and field qualification stay consistent.

## Execution and lifecycle
- Pagination/PIT create and cleanup paths are paired correctly.
- Cursor lifecycle and fetch-size behavior are consistent across success and failure.
- Exception flow preserves root cause and avoids swallowing actionable errors.
- Resource cleanup happens on all paths (normal, timeout, and exception).

## OpenSearch integration and safety
- Permission checks are not bypassed or weakened.
- Request objects are initialized before use (builders, explain state, context fields).
- API usage remains compatible with expected OpenSearch versions in this repo.
- Query size or limit changes are intentional and justified.

## Performance and stability
- Added loops, sorting, or materialization do not create avoidable hot-path cost.
- Object allocations and intermediate structures are bounded in hot paths.
- Backpressure and streaming assumptions are still valid where applicable.

## Tests and snapshots
- Behavior changes include at least one focused unit or integration test.
- Behavior-changing PRs should include `integ-test` or `yamlRestTest` coverage.
- Snapshot/expected output updates reflect intentional behavior change.
- Negative-path tests exist for fragile logic (permissions, nested fields, pagination cleanup).
- If tests are not added, rationale is explicit and credible.

## Docs and doctest
- User-visible syntax/behavior updates docs or doctest coverage.
- Any docs omission is explicitly justified in review output.

## Approval gate
- No unresolved blocker or major findings.
- Test evidence is present or risk is explicitly accepted.
- Missing both `integ-test` and `yamlRestTest` for behavior-changing PRs is an approval gap.
- Follow-up questions are tracked when assumptions remain.
