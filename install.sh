#!/usr/bin/env bash
#
# PPL Team Agent Environment - One-Line Installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/opensearchpplteam/agents/main/install.sh | bash
#
# This script downloads and runs the modular setup scripts to provision
# a full agent development environment on Amazon Linux 2023.
#
set -euo pipefail

# ── Colors & helpers ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }
step()    { echo -e "\n${BOLD}══════════════════════════════════════════${NC}"; \
            echo -e "${BOLD}  $*${NC}"; \
            echo -e "${BOLD}══════════════════════════════════════════${NC}\n"; }

# ── OS detection ──────────────────────────────────────────────────────
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "${ID:-}" == "amzn" && "${VERSION_ID:-}" == "2023" ]]; then
            info "Detected Amazon Linux 2023"
        else
            warn "Expected Amazon Linux 2023, detected: ${PRETTY_NAME:-unknown}"
            warn "Some package installation steps may not work correctly."
            read -r -p "Continue anyway? [y/N] " reply
            if [[ ! "$reply" =~ ^[Yy]$ ]]; then
                error "Aborted by user."
                exit 1
            fi
        fi
    else
        warn "Cannot detect OS (no /etc/os-release). Proceeding with caution."
    fi
}

# ── Directory structure ───────────────────────────────────────────────
create_directories() {
    step "Creating directory structure"

    local dirs=(
        "$HOME/oss"
        "$HOME/oss/ppl"
        "$HOME/ppl-team/issues"
        "$HOME/ppl-team/logs"
        "$HOME/ppl-team/review"
    )

    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            success "$dir (already exists)"
        else
            mkdir -p "$dir"
            success "$dir"
        fi
    done
}

# ── Download setup scripts ────────────────────────────────────────────
GITHUB_RAW_BASE="https://raw.githubusercontent.com/opensearchpplteam/agents/main"
SETUP_DIR="$(mktemp -d)/setup"

download_scripts() {
    step "Downloading setup scripts"

    mkdir -p "$SETUP_DIR"

    local scripts=(
        install-tools.sh
        install-claude.sh
        configure-claude.sh
        configure-git.sh
        clone-repos.sh
        configure-env.sh
        verify.sh
    )

    for script in "${scripts[@]}"; do
        local url="${GITHUB_RAW_BASE}/setup/${script}"
        local dest="${SETUP_DIR}/${script}"

        if curl -fsSL "$url" -o "$dest" 2>/dev/null; then
            chmod +x "$dest"
            success "Downloaded ${script}"
        else
            error "Failed to download ${script} from ${url}"
            error "Check your network connection and that the repo is accessible."
            exit 1
        fi
    done
}

# ── Run a setup script with error handling ────────────────────────────
run_script() {
    local script_name="$1"
    local script_path="${SETUP_DIR}/${script_name}"

    if [ ! -x "$script_path" ]; then
        error "Script not found or not executable: ${script_path}"
        return 1
    fi

    if bash "$script_path"; then
        success "Completed: ${script_name}"
        return 0
    else
        error "Failed: ${script_name}"
        error "You can re-run this step individually after fixing the issue."
        return 1
    fi
}

# ── Main ──────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║   PPL Team Agent Environment Installer           ║${NC}"
    echo -e "${BOLD}║   OpenSearch PPL Team                            ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
    echo ""

    detect_os
    create_directories
    download_scripts

    local failed=()

    # 1. System packages
    step "Step 1/7: Installing system packages"
    run_script "install-tools.sh" || failed+=("install-tools.sh")

    # 2. Claude Code
    step "Step 2/7: Installing Claude Code"
    run_script "install-claude.sh" || failed+=("install-claude.sh")

    # 3. Claude configuration
    step "Step 3/7: Configuring Claude Code"
    run_script "configure-claude.sh" || failed+=("configure-claude.sh")

    # 4. Git & GitHub (interactive)
    step "Step 4/7: Configuring Git & GitHub"
    run_script "configure-git.sh" || failed+=("configure-git.sh")

    # 5. Clone repositories
    step "Step 5/7: Cloning repositories & setting up skills"
    run_script "clone-repos.sh" || failed+=("clone-repos.sh")

    # 6. Shell environment
    step "Step 6/7: Configuring shell environment"
    run_script "configure-env.sh" || failed+=("configure-env.sh")

    # 7. Verification
    step "Step 7/7: Verifying installation"
    run_script "verify.sh" || failed+=("verify.sh")

    # ── Summary ───────────────────────────────────────────────────────
    echo ""
    echo -e "${BOLD}══════════════════════════════════════════${NC}"
    echo -e "${BOLD}  Installation Summary${NC}"
    echo -e "${BOLD}══════════════════════════════════════════${NC}"
    echo ""

    if [ ${#failed[@]} -eq 0 ]; then
        success "All steps completed successfully!"
    else
        warn "The following steps had issues:"
        for f in "${failed[@]}"; do
            error "  - ${f}"
        done
        echo ""
        info "You can re-run individual scripts from: ${SETUP_DIR}/"
    fi

    echo ""
    info "Next steps:"
    info "  1. Open a new terminal (or run: source ~/.bashrc)"
    info "  2. Run 'java --version' to verify Java 21"
    info "  3. Run 'claude --version' to verify Claude Code"
    info "  4. cd ~/oss/ppl && claude   # to start a Claude session"
    echo ""

    # Clean up temp dir only on full success
    if [ ${#failed[@]} -eq 0 ]; then
        rm -rf "$(dirname "$SETUP_DIR")"
    fi
}

main "$@"
