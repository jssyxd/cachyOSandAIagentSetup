#!/usr/bin/env bash
set -euo pipefail

echo ">>> [Phase 2] Configuring Sandbox Layers (Docker & Bubblewrap)..."

# 2.1 Docker setup
if command -v pacman &>/dev/null; then
    sudo pacman -S --needed --noconfirm docker docker-compose docker-buildx
elif command -v apt-get &>/dev/null; then
    sudo apt-get install -y docker.io docker-compose-v2
fi

sudo systemctl enable --now docker 2>/dev/null || true
sudo usermod -aG docker "$USER" 2>/dev/null || true

# 2.2 Bubblewrap rootless sandbox configuration for Pi and agents
mkdir -p "$HOME/.pi/agent"
cat > "$HOME/.pi/agent/bwrap.json" << 'EOF'
{
  "mode": "workspace-write",
  "bwrapPath": "/usr/bin/bwrap",
  "writablePaths": [".", "/tmp"]
}
EOF

# Approval rules with variable assignment compatibility
cat > "$HOME/.pi/bwrap.json" << 'EOF'
{
  "approvalRules": [
    { "action": "allow", "pattern": "git clone *" },
    { "action": "allow", "pattern": "git pull *" },
    { "action": "allow", "pattern": "bash *" },
    { "action": "allow", "pattern": "*bash *" },
    { "action": "allow", "pattern": "rm *" },
    { "action": "allow", "pattern": "uv *" },
    { "action": "allow", "pattern": "npm *" },
    { "action": "allow", "pattern": "bun *" },
    { "action": "allow", "pattern": "gh *" }
  ]
}
EOF

echo ">>> [Phase 2] Completed successfully."
