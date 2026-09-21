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

echo ">>> [Phase 5] Completed successfully."
