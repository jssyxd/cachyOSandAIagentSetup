#!/usr/bin/env bash
set -euo pipefail

echo ">>> [Phase 4] Installing Browser-Use and Computer-Use..."

NODE_VER="v22.23.2"
export PATH="$HOME/.local/bin:$HOME/.local/share/pi-node/node-${NODE_VER}-linux-x64/bin:$PATH"

# 4.1 Browser-Use (Python CLI)
echo "Installing browser-use CLI via uv..."
uv tool install browser-use || true

# 4.2 Computer-Use Linux driver
echo "Installing @agent-sh/computer-use-linux globally..."
npm install -g @agent-sh/computer-use-linux || true

# 4.3 Pi Browser-Use npm package is included in Pi settings (Phase 6)
echo ">>> [Phase 4] Completed successfully."
