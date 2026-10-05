#!/usr/bin/env bash
set -euo pipefail

echo ">>> [Phase 2] Configuring Container Layers (Docker)..."

# 2.1 Docker setup only (removed Bubblewrap sandbox)
if command -v pacman &>/dev/null; then
    sudo pacman -S --needed --noconfirm docker docker-compose docker-buildx
elif command -v apt-get &>/dev/null; then
    sudo apt-get install -y docker.io docker-compose-v2
fi

sudo systemctl enable --now docker 2>/dev/null || true
sudo usermod -aG docker "$USER" 2>/dev/null || true

echo ">>> [Phase 2] Completed successfully."
