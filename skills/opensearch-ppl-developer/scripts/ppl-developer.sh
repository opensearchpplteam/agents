#!/usr/bin/env bash
# ppl-developer.sh - Outer loop that polls GitHub issues and open PRs, launching
# Claude sessions to fix new issues and maintain existing PRs (address review
# comments, fix CI failures).
#
# Usage:
#   nohup bash ppl-developer.sh > /home/ec2-user/ppl-team/logs/ppl-developer.log 2>&1 &
#   bash ppl-developer.sh --dry-run
#   bash ppl-developer.sh --max-issues 1
#   kill $(cat /home/ec2-user/ppl-team/ppl-developer.pid)

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
REPO="opensearch-project/sql"
FORK_REPO="opensearchpplteam/sql"
FORK_USER="opensearchpplteam"
LABELS=("bug" "PPL" "good-for-agent")
POLL_INTERVAL=300
MAX_ISSUES=0  # 0 = unlimited
DRY_RUN=false

STATUS_DIR="/home/ec2-user/ppl-team"
SUMMARY_FILE="$STATUS_DIR/summary.md"
ISSUES_DIR="$STATUS_DIR/issues"
LOGS_DIR="$STATUS_DIR/logs"
PID_FILE="$STATUS_DIR/ppl-developer.pid"

WORKTREE_BASE="/home/ec2-user/oss"
SOURCE_REPO="/home/ec2-user/oss/ppl"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROMPT_TEMPLATE="$SKILL_DIR/references/ppl-developer-prompt.md"
PR_MAINTAIN_PROMPT_TEMPLATE="$SKILL_DIR/references/ppl-developer-pr-maintain-prompt.md"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --poll-interval)
            POLL_INTERVAL="$2"; shift 2 ;;
        --max-issues)
            MAX_ISSUES="$2"; shift 2 ;;
        --dry-run)
            DRY_RUN=true; shift ;;
        --help|-h)
            echo "Usage: $0 [--poll-interval SECONDS] [--max-issues N] [--dry-run]"
            exit 0 ;;
        *)
            echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

# ---------------------------------------------------------------------------
# Directory setup
# ---------------------------------------------------------------------------
mkdir -p "$ISSUES_DIR" "$LOGS_DIR"

# ---------------------------------------------------------------------------
# PID file and signal handling
# ---------------------------------------------------------------------------
SHUTDOWN_REQUESTED=false

cleanup() {
    log "Shutdown requested, cleaning up..."
    SHUTDOWN_REQUESTED=true
}

trap cleanup SIGTERM SIGINT

echo $$ > "$PID_FILE"
log "PID $$ written to $PID_FILE"

# ---------------------------------------------------------------------------
# Summary sync: rebuild summary.md from issues/ folder
# ---------------------------------------------------------------------------
sync_summary_from_issues() {
    local header
    header=$(cat <<'EOF'
# PPL Developer Status Summary

| Issue | Title | Status | PR | Branch | Started | Updated |
|-------|-------|--------|----|--------|---------|---------|
EOF
)

    local rows=""
    for issue_file in "$ISSUES_DIR"/issue-*.md; do
        [[ -f "$issue_file" ]] || continue

        local number title status pr_number branch started_at updated_at
        number=$(grep '^issue:' "$issue_file" | head -1 | sed 's/^issue: *//')
        title=$(grep '^title:' "$issue_file" | head -1 | sed 's/^title: *"//;s/"$//')
        status=$(grep '^status:' "$issue_file" | head -1 | sed 's/^status: *//')
        pr_number=$(grep '^pr_number:' "$issue_file" | head -1 | sed 's/^pr_number: *//')
        branch=$(grep '^branch:' "$issue_file" | head -1 | sed 's/^branch: *//')
        started_at=$(grep '^started_at:' "$issue_file" | head -1 | sed 's/^started_at: *"//;s/"$//' | cut -c1-10)
        updated_at=$(grep '^updated_at:' "$issue_file" | head -1 | sed 's/^updated_at: *"//;s/"$//' | cut -c1-10)

        # Format PR column
        local pr_col="-"
        if [[ "$pr_number" != "null" && -n "$pr_number" ]]; then
            pr_col="[#${pr_number}](https://github.com/${REPO}/pull/${pr_number})"
        fi

        # Truncate title for table readability
        local short_title="${title:0:60}"

        rows="${rows}| #${number} | ${short_title} | ${status} | ${pr_col} | ${branch} | ${started_at} | ${updated_at} |
"
    done

    printf '%s\n%s' "$header" "$rows" > "$SUMMARY_FILE"
    log "Synced summary.md from ${ISSUES_DIR}/ ($(echo "$rows" | grep -c '^|' || echo 0) issues)"
}

# ---------------------------------------------------------------------------
# Status helpers
# ---------------------------------------------------------------------------
get_issue_status() {
    local number="$1"
    if [[ -f "$ISSUES_DIR/issue-${number}.md" ]]; then
        grep '^status:' "$ISSUES_DIR/issue-${number}.md" | head -1 | sed 's/^status: *//'
    else
        echo "UNHANDLED"
    fi
}

get_issue_pr_number() {
    local number="$1"
    if [[ -f "$ISSUES_DIR/issue-${number}.md" ]]; then
        grep '^pr_number:' "$ISSUES_DIR/issue-${number}.md" | head -1 | sed 's/^pr_number: *//'
    else
        echo "null"
    fi
}

update_issue_status() {
    local number="$1"
    local new_status="$2"
    local issue_file="$ISSUES_DIR/issue-${number}.md"
    local now
    now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    if [[ -f "$issue_file" ]]; then
        sed -i "s/^status: .*/status: $new_status/" "$issue_file"
        sed -i "s/^updated_at: .*/updated_at: \"$now\"/" "$issue_file"
    fi

    # Summary will be synced at next cycle start via sync_summary_from_issues
}

update_issue_pr() {
    local number="$1"
    local pr_number="$2"
    local issue_file="$ISSUES_DIR/issue-${number}.md"
    local now
    now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    if [[ -f "$issue_file" ]]; then
        sed -i "s/^pr_number: .*/pr_number: $pr_number/" "$issue_file"
        sed -i "s/^updated_at: .*/updated_at: \"$now\"/" "$issue_file"
    fi
}

create_issue_record() {
    local number="$1"
    local title="$2"
    local body="$3"
    local branch="fix/issue-${number}"
    local worktree="$WORKTREE_BASE/sql-issue-${number}"
    local now
    now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    # Create per-issue status file
    cat > "$ISSUES_DIR/issue-${number}.md" <<EOF
---
issue: ${number}
title: "${title}"
status: PENDING
pr_number: null
branch: ${branch}
worktree: ${worktree}
started_at: "${now}"
updated_at: "${now}"
---

## Issue Description

${body}

## RCA

(pending - will be filled by developer agent)

## Changes Made

(pending - will be filled by developer agent)

## Test Results

(pending - will be filled by developer agent)

## Review Notes

(pending - will be filled by leader agent)

## PR

(pending - will be filled by leader agent)
EOF

    log "Created issue record for #${number}"
}

# ---------------------------------------------------------------------------
# Git worktree setup
# ---------------------------------------------------------------------------
setup_worktree() {
    local number="$1"
    local branch="fix/issue-${number}"
    local worktree="$WORKTREE_BASE/sql-issue-${number}"

    if [[ -d "$worktree" ]]; then
        log "Worktree already exists at $worktree, pulling latest"
        git -C "$worktree" fetch origin 2>/dev/null || true
        return 0
    fi

    log "Setting up worktree for issue #${number} at $worktree"

    # Fetch latest from origin
    git -C "$SOURCE_REPO" fetch origin main 2>/dev/null || true

    # Create worktree with new branch from origin/main
    git -C "$SOURCE_REPO" worktree add -b "$branch" "$worktree" origin/main 2>/dev/null || {
        # Branch might already exist
        git -C "$SOURCE_REPO" worktree add "$worktree" "$branch" 2>/dev/null || {
            log_error "Failed to create worktree for issue #${number}"
            return 1
        }
    }

    log "Worktree created at $worktree on branch $branch"
}

# ---------------------------------------------------------------------------
# Launch Claude session for a new issue
# ---------------------------------------------------------------------------
launch_claude_session() {
    local number="$1"
    local title="$2"
    local body="$3"
    local worktree="$WORKTREE_BASE/sql-issue-${number}"
    local log_file="$LOGS_DIR/issue-${number}.log"

    if [[ ! -f "$PROMPT_TEMPLATE" ]]; then
        log_error "Prompt template not found: $PROMPT_TEMPLATE"
        return 1
    fi

    local prompt
    prompt=$(cat "$PROMPT_TEMPLATE")
    prompt="${prompt//\{NUMBER\}/$number}"
    prompt="${prompt//\{TITLE\}/$title}"
    prompt="${prompt//\{WORKTREE\}/$worktree}"
    # Body can contain special chars, use a temp file approach
    local body_escaped
    body_escaped=$(printf '%s' "$body" | sed 's/[&/\]/\\&/g')
    prompt="${prompt//\{BODY\}/$body_escaped}"

    log "Launching Claude session for issue #${number}"
    update_issue_status "$number" "IN_PROGRESS"

    # Launch Claude CLI
    claude -p "$prompt" \
        --dangerously-skip-permissions \
        -d "$worktree" \
        2>&1 | tee "$log_file"

    local exit_code=${PIPESTATUS[0]}

    log "Claude session for issue #${number} exited with code $exit_code"

    # Determine outcome from status file (agent updates it) or exit code
    local final_status
    final_status=$(get_issue_status "$number")

    if [[ "$final_status" == "PR_SUBMITTED" || "$final_status" == "COMPLETED" ]]; then
        log "Issue #${number}: PR submitted successfully"
    elif [[ "$final_status" == "IN_PROGRESS" ]]; then
        # Agent didn't update status - check if there's a PR
        if grep -q "PR_SUBMITTED\|pull request" "$log_file" 2>/dev/null; then
            update_issue_status "$number" "PR_SUBMITTED"
            log "Issue #${number}: PR submitted (detected from log)"
        else
            update_issue_status "$number" "FAILED"
            log_error "Issue #${number}: Session ended without completing"
        fi
    fi

    return $exit_code
}

# ---------------------------------------------------------------------------
# PR maintenance: check open PRs and spawn sessions to address activity
# ---------------------------------------------------------------------------
get_pr_latest_activity() {
    local pr_number="$1"

    # Get PR check runs status
    local checks_json
    checks_json=$(gh pr checks "$pr_number" -R "$REPO" --json name,state,conclusion 2>/dev/null) || checks_json="[]"

    local failed_checks
    failed_checks=$(echo "$checks_json" | jq -r '[.[] | select(.conclusion == "FAILURE" or .conclusion == "failure")] | length' 2>/dev/null) || failed_checks="0"

    # Get review comments since last update
    local issue_number
    issue_number=$(gh pr view "$pr_number" -R "$REPO" --json body -q '.body' 2>/dev/null | grep -oP '#\K[0-9]+' | head -1) || issue_number=""

    local last_updated="1970-01-01T00:00:00Z"
    if [[ -n "$issue_number" && -f "$ISSUES_DIR/issue-${issue_number}.md" ]]; then
        last_updated=$(grep '^updated_at:' "$ISSUES_DIR/issue-${issue_number}.md" | head -1 | sed 's/^updated_at: *"//;s/"$//')
    fi

    # Get review comments
    local comments_json
    comments_json=$(gh api "repos/${REPO}/pulls/${pr_number}/comments" --jq "[.[] | select(.updated_at > \"${last_updated}\")] | length" 2>/dev/null) || comments_json="0"

    # Get issue comments on the PR (reviews, general comments)
    local review_comments
    review_comments=$(gh api "repos/${REPO}/pulls/${pr_number}/reviews" --jq "[.[] | select(.submitted_at > \"${last_updated}\" and .state != \"APPROVED\" and .user.login != \"${FORK_USER}\")] | length" 2>/dev/null) || review_comments="0"

    # Get general PR comments (issue-style)
    local pr_comments
    pr_comments=$(gh api "repos/${REPO}/issues/${pr_number}/comments" --jq "[.[] | select(.updated_at > \"${last_updated}\" and .user.login != \"${FORK_USER}\")] | length" 2>/dev/null) || pr_comments="0"

    echo "${failed_checks}:${comments_json}:${review_comments}:${pr_comments}"
}

check_open_prs() {
    log "Checking open PRs by ${FORK_USER} for maintenance"

    local prs_json
    prs_json=$(gh pr list -R "$REPO" --author "$FORK_USER" --state open \
        --json number,title,headRefName,updatedAt --limit 50 2>/dev/null) || {
        log_error "Failed to fetch open PRs"
        return 1
    }

    local pr_count
    pr_count=$(echo "$prs_json" | jq length)
    log "Found $pr_count open PRs by ${FORK_USER}"

    if [[ "$pr_count" -eq 0 ]]; then
        return 0
    fi

    for i in $(seq 0 $((pr_count - 1))); do
        if [[ "$SHUTDOWN_REQUESTED" == true ]]; then
            break
        fi

        local pr_number pr_title pr_branch
        pr_number=$(echo "$prs_json" | jq -r ".[$i].number")
        pr_title=$(echo "$prs_json" | jq -r ".[$i].title")
        pr_branch=$(echo "$prs_json" | jq -r ".[$i].headRefName")

        # Extract issue number from branch name (fix/issue-NNNN)
        local issue_number
        issue_number=$(echo "$pr_branch" | grep -oP 'issue-\K[0-9]+' || echo "")

        if [[ -z "$issue_number" ]]; then
            log "PR #${pr_number} (${pr_branch}): cannot determine issue number, skipping"
            continue
        fi

        local current_status
        current_status=$(get_issue_status "$issue_number")

        if [[ "$current_status" == "COMPLETED" ]]; then
            log "PR #${pr_number} (issue #${issue_number}): already completed, skipping"
            continue
        fi

        # Check for new activity that needs attention
        local activity
        activity=$(get_pr_latest_activity "$pr_number")
        local failed_checks inline_comments review_comments pr_comments
        IFS=':' read -r failed_checks inline_comments review_comments pr_comments <<< "$activity"

        local needs_attention=false
        local reasons=""

        if [[ "$failed_checks" -gt 0 ]]; then
            needs_attention=true
            reasons="${reasons}${failed_checks} failed CI checks; "
        fi
        if [[ "$inline_comments" -gt 0 ]]; then
            needs_attention=true
            reasons="${reasons}${inline_comments} new inline comments; "
        fi
        if [[ "$review_comments" -gt 0 ]]; then
            needs_attention=true
            reasons="${reasons}${review_comments} new reviews; "
        fi
        if [[ "$pr_comments" -gt 0 ]]; then
            needs_attention=true
            reasons="${reasons}${pr_comments} new PR comments; "
        fi

        if [[ "$needs_attention" == false ]]; then
            log "PR #${pr_number} (issue #${issue_number}): no new activity, skipping"
            continue
        fi

        # Remove trailing "; "
        reasons="${reasons%%; }"

        if [[ "$DRY_RUN" == true ]]; then
            log "[DRY RUN] Would maintain PR #${pr_number} (issue #${issue_number}): ${reasons}"
            continue
        fi

        log "PR #${pr_number} (issue #${issue_number}) needs attention: ${reasons}"

        # Ensure worktree exists
        if ! setup_worktree "$issue_number"; then
            log_error "Failed to set up worktree for PR maintenance (issue #${issue_number})"
            continue
        fi

        # Launch PR maintenance session
        launch_pr_maintain_session "$pr_number" "$issue_number" "$pr_title" "$reasons" || {
            log_error "PR maintenance session failed for PR #${pr_number}"
        }
    done
}

launch_pr_maintain_session() {
    local pr_number="$1"
    local issue_number="$2"
    local pr_title="$3"
    local reasons="$4"
    local worktree="$WORKTREE_BASE/sql-issue-${issue_number}"
    local log_file="$LOGS_DIR/issue-${issue_number}-pr-maintain.log"

    if [[ ! -f "$PR_MAINTAIN_PROMPT_TEMPLATE" ]]; then
        log_error "PR maintenance prompt template not found: $PR_MAINTAIN_PROMPT_TEMPLATE"
        return 1
    fi

    local prompt
    prompt=$(cat "$PR_MAINTAIN_PROMPT_TEMPLATE")
    prompt="${prompt//\{PR_NUMBER\}/$pr_number}"
    prompt="${prompt//\{NUMBER\}/$issue_number}"
    prompt="${prompt//\{TITLE\}/$pr_title}"
    prompt="${prompt//\{WORKTREE\}/$worktree}"
    prompt="${prompt//\{REASONS\}/$reasons}"

    log "Launching PR maintenance session for PR #${pr_number} (issue #${issue_number})"

    claude -p "$prompt" \
        --dangerously-skip-permissions \
        -d "$worktree" \
        2>&1 | tee "$log_file"

    local exit_code=${PIPESTATUS[0]}

    log "PR maintenance session for PR #${pr_number} exited with code $exit_code"

    # Update timestamp so next cycle won't re-trigger for same activity
    update_issue_status "$issue_number" "PR_SUBMITTED"

    return $exit_code
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
main() {
    local issues_processed=0

    log "PPL Developer started (poll_interval=${POLL_INTERVAL}s, max_issues=${MAX_ISSUES}, dry_run=${DRY_RUN})"

    while true; do
        if [[ "$SHUTDOWN_REQUESTED" == true ]]; then
            log "Shutdown flag set, exiting main loop"
            break
        fi

        # ---- Sync summary.md from issues/ on every cycle ----
        sync_summary_from_issues

        # ---- Phase 1: Check open PRs for maintenance ----
        check_open_prs || true

        if [[ "$SHUTDOWN_REQUESTED" == true ]]; then
            break
        fi

        # ---- Phase 2: Poll for new issues ----
        log "Polling for issues from $REPO with labels: ${LABELS[*]}"

        # Build label flags
        local label_flags=""
        for label in "${LABELS[@]}"; do
            label_flags="$label_flags --label \"$label\""
        done

        # Fetch open issues
        local issues_json
        issues_json=$(eval gh issue list -R "$REPO" $label_flags --state open --json number,title,body --limit 50 2>/dev/null) || {
            log_error "Failed to fetch issues from GitHub"
            sleep "$POLL_INTERVAL"
            continue
        }

        local issue_count
        issue_count=$(echo "$issues_json" | jq length)
        log "Found $issue_count matching issues"

        local had_work=false

        if [[ "$issue_count" -gt 0 ]]; then
            for i in $(seq 0 $((issue_count - 1))); do
                if [[ "$SHUTDOWN_REQUESTED" == true ]]; then
                    break
                fi

                local number title body
                number=$(echo "$issues_json" | jq -r ".[$i].number")
                title=$(echo "$issues_json" | jq -r ".[$i].title")
                body=$(echo "$issues_json" | jq -r ".[$i].body")

                # Check if already handled
                local status
                status=$(get_issue_status "$number")

                if [[ "$status" != "UNHANDLED" ]]; then
                    log "Issue #${number} already tracked (status: $status), skipping"
                    continue
                fi

                had_work=true

                if [[ "$DRY_RUN" == true ]]; then
                    log "[DRY RUN] Would process issue #${number}: $title"
                    issues_processed=$((issues_processed + 1))

                    if [[ "$MAX_ISSUES" -gt 0 && "$issues_processed" -ge "$MAX_ISSUES" ]]; then
                        log "[DRY RUN] Reached max issues ($MAX_ISSUES), stopping"
                        break 2
                    fi
                    continue
                fi

                log "Processing issue #${number}: $title"

                # Create tracking record
                create_issue_record "$number" "$title" "$body"

                # Set up worktree
                if ! setup_worktree "$number"; then
                    update_issue_status "$number" "FAILED"
                    log_error "Failed to set up worktree for issue #${number}"
                    continue
                fi

                # Launch Claude session (blocking - one at a time)
                launch_claude_session "$number" "$title" "$body" || {
                    local current_status
                    current_status=$(get_issue_status "$number")
                    if [[ "$current_status" != "PR_SUBMITTED" && "$current_status" != "COMPLETED" ]]; then
                        update_issue_status "$number" "FAILED"
                    fi
                    log_error "Claude session failed for issue #${number}"
                }

                issues_processed=$((issues_processed + 1))

                if [[ "$MAX_ISSUES" -gt 0 && "$issues_processed" -ge "$MAX_ISSUES" ]]; then
                    log "Reached max issues ($MAX_ISSUES), stopping"
                    break 2
                fi
            done
        fi

        if [[ "$DRY_RUN" == true ]]; then
            log "[DRY RUN] Complete."
            break
        fi

        # ---- Final sync before sleeping ----
        sync_summary_from_issues

        if [[ "$had_work" == false ]]; then
            log "No unhandled issues, sleeping ${POLL_INTERVAL}s"
        fi

        sleep "$POLL_INTERVAL" &
        wait $! 2>/dev/null || true  # Allow SIGTERM to interrupt sleep
    done

    # Final sync on shutdown
    sync_summary_from_issues

    log "PPL Developer shutting down. Processed $issues_processed issues."
    rm -f "$PID_FILE"
}

main
