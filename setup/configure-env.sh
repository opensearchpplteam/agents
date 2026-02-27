#!/usr/bin/env bash
#
# configure-env.sh - Configure shell environment (~/.bashrc additions)
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

BASHRC="$HOME/.bashrc"

# ── Idempotent append: only add a line if it's not already present ────
append_if_missing() {
    local line="$1"
    local comment="${2:-}"

    if grep -qF "$line" "$BASHRC" 2>/dev/null; then
        success "Already in .bashrc: ${line}"
    else
        if [ -n "$comment" ]; then
            echo "" >> "$BASHRC"
            echo "# ${comment}" >> "$BASHRC"
        fi
        echo "$line" >> "$BASHRC"
        success "Added to .bashrc: ${line}"
    fi
}

# ── Ensure ~/.local/bin is in PATH ────────────────────────────────────
ensure_local_bin_path() {
    # The default Amazon Linux .bashrc already includes ~/.local/bin,
    # but verify it just in case
    if grep -q 'HOME/.local/bin' "$BASHRC" 2>/dev/null; then
        success "~/.local/bin already in PATH via .bashrc"
    else
        append_if_missing 'export PATH="$HOME/.local/bin:$PATH"' "Local bin path"
    fi

    # Create the directory if it doesn't exist
    mkdir -p "$HOME/.local/bin"
}

# ── Main ──────────────────────────────────────────────────────────────
main() {
    info "Configuring shell environment..."

    # Backup .bashrc before modifying
    if [ -f "$BASHRC" ]; then
        cp "$BASHRC" "${BASHRC}.bak"
        info "Backed up .bashrc to .bashrc.bak"
    fi

    append_if_missing 'export AWS_REGION=us-west-2' "AWS Region for Bedrock"
    append_if_missing 'export AWS_PROFILE=bedrock-prod' "AWS Profile for Bedrock"
    ensure_local_bin_path

    echo ""
    info "Run 'source ~/.bashrc' or open a new terminal to apply changes."
}

main "$@"
