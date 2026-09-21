#!/usr/bin/env bash
set -euo pipefail

echo ">>> [Phase 8] Providing Multi-Provider Model Configuration Templates..."

# Models configuration template supporting both direct API keys and custom gateways
cat > "$HOME/.pi/agent/models.example.json" << 'EOF'
{
  "providers": {
    "custom-gateway": {
      "baseUrl": "http://YOUR_GATEWAY_OR_API_HOST/v1",
      "api": "openai-completions",
      "apiKey": "YOUR_API_KEY",
      "models": [
        { "id": "gemini-3.8-flash-high", "name": "Gemini 3.8 Flash High", "reasoning": true, "input": ["text","image"], "contextWindow": 1000000, "maxTokens": 32000 }
      ]
    },
    "deepseek": {
      "baseUrl": "https://api.deepseek.com/v1",
      "api": "openai-completions",
      "apiKey": "YOUR_DEEPSEEK_API_KEY",
      "models": [
        { "id": "deepseek-chat", "name": "DeepSeek V3", "input": ["text"], "contextWindow": 64000, "maxTokens": 8000 },
        { "id": "deepseek-reasoner", "name": "DeepSeek R1", "reasoning": true, "input": ["text"], "contextWindow": 64000, "maxTokens": 8000 }
      ]
    },
    "anthropic": {
      "baseUrl": "https://api.anthropic.com/v1",
      "api": "anthropic-messages",
      "apiKey": "YOUR_ANTHROPIC_API_KEY",
      "models": [
        { "id": "claude-sonnet-4-6", "name": "Claude Sonnet 4.6", "input": ["text","image"], "contextWindow": 200000, "maxTokens": 32000 }
      ]
    }
  }
}
EOF

# If models.json doesn't exist, create it from example
if [ ! -f "$HOME/.pi/agent/models.json" ]; then
    cp "$HOME/.pi/agent/models.example.json" "$HOME/.pi/agent/models.json"
fi

echo ">>> [Phase 8] Model configuration template initialized."
