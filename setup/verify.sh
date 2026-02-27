#!/usr/bin/env bash
#
# verify.sh - Validate all components of the PPL agent environment
#
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
WARN_COUNT=0

pass() { echo -e "  ${GREEN}PASS${NC}  $*"; ((PASS++)); }
fail() { echo -e "  ${RED}FAIL${NC}  $*"; ((FAIL++)); }
skip() { echo -e "  ${YELLOW}WARN${NC}  $*"; ((WARN_COUNT++)); }

# ── Checks ────────────────────────────────────────────────────────────
check_java() {
    if java --version 2>&1 | grep -q "21\."; then
        pass "Java 21  $(java --version 2>&1 | head -1)"
    else
        fail "Java 21 not found"
    fi
}

check_git() {
    if command -v git &>/dev/null; then
        pass "git      $(git --version)"
    else
        fail "git not found"
    fi
}

check_tmux() {
    if command -v tmux &>/dev/null; then
        pass "tmux     $(tmux -V)"
    else
        fail "tmux not found"
    fi
}

check_gh() {
    if command -v gh &>/dev/null; then
        pass "gh       $(gh --version | head -1)"
    else
        fail "gh (GitHub CLI) not found"
    fi
}

check_node() {
    if command -v node &>/dev/null; then
        pass "node     $(node --version)"
    else
        fail "Node.js not found"
    fi
}

check_claude() {
    if command -v claude &>/dev/null; then
        pass "claude   $(claude --version 2>/dev/null || echo 'installed')"
    else
        fail "Claude Code not found"
    fi
}

check_gh_auth() {
    if gh auth status &>/dev/null 2>&1; then
        pass "gh auth  authenticated"
    else
        skip "gh auth  not authenticated (run: gh auth login)"
    fi
}

check_repo() {
    local name="$1"
    local path="$2"

    if [ -d "$path/.git" ]; then
        pass "repo     ${name} (${path})"
    else
        fail "repo     ${name} not found at ${path}"
    fi
}

check_skills() {
    local skills_dir="$HOME/oss/ppl/.claude/skills"

    if [ -L "${skills_dir}/opensearch-ppl-developer" ] && [ -e "${skills_dir}/opensearch-ppl-developer" ]; then
        pass "skill    opensearch-ppl-developer"
    elif [ -L "${skills_dir}/opensearch-ppl-developer" ]; then
        fail "skill    opensearch-ppl-developer (broken symlink)"
    else
        fail "skill    opensearch-ppl-developer (missing)"
    fi

    if [ -L "${skills_dir}/opensearch-sql-pr-review" ] && [ -e "${skills_dir}/opensearch-sql-pr-review" ]; then
        pass "skill    opensearch-sql-pr-review"
    elif [ -L "${skills_dir}/opensearch-sql-pr-review" ]; then
        fail "skill    opensearch-sql-pr-review (broken symlink)"
    else
        fail "skill    opensearch-sql-pr-review (missing)"
    fi
}

check_claude_settings() {
    local settings="$HOME/.claude/settings.json"

    if [ ! -f "$settings" ]; then
        fail "settings ~/.claude/settings.json not found"
        return
    fi

    # Check key fields exist in the settings
    if grep -q "CLAUDE_CODE_USE_BEDROCK" "$settings" && \
       grep -q "bedrock-prod" "$settings" && \
       grep -q "alwaysThinkingEnabled" "$settings"; then
        pass "settings ~/.claude/settings.json (Bedrock config present)"
    else
        skip "settings ~/.claude/settings.json exists but may be incomplete"
    fi
}

check_bashrc_env() {
    if grep -q 'AWS_REGION=us-west-2' "$HOME/.bashrc" 2>/dev/null; then
        pass "bashrc   AWS_REGION=us-west-2"
    else
        fail "bashrc   AWS_REGION not set"
    fi

    if grep -q 'AWS_PROFILE=bedrock-prod' "$HOME/.bashrc" 2>/dev/null; then
        pass "bashrc   AWS_PROFILE=bedrock-prod"
    else
        fail "bashrc   AWS_PROFILE not set"
    fi
}

check_directories() {
    local dirs=(
        "$HOME/oss"
        "$HOME/ppl-team/issues"
        "$HOME/ppl-team/logs"
        "$HOME/ppl-team/review"
    )

    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            pass "dir      ${dir}"
        else
            fail "dir      ${dir} (missing)"
        fi
    done
}

# ── Main ──────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${BOLD}Verification Results${NC}"
    echo -e "${BOLD}────────────────────────────────────────────${NC}"
    echo ""

    echo -e "${BOLD}System Tools:${NC}"
    check_java
    check_git
    check_tmux
    check_gh
    check_node
    check_claude
    echo ""

    echo -e "${BOLD}Authentication:${NC}"
    check_gh_auth
    echo ""

    echo -e "${BOLD}Repositories:${NC}"
    check_repo "sql (ppl)"      "$HOME/oss/ppl"
    check_repo "agents"         "$HOME/oss/agents"
    echo ""

    echo -e "${BOLD}Skills:${NC}"
    check_skills
    echo ""

    echo -e "${BOLD}Configuration:${NC}"
    check_claude_settings
    check_bashrc_env
    echo ""

    echo -e "${BOLD}Directories:${NC}"
    check_directories
    echo ""

    # Summary
    echo -e "${BOLD}────────────────────────────────────────────${NC}"
    echo -e "  ${GREEN}Passed: ${PASS}${NC}  ${RED}Failed: ${FAIL}${NC}  ${YELLOW}Warnings: ${WARN_COUNT}${NC}"
    echo -e "${BOLD}────────────────────────────────────────────${NC}"
    echo ""

    if [ "$FAIL" -gt 0 ]; then
        return 1
    fi
    return 0
}

main "$@"
