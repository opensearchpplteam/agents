#!/usr/bin/env bash
#
# configure-claude.sh - Write ~/.claude/settings.json with Bedrock config
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

CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="${CLAUDE_DIR}/settings.json"

configure_claude() {
    mkdir -p "$CLAUDE_DIR"

    if [ -f "$SETTINGS_FILE" ]; then
        warn "~/.claude/settings.json already exists."
        info "Backing up to settings.json.bak and writing fresh config."
        cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak"
    fi

    cat > "$SETTINGS_FILE" << 'SETTINGS_EOF'
{
  "env": {
    "MCP_TIMEOUT": "120000",
    "ANTHROPIC_MODEL": "global.anthropic.claude-opus-4-6-v1[1m]",
    "AWS_PROFILE": "bedrock-prod",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "true",
    "CLAUDE_CODE_USE_BEDROCK": "true",
    "DISABLE_BUG_COMMAND": "true",
    "DISABLE_ERROR_REPORTING": "true",
    "DISABLE_TELEMETRY": "true",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "statusLine": {
    "type": "command",
    "command": "input=$(cat); dir=$(echo \"$input\" | jq -r '.workspace.current_dir'); branch=$(cd \"$dir\" 2>/dev/null && git -c core.fileMode=false rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'no-git'); used=$(echo \"$input\" | jq -r '.context_window.used_percentage // empty'); inp=$(echo \"$input\" | jq -r '.context_window.total_input_tokens // 0'); out=$(echo \"$input\" | jq -r '.context_window.total_output_tokens // 0'); cost=$(echo \"scale=3; ($inp * 15 + $out * 75) / 1000000\" | bc -l 2>/dev/null || echo '0'); parts=(); [ \"$branch\" != 'no-git' ] && parts+=(\"$branch\"); parts+=(\"$(basename \"$dir\")\"); [ -n \"$used\" ] && parts+=(\"ctx:${used}%\"); [ \"$cost\" != '0' ] && [ \"$cost\" != '0.000' ] && parts+=(\"~\\$${cost}\"); IFS=' | '; echo \"${parts[*]}\"",
    "padding": 0
  },
  "enabledPlugins": {
    "context7@claude-plugins-official": true,
    "ralph-loop@claude-plugins-official": true,
    "github@claude-plugins-official": true
  },
  "alwaysThinkingEnabled": true,
  "skipDangerousModePermissionPrompt": true,
  "teammateMode": "in-process",
  "includeCoAuthoredBy": false
}
SETTINGS_EOF

    success "Wrote ~/.claude/settings.json"
    info "  - Bedrock model: global.anthropic.claude-opus-4-6-v1[1m]"
    info "  - AWS profile: bedrock-prod"
    info "  - Plugins: context7, ralph-loop, github"
    info "  - Agent teams: enabled"
}

main() {
    info "Configuring Claude Code..."
    configure_claude
}

main "$@"
