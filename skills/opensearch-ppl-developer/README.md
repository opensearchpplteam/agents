# OpenSearch PPL Developer

Automated system that fixes GitHub issues from `opensearch-project/sql` via Claude agent teams and follows up on open PRs by triaging activity, addressing review comments, and fixing CI failures.

## Direct Invocation

The skill can be invoked directly from Claude Code with two modes:

### Fix a new issue

```
/opensearch-ppl-developer fix issue, 5178
```

Spawns a developer + leader agent team to: RCA the issue, implement a fix, run tests, review, and submit a PR.

### Follow up on a PR

```
/opensearch-ppl-developer follow up on pr, 5189
```

The coordinator triages PR activity first — filtering bot comments, classifying CI failures, and reading review comments. Based on the triage:

- **Nothing actionable** (all bot comments, flaky CI) → reports findings and exits
- **Simple replies needed** (questions, no code changes) → posts replies directly, no agents
- **Transient CI failures** → re-runs failed checks, no agents
- **Code changes requested** (reviewer feedback, real CI failures) → spawns developer + leader team

## Architecture

Two components can work independently or together:

1. **Outer loop** (`scripts/ppl-developer.sh`) - Bash script that polls GitHub for new issues and open PRs, manages deduplication/status, sets up git worktrees, and launches Claude sessions automatically.

2. **Skill** (`SKILL.md`) - Claude skill that can be invoked directly (see above) or by the outer loop. Defines a two-agent team (developer + leader) with built-in triage for PR follow-ups.

```
ppl-developer.sh (bash, runs in background)
  |
  +-- Sync summary.md from issues/ folder
  |
  +-- Phase 1: Check open PRs by opensearchpplteam
  |   +-- For each PR with new activity (comments, CI failures):
  |       +-- Launch: claude -p "<pr-maintain-prompt>" -d <worktree>
  |             +-- TeamCreate("ppl-maintain-{number}")
  |             +-- developer: address comments, fix CI
  |             +-- leader: verify, push, reply to reviewers
  |
  +-- Phase 2: Poll for new issues (bug + PPL + good-for-agent)
  |   +-- For each unhandled issue:
  |       +-- Create status files, git worktree
  |       +-- Launch: claude -p "<prompt>" -d <worktree>
  |             +-- TeamCreate("ppl-dev-{number}")
  |             +-- developer: RCA -> fix -> test -> commit
  |             +-- leader: review -> feedback -> push -> PR
  |
  +-- Sync summary.md again
  +-- Sleep 5m
  +-- Loop...
```

## Directory Structure

```
skills/opensearch-ppl-developer/
  SKILL.md                                    # Agent team skill definition
  README.md                                   # This file
  scripts/
    ppl-developer.sh                          # Outer loop bash script
  references/
    ppl-developer-prompt.md                   # Prompt template for new issues
    ppl-developer-pr-maintain-prompt.md       # Prompt template for PR maintenance

/home/ec2-user/ppl-team/                      # Runtime status tracking
  summary.md                                  # Overall status table (auto-synced)
  ppl-developer.pid                           # PID file for the outer loop
  issues/
    issue-{number}.md                         # Per-issue detail and progress
  logs/
    ppl-developer.log                         # Outer loop log
    issue-{number}.log                        # Per-issue Claude session log
    issue-{number}-pr-maintain.log            # PR maintenance session log
```

## Quick Start

### Start the loop

```bash
# In background (recommended)
nohup bash scripts/ppl-developer.sh > /home/ec2-user/ppl-team/logs/ppl-developer.log 2>&1 &

# Or in a tmux session
tmux new -s ppl-dev
bash scripts/ppl-developer.sh
```

### Process a single issue

```bash
bash scripts/ppl-developer.sh --max-issues 1
```

### Dry run (see what would be processed)

```bash
bash scripts/ppl-developer.sh --dry-run
```

### Stop the loop

```bash
kill $(cat /home/ec2-user/ppl-team/ppl-developer.pid)
```

## Options

| Flag | Default | Description |
|------|---------|-------------|
| `--poll-interval SECONDS` | 300 | Seconds between GitHub polls |
| `--max-issues N` | 0 (unlimited) | Stop after processing N new issues |
| `--dry-run` | false | Show what would be processed without acting |

## Monitoring

### Check overall status

```bash
cat /home/ec2-user/ppl-team/summary.md
```

### Check a specific issue

```bash
cat /home/ec2-user/ppl-team/issues/issue-5178.md
```

### Watch the outer loop log

```bash
tail -f /home/ec2-user/ppl-team/logs/ppl-developer.log
```

### Watch a specific Claude session

```bash
tail -f /home/ec2-user/ppl-team/logs/issue-5178.log
```

## Status Values

| Status | Meaning |
|--------|---------|
| `PENDING` | Issue recorded, worktree being set up |
| `IN_PROGRESS` | Claude session running (new issue fix) |
| `PR_SUBMITTED` | Pull request created (also used during PR maintenance) |
| `COMPLETED` | PR merged or issue resolved |
| `FAILED` | Agent could not fix the issue |

## Summary Auto-Sync

The `summary.md` file is automatically rebuilt from the individual `issues/issue-*.md` files on every poll cycle. This means:
- Agents only need to update the per-issue files
- `summary.md` always reflects the true state of issue files
- No more stale status (e.g., showing IN_PROGRESS when PR is already submitted)

## Git Setup

The system uses a fork-based workflow:

- **Fork remote (`origin`):** `opensearchpplteam/sql.git` - push target
- **Upstream remote:** `opensearch-project/sql.git` - PR target
- **Branch:** `fix/issue-{number}` created from `origin/main`
- **Worktree:** `/home/ec2-user/oss/sql-issue-{number}`
- **PRs:** Created via `gh pr create -R opensearch-project/sql --head opensearchpplteam:fix/issue-{number}`

## Prerequisites

- `gh` CLI authenticated with access to `opensearch-project/sql` and `opensearchpplteam/sql`
- `claude` CLI installed and configured
- Git repository at `/home/ec2-user/oss/ppl` with `origin` pointing to the fork
- `jq` installed for JSON parsing
