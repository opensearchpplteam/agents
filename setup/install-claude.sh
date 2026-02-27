#!/usr/bin/env bash
#
# install-claude.sh - Install Claude Code CLI
#
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

install_claude() {
    # Check if already installed
    if command -v claude &>/dev/null; then
        local current_version
        current_version=$(claude --version 2>/dev/null || echo "unknown")
        success "Claude Code already installed: ${current_version}"
        info "To upgrade, run: npm update -g @anthropic-ai/claude-code"
        return 0
    fi

    # Ensure npm is available
    if ! command -v npm &>/dev/null; then
        error "npm not found. Please run install-tools.sh first to install Node.js."
        return 1
    fi

    info "Installing Claude Code via npm..."
    sudo npm install -g @anthropic-ai/claude-code

    # Verify installation
    if command -v claude &>/dev/null; then
        success "Claude Code installed: $(claude --version 2>/dev/null)"
    else
        # npm global bin might not be in PATH yet
        local npm_bin
        npm_bin="$(npm config get prefix)/bin"
        if [ -x "${npm_bin}/claude" ]; then
            success "Claude Code installed at ${npm_bin}/claude"
            info "You may need to add ${npm_bin} to your PATH or open a new terminal."
        else
            error "Claude Code installation failed. Check npm output above."
            return 1
        fi
    fi
}

main() {
    info "Installing Claude Code CLI..."
    install_claude
}

main "$@"
