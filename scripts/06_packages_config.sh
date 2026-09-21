#!/usr/bin/env bash
set -euo pipefail

echo ">>> [Phase 6] Configuring AI Agent Packages, Plugins & Rules (Zero Redundancy)..."

mkdir -p "$HOME/.pi/agent/git/github.com/mitsuhiko" "$HOME/.pi/agent/git/github.com/bestony"

# 6.1 Clone mitsuhiko/agent-stuff (core skills & extensions)
if [ ! -d "$HOME/.pi/agent/git/github.com/mitsuhiko/agent-stuff" ]; then
    git clone https://github.com/mitsuhiko/agent-stuff.git "$HOME/.pi/agent/git/github.com/mitsuhiko/agent-stuff"
fi

# 6.2 Clone bestony/bestony-pi (prompts & themes)
if [ ! -d "$HOME/.pi/agent/git/github.com/bestony/bestony-pi" ]; then
    git clone https://github.com/bestony/bestony-pi.git "$HOME/.pi/agent/git/github.com/bestony/bestony-pi"
fi

# 6.3 Pi settings.json with strict exclusion of conflicting/deprecated modules
cat > "$HOME/.pi/agent/settings.json" << 'EOF'
{
  "theme": "dark",
  "defaultProvider": "default",
  "defaultModel": "default-model",
  "packages": [
    "npm:pi-browser-use",
    "npm:@quintinshaw/pi-dynamic-workflows",
    {
      "source": "https://github.com/mitsuhiko/agent-stuff",
      "extensions": [
        "!extensions/unified-edit.ts",
        "!extensions/uv.ts"
      ],
      "skills": [
        "!skills/apple-mail",
        "!skills/audio-transcription"
      ]
    },
    {
      "source": "https://github.com/bestony/bestony-pi",
      "extensions": [
        "!node_modules/pi-web-access/**",
        "!node_modules/@narumitw/pi-goal/**",
        "!node_modules/pi-xai-oauth/**"
      ]
    },
    {
      "source": "npm:@trim21/personal-pi-extensions@0.1.578",
      "extensions": [
        "!src/claude-code/**"
      ]
    }
  ],
  "hideThinkingBlock": true
}
EOF

# 6.4 Pi local proxy config (for Clash Verge port 7897 or user proxy)
cat > "$HOME/.pi/agent/proxy.json" << 'EOF'
{
  "proxy": "http://127.0.0.1:7897"
}
EOF

echo ">>> [Phase 6] Completed successfully."
