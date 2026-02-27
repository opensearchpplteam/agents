#!/usr/bin/env bash
#
# configure-git.sh - Configure git identity and GitHub CLI authentication
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

# ── Git identity ──────────────────────────────────────────────────────
configure_git_identity() {
    local current_name current_email

    current_name=$(git config --global user.name 2>/dev/null || echo "")
    current_email=$(git config --global user.email 2>/dev/null || echo "")

    if [ -n "$current_name" ] && [ -n "$current_email" ]; then
        success "Git identity already configured:"
        info "  Name:  ${current_name}"
        info "  Email: ${current_email}"
        echo ""
        read -r -p "Keep current identity? [Y/n] " reply </dev/tty
        if [[ "$reply" =~ ^[Nn]$ ]]; then
            prompt_git_identity "$current_name" "$current_email"
        fi
    else
        prompt_git_identity "${current_name:-opensearchpplteam}" "${current_email:-opensearchpplteam@gmail.com}"
    fi

    # Configure SSH as default protocol for GitHub
    git config --global url."git@github.com:".insteadOf "https://github.com/"
    success "Configured SSH protocol for GitHub"
}

prompt_git_identity() {
    local default_name="$1"
    local default_email="$2"

    echo ""
    read -r -p "Git user name [${default_name}]: " git_name </dev/tty
    git_name="${git_name:-$default_name}"

    read -r -p "Git email [${default_email}]: " git_email </dev/tty
    git_email="${git_email:-$default_email}"

    git config --global user.name "$git_name"
    git config --global user.email "$git_email"
    success "Git identity set: ${git_name} <${git_email}>"
}

# ── GitHub SSH known hosts ───────────────────────────────────────────
ensure_github_known_host() {
    local known_hosts="$HOME/.ssh/known_hosts"

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    if [ -f "$known_hosts" ] && grep -q "github\.com" "$known_hosts" 2>/dev/null; then
        success "GitHub SSH host key already in known_hosts"
        return 0
    fi

    info "Adding GitHub SSH host key to known_hosts..."
    ssh-keyscan -t ed25519,rsa github.com >> "$known_hosts" 2>/dev/null
    chmod 600 "$known_hosts"
    success "Added GitHub SSH host key to known_hosts"
}

# ── GitHub CLI auth ───────────────────────────────────────────────────
configure_gh_auth() {
    if ! command -v gh &>/dev/null; then
        error "gh (GitHub CLI) not found. Please run install-tools.sh first."
        return 1
    fi

    if gh auth status &>/dev/null; then
        success "GitHub CLI already authenticated:"
        gh auth status 2>&1 | while IFS= read -r line; do
            info "  $line"
        done
        return 0
    fi

    warn "GitHub CLI is not authenticated."
    info "Starting interactive login..."
    echo ""
    gh auth login -p ssh -h github.com </dev/tty

    if gh auth status &>/dev/null; then
        success "GitHub CLI authenticated successfully."
    else
        error "GitHub CLI authentication failed."
        info "You can retry later with: gh auth login -p ssh -h github.com"
        return 1
    fi
}

# ── Main ──────────────────────────────────────────────────────────────
main() {
    info "Configuring Git & GitHub..."
    configure_git_identity
    echo ""
    ensure_github_known_host
    echo ""
    configure_gh_auth
}

main "$@"
