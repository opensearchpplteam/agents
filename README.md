# PPL Team Agent Environment

One-line installer for provisioning EC2 instances with the full OpenSearch PPL agent development environment.

## Quick Start

SSH into your Amazon Linux 2023 EC2 instance and run:

```bash
curl -fsSL https://raw.githubusercontent.com/opensearchpplteam/agents/main/install.sh | bash
```

The installer runs 7 steps: installs system packages (Java 21, Git, tmux, gh, Node.js 22, bc), installs Claude Code, configures Claude Code with Bedrock settings, sets up Git/GitHub authentication, clones repositories, configures the shell environment, and verifies everything.

After installation, open a new terminal and verify:

```bash
java --version              # Should show 21.x
claude --version            # Should show latest version
gh auth status              # Should show authenticated
ls ~/oss/ppl/.claude/skills # Should show 2 symlinks
```

Start a Claude session:

```bash
cd ~/oss/ppl
claude
```

## Tutorial: Using the Skills

Two skills are installed into `~/oss/ppl/.claude/skills/` and are available as slash commands inside any Claude Code session started from `~/oss/ppl/`.

---

### Skill 1: opensearch-ppl-developer

Fixes GitHub issues and maintains open PRs in `opensearch-project/sql` using coordinated agent teams.

#### Fix a GitHub issue

```
/opensearch-ppl-developer fix issue, 5178
```

This spawns a two-agent team (developer + leader) that:
1. Performs root cause analysis on the issue
2. Implements the fix and runs tests
3. Reviews the changes and addresses any issues
4. Submits a PR to `opensearch-project/sql`

The developer agent writes and tests code in an isolated git worktree (`~/oss/sql-issue-{number}/`) on a branch named `fix/issue-{number}`. The leader agent reviews the work, provides feedback, and handles the PR submission.

#### Follow up on an open PR

```
/opensearch-ppl-developer follow up on pr, 5189
```

The skill triages the PR's recent activity first, then takes the minimal action needed:

| Situation | Action |
|-----------|--------|
| Only bot comments, no real feedback | Reports findings and exits |
| Simple questions from reviewers | Posts replies directly, no agents spawned |
| Transient CI failures (flaky tests) | Re-runs the failed checks |
| Code changes requested by reviewers | Spawns developer + leader team to address feedback |


---

### Skill 2: opensearch-sql-pr-review

Provides strict, engineer-to-engineer code review for PRs in `opensearch-project/sql`.

#### Review a PR

From a Claude Code session in `~/oss/ppl/`:

```
/opensearch-sql-pr-review 3216
```

The skill:
1. Creates a dedicated git worktree (`../sql-pr-{number}-review`) and checks out the PR
2. Fetches PR metadata, diff, changed files, and CI status using `gh`
3. Performs a fast risk pass to identify high-severity areas
4. Does a deep pass through each changed subsystem (`core`, `opensearch`, `ppl`, `calcite`, `integ-test`, docs)
5. Publishes findings as GitHub review comments

#### Review output

Each finding is graded by severity:

| Severity | Meaning |
|----------|---------|
| **blocker** | Must fix before merge — correctness bug, data loss risk, security issue |
| **major** | Should fix — performance regression, missing edge case, API contract violation |
| **minor** | Nice to fix — style inconsistency, naming, minor simplification |
| **nit** | Optional — formatting, comment wording |
| **question** | Needs clarification from the author |

The review ends with an approval gate: approve, request changes, or comment-only, based on whether any blockers or majors remain.

#### Covered modules

The skill reviews changes in these modules and ignores `sql/legacy` unless you explicitly ask:

- `core` — query planner and execution engine
- `opensearch` — OpenSearch integration layer
- `ppl` — PPL language parser and AST
- `calcite` — Calcite-based query optimizer
- `integ-test` — integration tests
- docs and doctest
