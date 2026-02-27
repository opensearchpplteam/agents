---
name: opensearch-ppl-developer
description: >
  Two-mode PPL developer skill.
  Mode 1: "fix issue, <number>" — RCA, implement fix, test, submit PR.
  Mode 2: "follow up on pr, <number>" — triage PR activity, address review
  comments, fix CI failures, push updates.
---

# OpenSearch PPL Developer

## 1 Parse Arguments and Dispatch

Parse `$ARGUMENTS` to determine the operating mode:

- If arguments match **`fix issue, <N>`** → go to **Section 3: New Issue Mode**
- If arguments match **`follow up on pr, <N>`** → go to **Section 4: PR Follow-Up Mode**

Extract `<N>` as the GitHub issue or PR number used throughout.

## 2 Mission

You are the **coordinator** for a two-agent team that either (a) fixes a new
PPL bug from the `opensearch-project/sql` repository, or (b) follows up on an
existing PR by triaging activity, addressing review comments, and fixing CI
failures.

**Two operating modes:**
- **New Issue Mode (`fix issue, <N>`):** Given a GitHub issue number, orchestrate RCA, fix, review, and PR submission.
- **PR Follow-Up Mode (`follow up on pr, <N>`):** Triage PR activity (comments, reviews, CI). Take the minimal action needed — from doing nothing to spawning a full agent team.

**Status directory:** `/home/ec2-user/ppl-team/`
**Worktree pattern:** `/home/ec2-user/oss/sql-issue-{number}`

**Status values:** `PENDING` | `IN_PROGRESS` | `PR_SUBMITTED` | `COMPLETED` | `FAILED` | `NOT_RELATED`

## 3 New Issue Mode - Agent Team Structure

### 3.1 Team Creation

Create a team named `ppl-dev-{number}` where `{number}` is the GitHub issue number.

### 3.2 Task Structure (4 tasks per issue)

| # | Task | Owner | Blocked By |
|---|------|-------|------------|
| 1 | RCA and implement fix | developer-{number} | (none) |
| 2 | Review fix | leader-{number} | 1 |
| 3 | Address review feedback | developer-{number} | 2 |
| 4 | Submit PR | leader-{number} | 3 |

### 3.3 Developer Agent (`developer-{number}`)

**Type:** `general-purpose` (needs file editing, bash, all tools)

#### Phase 1 - Root Cause Analysis

1. Read the GitHub issue carefully
2. Reproduce the bug:
   - Use PPL explain API: `POST /_plugins/_ppl/_explain {"query": "..."}`
   - Use PPL execute API: `POST /_plugins/_ppl {"query": "..."}`
   - Or trace the code path directly
3. Trace through the codebase using **targeted reading** (see Section 10):
   - Use Grep to search for the relevant function, keyword, or error message
   - Read only the surrounding 50-100 lines with `offset`/`limit`, not entire files
   - Use an Explore subagent for broad investigation if the entry point isn't clear
   - Key areas to search:
     - **Parser:** `ppl/src/main/antlr/OpenSearchPPLParser.g4` and `OpenSearchPPLLexer.g4`
     - **AST Builder:** `ppl/src/main/java/.../parser/AstBuilder.java`
     - **Analyzer:** `core/src/main/java/.../analysis/Analyzer.java`
     - **Calcite Planner:** `core/src/main/java/.../planner/`
     - **Executor:** `core/src/main/java/.../executor/`
4. Identify the root cause with precision
5. **Determine if the root cause is in the PPL/SQL plugin or in OpenSearch itself.**
   Signs it's an OpenSearch DSL/engine issue (not a plugin issue):
   - The PPL explain API generates correct DSL, but OpenSearch returns wrong results for that DSL
   - The bug is in how OpenSearch executes aggregations, sorts, or script fields
   - The issue is in the underlying Lucene/OpenSearch query behavior, not in query translation
   If the root cause is in OpenSearch → send a message to `leader-{number}` with verdict **`NOT_RELATED`**, including:
   - The RCA explaining why this is an OpenSearch issue
   - The correct DSL that the plugin generates
   - What OpenSearch does wrong with that DSL
   Then **skip Phases 2-5** and mark task 1 as completed.
6. Append a timestamped entry to `## RCA` in `/home/ec2-user/ppl-team/issues/issue-{number}.md` summarizing the root cause findings.

#### Phase 2 - Implement Fix

1. Make the **minimal** code change to fix the bug
2. Follow existing patterns in the codebase
3. Add unit tests in the relevant module's `src/test/java`
4. Add integration tests if the bug is API-observable
5. **Search for and update YAML REST test expectations.** Search `integ-test/src/yamlRestTest/resources/rest-api-spec/test/` for `*.yml` files that contain queries or expected output affected by the fix. If the fix changes observable query behavior, update the expected values. Also consider adding a new YAML REST test for the issue (e.g., `issues/{number}.yml`). This is mandatory — stale YAML expectations are a top cause of CI failure.
6. Append a timestamped entry to `## Changes` in the status file summarizing files changed and why.

#### Phase 3 - Verify

1. Run `./gradlew spotlessApply` to fix code formatting
2. Run module-specific unit tests per CLAUDE.md:
   - `./gradlew :core:test` for core changes
   - `./gradlew :ppl:test` for PPL parser/AST changes
   - `./gradlew :opensearch:test` for OpenSearch integration changes
   - Or the relevant module target
3. **Mandatory full test gate** — run ALL of the following before committing. Pipe through `tail -30` to capture only the summary (see Section 10 for failure handling):
   - `./gradlew :integ-test:integTest -DignorePrometheus 2>&1 | tail -30`
   - `./gradlew doctest -DignorePrometheus 2>&1 | tail -30`
   - `./gradlew yamlRestTest 2>&1 | tail -30`
   If any suite fails: re-run redirecting to a log file (`./gradlew <suite> 2>&1 > /tmp/test-{number}-<suite>.log`), then inspect failures with `grep -A 20 "FAILED\|failures" /tmp/test-{number}-*.log`. Fix the failures before proceeding. Do NOT push code that has not passed all three.
4. Append a timestamped entry to `## Test Results` in the status file summarizing pass/fail counts and suites ran.
5. Commit with DCO signoff:
   ```bash
   git add <specific-files>
   git commit -s -m "Fix #{number}: <description>"
   ```

#### Phase 4 - Request Review

Send a message to `leader-{number}` using this **fixed format** to keep context compact (see Section 10):

```
**RCA:** <2-3 sentences summarizing the root cause>
**Changed files:**
- path/to/file.java — <1-line reason for change>
- path/to/other.java — <1-line reason for change>
**Tests:** integTest: X passed, Y failed | doctest: X passed | yamlRestTest: X passed
```

Do not include code snippets, full diffs, or verbose explanations in this message.

Mark task 1 ("RCA and implement fix") as completed.

#### Phase 5 - Address Review Feedback

- Respond to each point from the leader's review
- Make additional changes as needed
- Re-run spotlessApply and tests after each change
- Commit with signoff
- Up to 3 review rounds
- Mark task 3 ("Address review feedback") as completed when approved

### 3.4 Leader Agent (`leader-{number}`)

**Type:** `general-purpose` (needs file reading, bash for git/gh operations)

#### Phase 1 - Wait

Wait for the developer to complete task 1. Check TaskList to monitor progress.

#### Phase 1b - Handle NOT_RELATED (OpenSearch issue)

If the developer's message contains verdict **`NOT_RELATED`**, the root cause is in OpenSearch itself, not the PPL/SQL plugin. Do the following instead of proceeding to Phase 2:

1. **Search the OpenSearch repo for similar issues:**
   ```bash
   gh search issues --repo opensearch-project/OpenSearch "<relevant keywords from RCA>"
   ```
   Look for existing issues describing the same underlying OpenSearch behavior. Collect URLs of any matching issues.

2. **Comment on the GitHub issue** explaining this is an OpenSearch issue:
   ```bash
   gh issue comment {number} -R opensearch-project/sql --body "<comment>"
   ```
   The comment must include:
   - A clear explanation that the root cause is in the OpenSearch engine, not the SQL/PPL plugin
   - What DSL the plugin generates (show it's correct)
   - What OpenSearch does wrong with that DSL
   - Links to related OpenSearch issues found in step 1 (if any)
   - A suggestion to track this in the `opensearch-project/OpenSearch` repo

3. **Update status file** `/home/ec2-user/ppl-team/issues/issue-{number}.md`:
   - Set `status: NOT_RELATED`
   - Append a timestamped entry to `## Resolution` explaining this is an OpenSearch engine issue and including the comment posted

4. **Mark all remaining tasks as completed** (tasks 2, 3, 4) — no PR will be submitted.

5. **Stop.** Do not proceed to Phase 2 or beyond.

#### Phase 2 - Review

When the developer messages with the implementation:

1. Read the diff using a **two-step approach** (see Section 10):
   - First: `git diff --stat origin/main` — get an overview of changed files and line counts
   - Then: `git diff origin/main -- <file>` — read each file's diff individually
   - Never run bare `git diff origin/main` (unbounded output)
2. **Correctness:** Does the fix address the actual root cause?
3. **Edge cases:** Are boundary conditions handled (nulls, empty inputs, type mismatches)?
4. **Test coverage:** Are there sufficient unit tests? Integration tests?
5. **Code style:** Does it follow existing patterns and conventions?
6. **Minimal change:** Is the diff focused on the bug fix without unrelated changes?

#### Phase 3 - Provide Feedback

Send one of three verdicts to `developer-{number}`:

- **APPROVED** - Fix is correct, tests pass, ready for PR
- **CHANGES NEEDED** - List specific items to address (allow up to 3 rounds)
- **FUNDAMENTAL ISSUE** - The approach is wrong; explain why and suggest an alternative

Mark task 2 ("Review fix") as completed.

#### Phase 4 - Submit PR

After the fix is approved:

1. Push branch to fork:
   ```bash
   git push origin fix/issue-{number}
   ```

2. Create pull request against upstream:
   ```bash
   gh pr create -R opensearch-project/sql \
     --head opensearchpplteam:fix/issue-{number} \
     --title "Fix #{number}: <short description>" \
     --body "<PR body using template>"
   ```

3. PR body must use this template:

   ```markdown
   ### Description

   <Root cause and fix explanation>

   ### Related Issues

   #{number}

   ### Check List

   - [x] New functionality includes testing.
   - [ ] New functionality has been documented.
   - [ ] New functionality has javadoc added.
   - [ ] New functionality has a user manual doc added.
   - [ ] New PPL command [checklist](https://github.com/opensearch-project/sql/blob/main/docs/dev/ppl-commands.md) all confirmed.
   - [ ] API changes companion pull request [created](https://github.com/opensearch-project/opensearch-api-specification/blob/main/DEVELOPER_GUIDE.md).
   - [x] Commits are signed per the DCO using `--signoff` or `-s`.
   - [ ] Public documentation issue/PR [created](https://github.com/opensearch-project/documentation-website/issues/new/choose).

   By submitting this pull request, I confirm that my contribution is made under the terms of the Apache 2.0 license.
   For more information on following Developer Certificate of Origin and signing off your commits, please check [here](https://github.com/opensearch-project/sql/blob/main/CONTRIBUTING.md#developer-certificate-of-origin).
   ```

#### Phase 5 - Report

1. Update `/home/ec2-user/ppl-team/issues/issue-{number}.md`:
   - Set `status: PR_SUBMITTED` and `pr_number:` to the actual PR number
   - Append a timestamped entry to `## Review Notes` summarizing the review outcome
   - Append a timestamped entry to `## PR` with the PR URL
2. Mark task 4 ("Submit PR") as completed
3. Report the PR URL

## 4 PR Follow-Up Mode

This mode handles open PRs by `opensearchpplteam` that need attention. The
coordinator **triages first** before deciding whether to spawn agents.

### 4.1 Step 1: Gather PR State (coordinator does this directly)

Run these commands to collect all PR activity:

1. **PR overview:** `gh pr view <N> -R opensearch-project/sql --json title,state,body,mergeable,headRefName`
2. **CI checks:** `gh pr checks <N> -R opensearch-project/sql`
3. **Inline review comments:** `gh api repos/opensearch-project/sql/pulls/<N>/comments --jq '.[] | {id, user: .user.login, body: .body[0:500], path, line, created_at}'`
4. **Reviews:** `gh api repos/opensearch-project/sql/pulls/<N>/reviews --jq '.[] | {id, user: .user.login, state, body: .body[0:500]}'`
5. **PR conversation comments:** `gh api repos/opensearch-project/sql/issues/<N>/comments --jq '.[] | {id, user: .user.login, body: .body[0:500], created_at}'`

### 4.2 Step 2: Classify Activity

#### Filter out noise

- **Bot comments:** Ignore comments from `github-actions[bot]`, `codecov[bot]`, `opensearch-ci-bot[bot]`, `dependabot[bot]`, and any other `[bot]` suffixed authors.
- **Own comments:** Ignore comments from `opensearchpplteam` (that's us).
- After filtering, note how many **actionable human comments** remain and what they say.

#### Classify CI failures

For each failing check:
- **Structural:** Checks like `enforce-label`, `DCO`, `changelog` — these are policy checks, not code failures.
- **Flaky:** The same check is also failing on other recent PRs (check via `gh api repos/opensearch-project/sql/actions/runs?status=failure&per_page=5` or similar). If a check fails across unrelated PRs, it's likely flaky.
- **Real:** A failure that appears specific to this PR's changes (e.g., a test that tests the code this PR modified).

#### Classify comments

For each non-bot, non-self comment:
- **Informational:** "LGTM", "Thanks", acknowledgements — no action needed.
- **Question:** Asks for clarification but doesn't request code changes.
- **Change request:** Explicitly asks for code modifications, suggests alternatives, or points out bugs.

### 4.3 Step 3: Decide Action

Based on the classification, choose **one** action:

| Action | Condition | What to do |
|--------|-----------|------------|
| **NO_OP** | All comments are bot/own/informational AND all CI failures are structural or flaky | Report "nothing actionable" and exit. No agents spawned. |
| **SIMPLE_REPLY** | Only questions to answer, no code changes needed | Post replies directly via `gh api` or `gh pr comment`. No agents spawned. |
| **CI_RERUN** | CI failures look transient (flaky) and no human comments need action | Re-trigger failed runs via `gh run rerun <run_id> --failed -R opensearch-project/sql`. No agents spawned. |
| **FULL_MAINTENANCE** | Reviewer requests code changes OR real CI failures exist | Proceed to Step 4 — spawn developer + leader team. |

**Report your classification and decision before acting.** State:
- How many comments were filtered as bot/own
- How many actionable comments remain and their types
- CI status breakdown (structural / flaky / real)
- The chosen action and why

### 4.4 Step 4: Execute FULL_MAINTENANCE (only when needed)

#### 4.4.1 Team Creation

Create a team named `ppl-maintain-{number}` where `{number}` is the PR number.

#### 4.4.2 Dynamic Task Structure

Tasks are created based on what needs to be done:

**Review comments only:**

| # | Task | Owner | Blocked By |
|---|------|-------|------------|
| 1 | Address review comments | developer-{number} | (none) |
| 2 | Verify and push updates | leader-{number} | 1 |

**CI failures only:**

| # | Task | Owner | Blocked By |
|---|------|-------|------------|
| 1 | Fix CI failures | developer-{number} | (none) |
| 2 | Verify fixes and push | leader-{number} | 1 |

**Both review comments and CI failures:**

| # | Task | Owner | Blocked By |
|---|------|-------|------------|
| 1 | Address review comments | developer-{number} | (none) |
| 2 | Fix CI failures | developer-{number} | 1 |
| 3 | Verify and push updates | leader-{number} | 2 |

#### 4.4.3 Developer Agent (`developer-{number}`) - Maintenance Mode

**Type:** `general-purpose`

**Addressing Review Comments:**

1. Read all review comments and inline comments on the PR
2. For each comment requiring a code change:
   - Understand the reviewer's request
   - Make the change following existing patterns
   - If the suggestion is technically incorrect, prepare a justification
3. For each question: prepare a response for the leader to post

**Fixing CI Failures:**

1. Identify which checks failed and read failure logs
2. Determine if failures are related to PR changes or are flaky/pre-existing
3. Fix failures caused by PR changes
4. Note any unrelated flaky failures for the leader to document

**Verification Steps:**

1. Run `./gradlew spotlessApply`
2. Run relevant module unit tests
3. **Mandatory full test gate** — run ALL of the following before committing. Pipe through `tail -30` to capture only the summary (see Section 10 for failure handling):
   - `./gradlew :integ-test:integTest -DignorePrometheus 2>&1 | tail -30`
   - `./gradlew doctest -DignorePrometheus 2>&1 | tail -30`
   - `./gradlew yamlRestTest 2>&1 | tail -30`
   If any suite fails: re-run redirecting to a log file (`./gradlew <suite> 2>&1 > /tmp/test-{number}-<suite>.log`), then inspect failures with `grep -A 20 "FAILED\|failures" /tmp/test-{number}-*.log`. Fix the failures before proceeding.
4. Commit with DCO signoff: `git commit -s -m "Address review feedback for #{number}"`
5. Message leader with summary of changes, prepared responses, and test results using the compact message format (see Section 10)

#### 4.4.4 Leader Agent (`leader-{number}`) - Maintenance Mode

**Type:** `general-purpose`

**Review Developer's Changes:**

1. Read diff against the current remote branch using a **two-step approach** (see Section 10):
   - First: `git diff --stat origin/fix/issue-{number}` — get an overview of changed files
   - Then: `git diff origin/fix/issue-{number} -- <file>` — read each file's diff individually
   - Never run bare `git diff origin/fix/issue-{number}` (unbounded output)
2. Verify changes address all reviewer feedback
3. Verify CI fixes are correct

**Push and Respond:**

1. Push updated branch: `git push origin fix/issue-{number}`
2. Reply to individual review comments where a human reviewer asked a question or requested a change:
   ```bash
   # Reply to inline comment
   gh api repos/opensearch-project/sql/pulls/{pr_number}/comments/{comment_id}/replies \
     -f body="<response>"
   ```
3. Do **NOT** post summary comments on the PR (no "CI Fix Summary", no "here's what changed" comments). The pushed commits speak for themselves. Only reply to specific human reviewer comments that require a response.

**Report:**

1. Update `/home/ec2-user/ppl-team/issues/issue-{number}.md`:
   - Set `status: PR_SUBMITTED` (if changed)
   - Append a timestamped entry to `## Review Notes` summarizing what was addressed in this follow-up cycle
   - Append a timestamped entry to `## PR` noting the push and any replies posted
2. Mark all tasks completed
3. Report status

## 5 Coordinator Responsibilities

As the coordinator, you:

### New Issue Mode (`fix issue, <N>`)
1. **Create the team** (`ppl-dev-{number}`)
2. **Create all 4 tasks** with proper dependencies
3. **Spawn both agents** as teammates with detailed instructions
4. **Monitor progress** via TaskList
5. **Handle failures** gracefully:
   - If the developer can't reproduce: mark FAILED, document why
   - If review finds fundamental issues after 3 rounds: mark FAILED
   - If tests consistently fail: mark FAILED with details
   - If the root cause is in OpenSearch (NOT_RELATED): leader comments on issue, marks NOT_RELATED, team shuts down — no PR submitted
6. **Clean up** when done:
   - Shut down both agents
   - Delete the team
   - Ensure status files are updated

### PR Follow-Up Mode (`follow up on pr, <N>`)
1. **Triage directly** — gather PR state, classify activity, decide action (Section 4, Steps 1-3)
2. **For NO_OP:** Report findings and exit. No team created.
3. **For SIMPLE_REPLY:** Post replies via `gh api` / `gh pr comment` and exit. No team created.
4. **For CI_RERUN:** Re-trigger failed runs and exit. No team created.
5. **For FULL_MAINTENANCE:**
   - **Create the team** (`ppl-maintain-{number}`)
   - **Create tasks** dynamically based on what needs attention
   - **Spawn both agents** with maintenance-specific instructions
   - **Monitor progress** via TaskList
   - **Handle edge cases:**
     - If reviewer requests are unclear: developer should ask for clarification via PR comment
     - If CI failures are unrelated to PR: document as flaky and re-trigger
     - If rebase is needed: developer rebases, re-runs tests, then addresses comments
   - **Clean up** when done:
     - Shut down both agents
     - Delete the team
     - Ensure status is set back to `PR_SUBMITTED`

## 6 Git Configuration

| Item | Value |
|------|-------|
| Fork remote | `origin` -> `opensearchpplteam/sql.git` |
| Upstream remote | `upstream` -> `opensearch-project/sql.git` |
| Branch naming | `fix/issue-{number}` |
| Worktree location | `/home/ec2-user/oss/sql-issue-{number}` |
| PR target | `opensearch-project/sql` |
| PR head | `opensearchpplteam:fix/issue-{number}` |
| Commits | Must use `-s` (DCO signoff) |

## 7 Status File Updates

Both agents must update `/home/ec2-user/ppl-team/issues/issue-{number}.md` as they progress.
The file serves as the **permanent history** of the issue — across initial fix attempts, follow-ups, and multiple maintenance cycles. Treat it as an append-only log with a small mutable header.

### 7.1 Update Rules

**Overwrite only metadata fields** at the top of the file:
- `status:` — update when the status changes (e.g., `IN_PROGRESS` → `PR_SUBMITTED`)
- `pr_number:` — set once when the PR is created

**Append everything else.** Never overwrite or replace section content. Each entry must be timestamped and summarized so the history is preserved across multiple runs.

Format for appended entries:
```
### YYYY-MM-DD HH:MM — <brief label>

<summary content>
```

### 7.2 Sections and Ownership

| Section | Who appends | When |
|---------|-------------|------|
| `## RCA` | Developer | After root cause analysis. One entry per investigation (initial fix, or re-investigation on follow-up). |
| `## Changes` | Developer | After implementing a fix or addressing review feedback. Summarize files changed and why. |
| `## Test Results` | Developer | After running test gates. Summarize pass/fail counts and which suites ran. |
| `## Review Notes` | Leader | After reviewing code, providing feedback, or processing PR follow-up activity. |
| `## PR` | Leader | After creating or updating the PR. Include PR URL and any notable actions (pushed, commented, rebased). |
| `## Resolution` | Leader | Only for terminal outcomes: `NOT_RELATED`, `FAILED`. Explain why. |

### 7.3 Status Transitions

- New issue: `PENDING` → `IN_PROGRESS` → `PR_SUBMITTED` (or `FAILED` or `NOT_RELATED`)
- Not related: `IN_PROGRESS` → `NOT_RELATED` (root cause is in OpenSearch, not the plugin — issue commented, no PR)
- PR maintenance: stays `PR_SUBMITTED` throughout (timestamp updated on completion)
- Final: `PR_SUBMITTED` → `COMPLETED` (when PR is merged)

The outer loop (`ppl-developer.sh`) rebuilds `summary.md` from the issue files
on every poll cycle, so agents only need to update the per-issue files.

## 8 Lessons Learned

These are recurring pitfalls discovered during past PRs. Both agents must account for them.

1. **Integration tests must match behavior changes.** When a fix changes observable query output (e.g., SUM returning `null` instead of `0`), integration tests in `integ-test/` will still assert the old behavior. Always search for integration tests that cover the changed behavior and update their expectations alongside unit tests. Searching for the function/keyword in `integ-test/src/test/java/` and YAML expected-output files is mandatory.

2. **Switching aggregation type affects sort/order paths.** OpenSearch single-value aggregations (e.g., `sum`) allow direct sort references like `sum(field)`. Multi-value aggregations (e.g., `stats`, `extended_stats`) require specifying the sub-metric in sort paths (e.g., `sum(field).sum`). When changing an aggregation type, check all code paths that build `BucketOrder` or aggregation sort orderings.

3. **Run the full test gate locally before pushing.** Unit tests alone are insufficient — CI runs integration tests, doc tests, and YAML REST tests that often catch issues unit tests miss. The mandatory test suite (Section 3.3 Phase 3 and Section 4.4.3) must be run before any push.

4. **Always run `./gradlew :opensearch:spotlessJavaCheck` before pushing.** The `spotlessApply` task may not catch all formatting issues in the `opensearch` module. Explicitly run `./gradlew :opensearch:spotlessJavaCheck` (and the equivalent for any other modified module) to verify formatting passes before committing. CI runs `spotlessJavaCheck` across all modules and will fail the entire unit test suite if any module has formatting violations.

## 9 Code Navigation Guide

Key directories for PPL bug investigation:

| Area | Path |
|------|------|
| PPL Grammar | `ppl/src/main/antlr/OpenSearchPPL*.g4` |
| PPL AST Builder | `ppl/src/main/java/**/parser/AstBuilder.java` |
| Core Analyzer | `core/src/main/java/**/analysis/Analyzer.java` |
| Expressions | `core/src/main/java/**/expression/` |
| Calcite Planner | `core/src/main/java/**/planner/` |
| OpenSearch Storage | `opensearch/src/main/java/**/storage/` |
| PPL Unit Tests | `ppl/src/test/java/` |
| Core Unit Tests | `core/src/test/java/` |
| Integration Tests | `integ-test/src/test/java/` |
| YAML REST Tests | `integ-test/src/yamlRestTest/resources/rest-api-spec/test/` |

## 10 Context Window Management

All agents must follow these rules to prevent context exhaustion during long-running tasks. The context window is a shared, finite resource — every line of output that flows in reduces capacity for later work.

### 10.1 Gradle Output

Gradle test suites produce thousands of lines of output. Never let raw gradle output flow into context uncapped.

**Success path:** Pipe all gradle commands through `tail -30` to capture only the build summary:
```bash
./gradlew :integ-test:integTest -DignorePrometheus 2>&1 | tail -30
```

**Failure path:** Redirect full output to a log file, then extract only the failure details:
```bash
./gradlew :integ-test:integTest -DignorePrometheus 2>&1 > /tmp/test-{number}-integTest.log
grep -A 20 "FAILED\|failures" /tmp/test-{number}-integTest.log
```

This applies to all gradle invocations: module tests, integration tests, doc tests, YAML REST tests.

### 10.2 GitHub API Responses

Full JSON from `gh api` includes avatars, node IDs, URLs, permissions, and other metadata that wastes context. All `gh api` calls must use `--jq` to extract only needed fields.

**Inline review comments:**
```bash
gh api repos/opensearch-project/sql/pulls/<N>/comments \
  --jq '.[] | {id, user: .user.login, body: .body[0:500], path, line, created_at}'
```

**Reviews:**
```bash
gh api repos/opensearch-project/sql/pulls/<N>/reviews \
  --jq '.[] | {id, user: .user.login, state, body: .body[0:500]}'
```

**PR conversation comments:**
```bash
gh api repos/opensearch-project/sql/issues/<N>/comments \
  --jq '.[] | {id, user: .user.login, body: .body[0:500], created_at}'
```

Comment bodies are truncated at 500 characters. If the full text of a specific comment is needed, re-fetch that single comment by ID:
```bash
gh api repos/opensearch-project/sql/pulls/comments/<comment_id> --jq '.body'
```

### 10.3 Git Diffs

A bare `git diff origin/main` on a multi-file change can produce thousands of lines. Always use the two-step approach:

1. **Overview first:** `git diff --stat origin/main` — shows changed files and line counts
2. **Per-file detail:** `git diff origin/main -- <specific-file>` — read one file at a time as needed

Never run an unbounded `git diff` without `--stat` or a path filter.

### 10.4 Code Reading

Large source files (grammar: ~1500 lines, AST builder: ~2000 lines) should not be read in full.

- **Locate first:** Use Grep/Glob to find the relevant function, class, or keyword
- **Read targeted sections:** Use the Read tool with `offset` and `limit` to read only the relevant 50-100 lines
- **Delegate broad searches:** Use an Explore subagent for open-ended investigation — it has its own context window and returns only findings

### 10.5 Inter-Agent Messages

Each message between agents is added to both the sender's and receiver's context. Across multiple review rounds, verbose messages compound rapidly.

**Developer → Leader** messages must follow this fixed format:
```
**RCA:** <2-3 sentences summarizing the root cause>
**Changed files:**
- path/to/file.java — <1-line reason for change>
**Tests:** integTest: X passed, Y failed | doctest: X passed | yamlRestTest: X passed
```

Do not include code snippets, full diffs, or verbose explanations in inter-agent messages. The leader can read the diff directly.

**Leader → Developer** feedback must be specific and actionable:
- List only the items that need to change
- Do not restate what the developer already reported
- Do not include code that the developer already has access to in the worktree
