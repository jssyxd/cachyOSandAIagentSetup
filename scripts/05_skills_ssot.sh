#!/usr/bin/env bash
set -euo pipefail

echo ">>> [Phase 5] Setting up Global Skills Single Source of Truth (SSOT)..."

export PATH="$HOME/.local/bin:$PATH"
SSOT_DIR="$HOME/.agents/skills"
mkdir -p "$SSOT_DIR"

# 5.1 agent-reach
echo "Installing agent-reach via uv..."
uv tool install agent-reach || true

# 5.2 loopx
echo "Installing loopx via uv..."
uv tool install loopx || true

# 5.3 herdr-skills (herdr-dispatch & herdr-swarm)
if [ ! -d "$SSOT_DIR/herdr-dispatch" ]; then
    echo "Cloning arronKler/herdr-skills..."
    git clone https://github.com/arronKler/herdr-skills.git /tmp/herdr-skills
    cp -r /tmp/herdr-skills/skills/herdr-dispatch "$SSOT_DIR/"
    cp -r /tmp/herdr-skills/skills/herdr-swarm "$SSOT_DIR/"
    chmod +x "$SSOT_DIR/herdr-dispatch/scripts/herd-dispatch"
    ln -sf "$SSOT_DIR/herdr-dispatch/scripts/herd-dispatch" "$HOME/.local/bin/herd-dispatch"
    rm -rf /tmp/herdr-skills
fi

# 5.4 WSL / Windows Coordination Skills (Condition: Only install when deployed on Windows/WSL)
IS_WINDOWS=false
if [[ "${OSTYPE:-}" == "msys"* || "${OSTYPE:-}" == "cygwin"* || "${OS:-}" == "Windows_NT" ]] || grep -qi "microsoft" /proc/version 2>/dev/null; then
    IS_WINDOWS=true
fi

if [ "$IS_WINDOWS" = true ]; then
    echo ">>> [Phase 5] Host identified as Windows / WSL environment. Installing admin-wsl & windows-wsl-coordination skills..."
    SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    if [ -d "$SCRIPT_ROOT/skills_repo/admin-wsl" ]; then
        cp -r "$SCRIPT_ROOT/skills_repo/admin-wsl" "$SSOT_DIR/"
        cp -r "$SCRIPT_ROOT/skills_repo/windows-wsl-coordination" "$SSOT_DIR/"
    else
        # Fallback to remote clone if repo local dir not present
        git clone https://github.com/evolv3ai/claude-skills-archive.git /tmp/claude-skills-archive || true
        if [ -d "/tmp/claude-skills-archive/archive/skills/admin-wsl" ]; then
            cp -r /tmp/claude-skills-archive/archive/skills/admin-wsl "$SSOT_DIR/"
            cp -r /tmp/claude-skills-archive/skills/windows-wsl-coordination "$SSOT_DIR/"
        fi
        rm -rf /tmp/claude-skills-archive
    fi
    echo ">>> [Phase 5] Windows/WSL skills installed to SSOT successfully."
else
    echo ">>> [Phase 5] Host is pure Linux (non-Windows/non-WSL). Skipping admin-wsl skills installation as required."
fi

echo ">>> [Phase 5] Completed successfully."
