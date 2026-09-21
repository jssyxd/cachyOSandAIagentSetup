#!/usr/bin/env bash
set -euo pipefail

echo ">>> [Phase 9] Syncing Skills from SSOT to all Agent Environments..."

SSOT_DIR="$HOME/.agents/skills"
TARGET_DIRS=(
    "$HOME/.pi/agent/skills"
    "$HOME/.omp/agent/skills"
    "$HOME/.config/opencode/skills"
)

mkdir -p "$SSOT_DIR"

for target in "${TARGET_DIRS[@]}"; do
    mkdir -p "$target"
    # Clean up broken symlinks
    find "$target" -xtype l -delete 2>/dev/null || true
    
    # Symlink each valid skill directory from SSOT
    for skill_path in "$SSOT_DIR"/*; do
        [ -d "$skill_path" ] || continue
        skill_name=$(basename "$skill_path")
        ln -sfn "$skill_path" "$target/$skill_name"
    done
done

echo ">>> [Phase 9] Skills synchronized across all agents with zero conflicts."
