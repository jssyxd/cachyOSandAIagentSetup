#!/usr/bin/env bash
set -euo pipefail

echo ">>> [Phase 3] Installing Core AI Coding Agents (Pi, omp, OpenCode)..."

NODE_VER="v22.23.2"
export PATH="$HOME/.local/bin:$HOME/.local/share/pi-node/node-${NODE_VER}-linux-x64/bin:$PATH"

# 3.1 Pi Coding Agent
echo "Installing Pi coding agent globally via npm..."
npm install -g @earendil-works/pi-coding-agent

# 3.2 Oh-My-Pi (omp)
mkdir -p "$HOME/.omp/agent/skills"
if [ ! -f "$HOME/.local/bin/omp" ]; then
    echo "Notice: Place your target omp binary into ~/.local/bin/omp"
fi
[ -f "$HOME/.local/bin/omp" ] && chmod +x "$HOME/.local/bin/omp" && ln -sf "$HOME/.local/bin/omp" "$HOME/.local/bin/ohmypi"

# 3.3 OpenCode
mkdir -p "$HOME/.config/opencode/skills"
cat > "$HOME/.config/opencode/package.json" << 'EOF'
{
  "name": "opencode-local",
  "dependencies": {
    "@opencode-ai/plugin": "^1.18.30",
    "@ai-sdk/openai-compatible": "^3.0.0"
  }
}
EOF
(cd "$HOME/.config/opencode" && npm install --silent)

echo ">>> [Phase 3] Completed successfully."
