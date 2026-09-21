#!/usr/bin/env bash
set -euo pipefail

echo ">>> [Phase 0] Installing Base System, Proxy & Chinese Input Environment..."

# Detect package manager
if command -v pacman &>/dev/null; then
    echo "Updating pacman repositories..."
    sudo pacman -Syu --noconfirm
    sudo pacman -S --needed --noconfirm \
        base-devel git curl wget jq unzip tar rsync \
        bubblewrap ca-certificates zsh tmux lsof \
        noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra \
        fcitx5 fcitx5-chinese-addons fcitx5-configtool fcitx5-gtk fcitx5-qt fcitx5-pinyin-zhwiki

    # Ensure yay or paru is available
    if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
        echo "Installing yay-bin..."
        git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
        (cd /tmp/yay-bin && makepkg -si --noconfirm)
        rm -rf /tmp/yay-bin
    fi

    AUR_HELPER=$(command -v yay || command -v paru)
    echo "Installing AUR packages: google-chrome, clash-verge-rev-bin..."
    $AUR_HELPER -S --needed --noconfirm google-chrome clash-verge-rev-bin || true
elif command -v apt-get &>/dev/null; then
    echo "Debian/Ubuntu detected, installing base packages..."
    sudo apt-get update
    sudo apt-get install -y build-essential git curl wget jq unzip tar rsync \
        bubblewrap ca-certificates zsh tmux lsof fonts-noto-cjk fcitx5 fcitx5-chinese-addons
fi

# Configure Fcitx5 environment variables
cat >> "$HOME/.profile" << 'EOF'
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export SDL_IM_MODULE=fcitx
export GLFW_IM_MODULE=ibus
EOF

systemctl --user enable --now fcitx5 2>/dev/null || true

# Setup ~/.local/bin in PATH
mkdir -p "$HOME/.local/bin" "$HOME/.local/share"
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rc" ] && ! grep -q 'HOME/.local/bin' "$rc"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
    fi
done

echo ">>> [Phase 0] Completed successfully."
