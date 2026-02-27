#!/usr/bin/env bash
#
# install-tools.sh - Install system packages for the PPL agent environment
#
# Packages: Java 21 (Corretto), git, tmux, gh (GitHub CLI), Node.js 22, bc
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

# ── Java 21 (Amazon Corretto) ────────────────────────────────────────
install_java() {
    if java --version 2>&1 | grep -q "21\."; then
        success "Java 21 already installed"
        return 0
    fi

    info "Installing Amazon Corretto 21..."
    sudo dnf install -y java-21-amazon-corretto-devel
    success "Java 21 installed: $(java --version 2>&1 | head -1)"
}

# ── Git ───────────────────────────────────────────────────────────────
install_git() {
    if command -v git &>/dev/null; then
        success "git already installed: $(git --version)"
        return 0
    fi

    info "Installing git..."
    sudo dnf install -y git
    success "git installed: $(git --version)"
}

# ── tmux ──────────────────────────────────────────────────────────────
install_tmux() {
    if command -v tmux &>/dev/null; then
        success "tmux already installed: $(tmux -V)"
        return 0
    fi

    info "Installing tmux..."
    sudo dnf install -y tmux
    success "tmux installed: $(tmux -V)"
}

# ── GitHub CLI ────────────────────────────────────────────────────────
install_gh() {
    if command -v gh &>/dev/null; then
        success "gh already installed: $(gh --version | head -1)"
        return 0
    fi

    info "Installing GitHub CLI..."
    sudo dnf install -y 'dnf-command(config-manager)'
    sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
    sudo dnf install -y gh
    success "gh installed: $(gh --version | head -1)"
}

# ── Node.js 22 ────────────────────────────────────────────────────────
install_node() {
    if command -v node &>/dev/null; then
        local node_major
        node_major=$(node --version | sed 's/v\([0-9]*\).*/\1/')
        if [ "$node_major" -ge 22 ] 2>/dev/null; then
            success "Node.js already installed: $(node --version)"
            return 0
        else
            warn "Node.js $(node --version) found, but need v22+. Upgrading..."
        fi
    fi

    info "Installing Node.js 22..."
    # Use NodeSource if dnf module not available
    if sudo dnf module list nodejs 2>/dev/null | grep -q "22"; then
        sudo dnf module enable -y nodejs:22
        sudo dnf install -y nodejs
    else
        # Fallback: install via NodeSource
        curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
        sudo dnf install -y nodejs
    fi

    success "Node.js installed: $(node --version)"
}

# ── bc (calculator for status line) ──────────────────────────────────
install_bc() {
    if command -v bc &>/dev/null; then
        success "bc already installed"
        return 0
    fi

    info "Installing bc..."
    sudo dnf install -y bc
    success "bc installed"
}

# ── Main ──────────────────────────────────────────────────────────────
main() {
    info "Installing system packages..."
    install_java
    install_git
    install_tmux
    install_gh
    install_node
    install_bc
    success "All system packages installed."
}

main "$@"
