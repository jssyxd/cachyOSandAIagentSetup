#!/usr/bin/env bash
set -euo pipefail

echo ">>> [Phase 7] Configuring Herdr Multi-Agent Orchestrator..."

export PATH="$HOME/.local/bin:$PATH"

mkdir -p "$HOME/.config/herdr"
cat > "$HOME/.config/herdr/config.toml" << 'EOF'
onboarding = false
EOF

if command -v herdr &>/dev/null; then
    echo "Syncing Herdr agent state tracking plugins..."
    herdr integration install pi || true
    herdr integration install omp || true
    herdr integration install opencode || true
    herdr integration install hermes || true
else
    echo "Notice: Place your herdr binary into ~/.local/bin/herdr to enable terminal multi-agent dispatch."
fi

echo ">>> [Phase 7] Completed successfully."
