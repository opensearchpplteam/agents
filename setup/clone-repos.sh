#!/usr/bin/env bash
#
# clone-repos.sh - Clone repositories and set up skills symlinks
#
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

OSS_DIR="$HOME/oss"

# ── Clone a repo if not already present ───────────────────────────────
clone_repo() {
    local repo_url="$1"
    local target_dir="$2"
    local repo_name

    repo_name=$(basename "$repo_url" .git)

    if [ -d "$target_dir/.git" ]; then
        success "${repo_name} already cloned at ${target_dir}"
        info "Pulling latest changes..."
        (cd "$target_dir" && git pull --ff-only 2>/dev/null) || warn "Could not pull (you may have local changes)"
        return 0
    fi

    # If the directory exists but is not a git repo, warn
    if [ -d "$target_dir" ] && [ "$(ls -A "$target_dir" 2>/dev/null)" ]; then
        warn "${target_dir} exists and is not empty. Skipping clone."
        return 0
    fi

    info "Cloning ${repo_url} → ${target_dir}"
    git clone "$repo_url" "$target_dir"
    success "Cloned ${repo_name}"
}

# ── Set up skills symlinks ────────────────────────────────────────────
setup_skills() {
    local ppl_skills_dir="${OSS_DIR}/ppl/.claude/skills"
    local agents_skills_dir="${OSS_DIR}/agents/skills"

    info "Setting up skills symlinks..."

    mkdir -p "$ppl_skills_dir"

    if [ ! -d "$agents_skills_dir" ]; then
        error "Skills directory not found: ${agents_skills_dir}"
        error "Make sure the agents repo was cloned successfully."
        return 1
    fi

    # Symlink: opensearch-ppl-developer
    local skill1_target="${agents_skills_dir}/opensearch-ppl-developer"
    local skill1_link="${ppl_skills_dir}/opensearch-ppl-developer"

    if [ -L "$skill1_link" ]; then
        # Update existing symlink if it points to the old location
        local current_target
        current_target=$(readlink "$skill1_link")
        if [[ "$current_target" == *"treasuretoken"* ]]; then
            rm "$skill1_link"
            ln -s "$skill1_target" "$skill1_link"
            success "Updated symlink: opensearch-ppl-developer (was pointing to treasuretoken)"
        else
            success "Symlink already exists: opensearch-ppl-developer"
        fi
    elif [ -d "$skill1_target" ]; then
        ln -s "$skill1_target" "$skill1_link"
        success "Created symlink: opensearch-ppl-developer"
    else
        warn "Source not found: ${skill1_target}"
    fi

    # Symlink: opensearch-sql-pr-review
    local skill2_target="${agents_skills_dir}/opensearch-sql-pr-review"
    local skill2_link="${ppl_skills_dir}/opensearch-sql-pr-review"

    if [ -L "$skill2_link" ]; then
        local current_target
        current_target=$(readlink "$skill2_link")
        if [[ "$current_target" == *"treasuretoken"* ]]; then
            rm "$skill2_link"
            ln -s "$skill2_target" "$skill2_link"
            success "Updated symlink: opensearch-sql-pr-review (was pointing to treasuretoken)"
        else
            success "Symlink already exists: opensearch-sql-pr-review"
        fi
    elif [ -d "$skill2_target" ]; then
        ln -s "$skill2_target" "$skill2_link"
        success "Created symlink: opensearch-sql-pr-review"
    else
        warn "Source not found: ${skill2_target}"
    fi
}

# ── Main ──────────────────────────────────────────────────────────────
main() {
    info "Cloning repositories..."
    mkdir -p "$OSS_DIR"

    clone_repo "git@github.com:opensearchpplteam/sql.git"    "${OSS_DIR}/ppl"
    clone_repo "git@github.com:opensearchpplteam/agents.git" "${OSS_DIR}/agents"

    echo ""
    setup_skills
}

main "$@"
