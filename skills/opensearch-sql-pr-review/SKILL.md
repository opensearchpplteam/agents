---
name: opensearch-sql-pr-review
description: PR/code review for opensearch-project/sql with focus on core, opensearch, ppl, calcite, integ-test, and docs. Use for review requests, PR diffs, or review comments in this repo. Exclude sql/legacy modules unless explicitly requested.
---

# Opensearch SQL PR Review

## Mission
Provide strict, engineer-to-engineer review for `opensearch-project/sql` changes in:
- `core`
- `opensearch`
- `ppl`
- `calcite`
- `integ-test`
- docs and doctest

Ignore `sql/legacy` unless the user explicitly asks to include it.


## Required Inputs
- PR description and linked issues.
- Diff or changed file list.
- Test evidence (CI status, local test output, or explicit "not run").
- Any logs, stack traces, or failing snapshots if available.

## Worktree Policy (mandatory)
- For PR review requests, create and use a dedicated git worktree before analyzing diffs.
- Do not review directly in the primary working directory unless the user explicitly asks to skip worktree setup.
- Use naming convention:
1. worktree path: `../sql-pr-<pr-number>-review`
2. branch name: `codex/review-pr-<pr-number>`
- If the worktree already exists, reuse it and sync to current PR head before review.

## Tooling Policy (mandatory)
- For GitHub PR/issue review tasks, use GitHub tooling first (`gh` CLI or equivalent GitHub-native tools in the client).
- Do not use generic `web_fetch` as the primary source for PR files/diff/comments when `gh` is available.
- Required source order:
1. `gh` PR metadata, files, diff, checks, and comments.
2. local `git` inspection if needed for additional patch context.
3. `web_fetch` only as fallback when `gh` is unavailable or blocked.
- If fallback is used, explicitly state:
- why `gh` could not be used.
- which data may be incomplete.
- reduced confidence for affected findings.

## Worktree Setup Sequence (before PR intake)
Run these in order:
- `gh pr view <pr-url-or-number> --json number,baseRefName,headRefName,headRepositoryOwner`
- `git fetch origin`
- `git worktree add ../sql-pr-<pr-number>-review -b codex/review-pr-<pr-number> origin/<baseRefName>` (if missing)
- `cd ../sql-pr-<pr-number>-review`
- `gh pr checkout <pr-url-or-number>`
- `git status --short`

## PR Intake Command Sequence (gh-first)
Run these in order for each PR review:
- `gh pr view <pr-url-or-number> --json number,title,body,author,baseRefName,headRefName,labels,changedFiles,additions,deletions,mergeable,url`
- `gh pr view <pr-url-or-number> --json files`
- `gh pr diff <pr-url-or-number>`
- `gh pr checks <pr-url-or-number>`
- `gh pr view <pr-url-or-number> --comments`
- If linked issues exist: `gh issue view <issue-number> --comments`
- If review comments exist and are relevant: `gh api repos/opensearch-project/sql/pulls/<pr-number>/comments`

## Severity Rubric
- `blocker`: correctness, security, or data integrity risk that can ship broken behavior.
- `major`: high-confidence regression risk, missing critical test coverage, or fragile design in a hot path.
- `minor`: maintainability issue or localized risk with bounded blast radius.
- `nit`: readability/style feedback with low risk.
- `question`: non-blocking clarification needed.

Prefer fewer high-signal findings over a long list of low-value notes.

## Comment Style (mandatory)
- Keep review comments concise and engineer-to-engineer.
- Use direct wording; avoid formal or ceremonial phrasing.
- Keep each finding focused on one risk and one next step.

## Finding IDs (mandatory)
- Assign stable sequence IDs per severity so users can refer to findings precisely.
- Format: `blocker 1`, `blocker 2`, `major 1`, `minor 1`, `nit 1`, `question 1`.
- IDs are local to each review output; keep numbering deterministic in report order.

## Workflow (in order)
1) Intake and scope lock
- Read PR intent, issue context, and module ownership.
- Classify the change: bugfix, perf, refactor, feature, docs-only, backport.
- Map changed files to impacted runtime path (planner, translator, executor, tests, docs).
- If linked issue includes explicit acceptance examples/cases, extract them into a checklist matrix before deep review.
- Draft a short PR change summary for the final output:
  - What changed (2 to 4 bullets).
  - Which modules/files are affected most.
  - Whether behavior, tests, and docs changed.

2) Fast risk pass
- Scan for behavior changes, API surface changes, configuration shifts, or performance-sensitive paths.
- Flag fragile areas immediately: pushdown rules, pagination/PIT lifecycle, alias/nested field handling, exception flow, permission checks, and query size limits.

3) Deep pass by subsystem
- Java logic: null handling, exception propagation, cleanup, mutability/thread-safety assumptions.
- Calcite/Rel rules: plan shape invariants, rule ordering side effects, projection/aggregation correctness.
- OpenSearch integration: request initialization, security context, cursor lifecycle, and API compatibility.
- Tests and snapshots: verify changed behavior is covered and expected outputs are intentionally updated.
- For behavior-changing PRs, require integration-level coverage (`integ-test` or `yamlRestTest`) unless there is a strong written rationale.
- When issue examples are explicit (for example Example 5/6/9), verify each example has coverage or a clear rationale.
- Docs/doctest (read as an end user, not a developer):
    - No internal implementation details in user-facing docs (e.g. Calcite internals, function mapping names, engine-specific notes).
    - Wording is clear and specific — flag vague terms like "join operation" or unexplained relationships.
    - Error examples match actual API response format.
    - Related commands section is relevant and the relationship is explained.
    - Labels/classifications (experimental, etc.) are justified — question if they seem wrong for the feature's complexity.
    - Remove boilerplate that applies to all commands unless it adds unique value.

4) Evidence bar for each finding
- Reference exact location as `path:line`.
- State concrete impact first (what can break and for whom).
- Add an actionable next step (code fix, test gap, or follow-up validation).
- Mark assumptions when evidence is incomplete.
- If tied to linked issue acceptance criteria, include `Spec ref: <issue/example>`.

5) Approval gate
- Behavior change has test updates, or a clear explanation for why tests are unnecessary.
- Missing both `integ-test` and `yamlRestTest` for behavior-changing PRs is an approval gap (at least `major`; treat as `blocker` for high-risk paths).
- Snapshot updates are intentional and reviewed for semantic correctness.
- User-facing changes include docs/doctest updates, or explicit rationale for omission.
- Any unresolved high-risk assumptions are called out.
- Do not classify PR merge conflicts (`mergeable=CONFLICTING`) as code-quality findings; report them separately as merge readiness info.

## Publish Review Comments (on request)
When the user asks to publish specific findings (for example: `publish blocker 1`), publish line comments to the PR using `gh`.

Required steps:
1. Resolve the selected finding ID to `path`, `line`, and comment body from the current review output.
2. Resolve PR metadata:
- `gh pr view <pr-url-or-number> --json number,headRefOid`
3. Publish a line comment with `gh api`:
- `gh api repos/<owner>/<repo>/pulls/<pr-number>/comments -f body='<comment body>' -f commit_id='<headRefOid>' -f path='<file path>' -F line=<line> -f side='RIGHT'`

Notes:
- Keep comment text concise and engineer-to-engineer.
- Publish only the finding IDs explicitly requested by the user.
- If a finding references multiple lines, publish on the primary line and mention the related lines in the comment body.
- If line mapping is outdated (diff changed), report the failure and ask for confirmation before retrying.

GitHub publish body format (mandatory):
- Write in natural engineer-to-engineer prose (1 to 3 short sentences).
- Do not include `Finding ID`, severity label, or section headers.
- Include:
1. concrete observation tied to the code/spec at that line.
2. why it matters (impact/risk), briefly.
3. clear requested change (specific fix/test/doc update).
- Prefer human phrasing such as:
`This test name implies null coverage, but the array has no null element. Could we rename it and add a true null-element case to cover Example 5?`

Example (from user selection):
- Selection: `publish blocker 1`
- Target: `opensearch/src/main/java/org/opensearch/sql/opensearch/monitor/OpenSearchResourceMonitor.java:70`
- Command pattern:
`gh api repos/opensearch-project/sql/pulls/<pr-number>/comments -f body='<blocker 1 body>' -f commit_id='<headRefOid>' -f path='opensearch/src/main/java/org/opensearch/sql/opensearch/monitor/OpenSearchResourceMonitor.java' -F line=70 -f side='RIGHT'`

## Output Format (strict)
Use this exact structure:

```
## PR Change Summary
- <what changed in this PR>
- <main modules/files touched>
- <behavior and test/docs impact>

## Review Findings

### Blocker Issues
[blocker 1] path:line - Impact. Actionable fix or next step.

### Major Issues
[major 1] path:line - Impact. Actionable fix or next step.

### Minor Issues
[minor 1] path:line - Impact. Actionable fix or next step.

### Nit Issues
[nit 1] path:line - Impact. Actionable fix or next step.

### Questions
[question 1] path:line - Clarifying question.

Follow-up Questions
- Question 1
- Question 2

Testing Recommendations
- Recommendation 1
- Recommendation 2

Approval
- Ready for approval | Not ready for approval (list missing checklist items)

Merge Readiness (informational)
- Clean | Conflicting
```

If no issues are found, write:
- `## PR Change Summary`
- `<same short change summary bullets>`
- `## Review Findings`
- `No blocker/major/minor findings.`

Output hygiene rules:
- Do not include execution task logs (for example `TODO:` blocks, tool checklists, command audit traces) in final review output.
- Keep review output focused on summary, findings, questions, testing recommendations, approval, and merge readiness.

## References
- Read `references/checklist-opensearch-sql.md` for subsystem checks and approval gates.
- Read `references/review-patterns.md` for high-signal finding patterns and comment phrasing.

## Assets
- Use `assets/templates/review-comment.md` when you need a preformatted comment block.
- Use `assets/templates/pr-line-comment.md` when publishing comments to GitHub PR lines.
