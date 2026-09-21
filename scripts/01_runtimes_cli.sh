#!/usr/bin/env bash
set -euo pipefail

echo ">>> [Phase 1] Installing Runtimes and Essential CLI Tools..."

export PATH="$HOME/.local/bin:$PATH"

# 1.1 Astral uv & uvx
if ! command -v uv &>/dev/null; then
    echo "Installing Astral uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# 1.2 Node.js LTS
NODE_VER="v22.23.2"
NODE_DIR="$HOME/.local/share/pi-node/node-${NODE_VER}-linux-x64"
if [ ! -d "$NODE_DIR" ]; then
    echo "Installing Node.js ${NODE_VER}..."
    mkdir -p "$HOME/.local/share/pi-node"
    curl -fsSL "https://nodejs.org/dist/${NODE_VER}/node-${NODE_VER}-linux-x64.tar.xz" | tar -xJ -C "$HOME/.local/share/pi-node"
fi
export PATH="$NODE_DIR/bin:$PATH"

for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rc" ] && ! grep -q "pi-node" "$rc"; then
        echo "export PATH=\"\$HOME/.local/share/pi-node/node-${NODE_VER}-linux-x64/bin:\$PATH\"" >> "$rc"
    fi
done

# 1.3 Bun
if ! command -v bun &>/dev/null; then
    echo "Installing Bun runtime..."
    curl -fsSL https://bun.sh/install | bash
    ln -sf "$HOME/.bun/bin/bun" "$HOME/.local/bin/bun"
fi

# 1.4 GitHub CLI (gh)
if ! command -v gh &>/dev/null; then
    echo "Installing GitHub CLI..."
    GH_VER="2.101.0"
    curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VER}/gh_${GH_VER}_linux_amd64.tar.gz" | tar -xz -C /tmp
    cp "/tmp/gh_${GH_VER}_linux_amd64/bin/gh" "$HOME/.local/bin/gh"
    chmod +x "$HOME/.local/bin/gh"
    rm -rf "/tmp/gh_${GH_VER}_linux_amd64"
fi

echo ">>> [Phase 1] Completed successfully."
