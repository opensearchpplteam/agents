# PPL Team Agent Environment

One-line installer for provisioning EC2 instances with the full OpenSearch PPL agent development environment.

## Quick Start

SSH into your EC2 instance and run:

```bash
curl -fsSL https://raw.githubusercontent.com/opensearchpplteam/agents/main/install.sh | bash
```

This installs everything needed to run Claude Code sessions for OpenSearch PPL development.

## What Gets Installed

| Component | Details |
|-----------|---------|
| Java 21 | Amazon Corretto 21 via dnf |
| Git | Latest from dnf |
| tmux | Terminal multiplexer |
| GitHub CLI | `gh` for PR workflows |
| Node.js 22 | Required by Claude Code |
| Claude Code | `@anthropic-ai/claude-code` via npm |
| bc | Used by the status line cost calculator |

## What Gets Configured

**Repositories** cloned into `~/oss/`:

| Repo | Local Path |
|------|-----------|
| `opensearchpplteam/sql` | `~/oss/ppl/` |
| `opensearchpplteam/agents` | `~/oss/agents/` |

**Skills** symlinked from `~/oss/agents/skills/` into `~/oss/ppl/.claude/skills/`:
- `opensearch-ppl-developer` — PPL development assistant
- `opensearch-ppl-team-review` — Code review assistant

All skills are bundled in this repo under `skills/` (no external repo dependency).

**Claude Code** (`~/.claude/settings.json`):
- Model: `global.anthropic.claude-opus-4-6-v1[1m]` via AWS Bedrock
- AWS profile: `bedrock-prod`
- Plugins: context7, ralph-loop, github
- Agent teams enabled, always-thinking mode on
- Status line showing branch, directory, context usage, and estimated cost

**Shell environment** (`~/.bashrc`):
- `AWS_REGION=us-west-2`
- `AWS_PROFILE=bedrock-prod`
- `~/.local/bin` in PATH

**Directory structure**:
```
~/oss/                      # All source repos
~/oss/ppl/                  # OpenSearch SQL/PPL repo
~/oss/ppl/.claude/skills/   # Skills symlinks → ~/oss/agents/skills/
~/oss/agents/               # This repo (installer + skills)
~/oss/agents/skills/        # All skill definitions
~/ppl-team/issues/          # Issue tracking workspace
~/ppl-team/logs/            # Session logs
~/ppl-team/review/          # Code review workspace
```

## Prerequisites

- **Amazon Linux 2023** EC2 instance (the installer warns on other OSes but will attempt to continue)
- **sudo access** for installing system packages via dnf
- **AWS credentials** configured with a `bedrock-prod` profile that has access to Bedrock
- The installer will generate an SSH key and guide you through registering it with GitHub if needed

## Installation Steps

The installer runs 7 steps in order:

1. **Install system packages** — Java 21, git, tmux, gh, Node.js 22, bc
2. **Install Claude Code** — via `npm install -g @anthropic-ai/claude-code`
3. **Configure Claude Code** — writes `~/.claude/settings.json` with Bedrock config
4. **Configure Git & GitHub** — prompts for git name/email, generates SSH key, guides you to register it on GitHub, runs `gh auth login`
5. **Clone repositories** — clones sql and agents repos, creates skills symlinks
6. **Configure shell environment** — appends AWS env vars to `~/.bashrc`
7. **Verify installation** — checks all components and prints a pass/fail summary

Step 4 (Git/GitHub) is interactive — it prompts for your identity, generates an SSH key if needed, shows it to you with instructions to add it at https://github.com/settings/ssh/new, then verifies the connection before proceeding to `gh auth login`.

## Post-Install Verification

Open a new terminal and verify:

```bash
java --version              # Should show 21.x
claude --version            # Should show latest version
gh auth status              # Should show authenticated
ls ~/oss/ppl/               # Should have the sql repo contents
ls ~/oss/ppl/.claude/skills # Should show 2 symlinks
```

Start a Claude session:

```bash
cd ~/oss/ppl
claude
```

## Configuration

### AWS Bedrock Access

The installer sets `AWS_PROFILE=bedrock-prod`. Make sure your AWS credentials file has this profile configured:

```ini
# ~/.aws/credentials
[bedrock-prod]
aws_access_key_id = YOUR_KEY
aws_secret_access_key = YOUR_SECRET

# ~/.aws/config
[profile bedrock-prod]
region = us-west-2
```

Or if using SSO:

```ini
# ~/.aws/config
[profile bedrock-prod]
sso_start_url = https://your-org.awsapps.com/start
sso_region = us-west-2
sso_account_id = 123456789012
sso_role_name = YourRole
region = us-west-2
```

### Claude Code Settings

The installer writes `~/.claude/settings.json`. Key settings you may want to customize:

```jsonc
{
  "env": {
    "ANTHROPIC_MODEL": "global.anthropic.claude-opus-4-6-v1[1m]",  // Model ID
    "AWS_PROFILE": "bedrock-prod",                                   // AWS profile name
    "CLAUDE_CODE_USE_BEDROCK": "true"                                // Use Bedrock backend
  },
  "enabledPlugins": {
    "context7@claude-plugins-official": true,      // Library docs lookup
    "ralph-loop@claude-plugins-official": true,     // Agentic loop
    "github@claude-plugins-official": true          // GitHub integration
  },
  "alwaysThinkingEnabled": true,                   // Extended thinking
  "skipDangerousModePermissionPrompt": true,        // Skip safety prompts
  "teammateMode": "in-process"                      // Agent team execution mode
}
```

To edit after installation:

```bash
vim ~/.claude/settings.json
```

### Git Identity

The installer prompts for your name and email during setup. To change later:

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

The installer also configures SSH as the default protocol for GitHub. To revert to HTTPS:

```bash
git config --global --unset url."git@github.com:".insteadOf
```

### GitHub Authentication

If `gh auth` expires or you need to re-authenticate:

```bash
gh auth login -p ssh -h github.com
```

## Re-running Individual Steps

If a step fails, you can re-run it individually. Clone this repo and run the specific script:

```bash
cd ~/oss/agents

# Re-run a specific step
bash setup/install-tools.sh      # System packages
bash setup/install-claude.sh     # Claude Code
bash setup/configure-claude.sh   # Claude settings
bash setup/configure-git.sh      # Git & GitHub auth
bash setup/clone-repos.sh        # Repos & skills
bash setup/configure-env.sh      # Shell environment
bash setup/verify.sh             # Verification only
```

All scripts are idempotent — they check before acting and skip anything already installed or configured.

## Troubleshooting

### `java` command not found after install

Open a new terminal or run `source ~/.bashrc`.

### Claude Code not found after install

The npm global bin directory may not be in your PATH. Check:

```bash
npm config get prefix    # Shows npm prefix, e.g. /usr/local
ls $(npm config get prefix)/bin/claude
```

Add it to PATH if needed, or open a new terminal.

### `gh auth login` fails

Make sure your EC2 instance can reach `github.com`. If behind a proxy, configure git and gh proxy settings. You can also authenticate with a personal access token:

```bash
gh auth login --with-token < token.txt
```

### Skills symlinks are broken

The skills symlinks point to `~/oss/agents/skills/`. If the agents repo wasn't cloned successfully, re-run:

```bash
bash ~/oss/agents/setup/clone-repos.sh
```

### Want to reset Claude settings

The installer backs up existing settings before overwriting:

```bash
# Restore backup
cp ~/.claude/settings.json.bak ~/.claude/settings.json

# Or re-run to get fresh defaults
bash ~/oss/agents/setup/configure-claude.sh
```

## File Structure

```
agents/
├── install.sh                  # Main entry point (downloads & runs setup scripts)
├── README.md
├── setup/
│   ├── install-tools.sh        # Java 21, git, tmux, gh, Node.js, bc
│   ├── install-claude.sh       # Claude Code CLI
│   ├── configure-claude.sh     # ~/.claude/settings.json
│   ├── configure-git.sh        # Git identity, SSH key + gh auth
│   ├── clone-repos.sh          # Repos + skills symlinks
│   ├── configure-env.sh        # ~/.bashrc additions
│   └── verify.sh               # Validation & summary
└── skills/                     # All skill definitions (symlinked into ppl repo)
    ├── opensearch-ppl-developer/
    ├── opensearch-ppl-team-review/
    ├── opensearch-sql-pr-review/
    ├── bounty-hunter/
    ├── ppl-perf-optimizer/
    ├── distributed-ppl/
    ├── distributed-ppl-connector/
    ├── distributed-ppl-phase1/
    ├── distributed-ppl-qa/
    └── distributed-ppl-translate/
```
