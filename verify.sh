#!/usr/bin/env bash
set -euo pipefail

echo "========================================================"
echo "cachyOSandAIagentSetup - End-to-End Verification Suite"
echo "========================================================"

errors=0
warnings=0

check_cmd() {
    local cmd="$1"
    local desc="$2"
    if command -v "$cmd" &>/dev/null; then
        echo -e "  \033[0;32m[PASS]\033[0m $desc ($cmd -> $(command -v "$cmd"))"
    else
        echo -e "  \033[0;31m[FAIL]\033[0m Missing command: $cmd ($desc)"
        errors=$((errors + 1))
    fi
}

echo "1. Core Runtimes & CLIs:"
check_cmd git "Git VCS"
check_cmd bwrap "Bubblewrap Sandbox"
check_cmd node "Node.js LTS"
check_cmd bun "Bun Runtime"
check_cmd uv "Astral uv package manager"
check_cmd gh "GitHub CLI"

echo ""
echo "2. AI Coding Agents:"
check_cmd pi "Pi Coding Agent"
if command -v omp &>/dev/null || command -v ohmypi &>/dev/null; then
    echo -e "  \033[0;32m[PASS]\033[0m Oh-My-Pi (omp)"
else
    echo -e "  \033[0;33m[WARN]\033[0m omp not found in PATH"
    warnings=$((warnings + 1))
fi

if [ -f "$HOME/.config/opencode/package.json" ]; then
    echo -e "  \033[0;32m[PASS]\033[0m OpenCode package setup"
else
    echo -e "  \033[0;33m[WARN]\033[0m OpenCode package.json missing"
    warnings=$((warnings + 1))
fi

echo ""
echo "3. Multi-Agent Orchestration & Skills (SSOT):"
check_cmd herdr "Herdr Multi-Agent Orchestrator"
check_cmd herd-dispatch "Herdr Task Dispatcher"

SSOT_COUNT=$(ls -d "$HOME/.agents/skills"/*/ 2>/dev/null | wc -l || echo 0)
echo "  SSOT Skills registered: $SSOT_COUNT"
if [ "$SSOT_COUNT" -gt 0 ]; then
    echo -e "  \033[0;32m[PASS]\033[0m Skills SSOT contains $SSOT_COUNT skills"
else
    echo -e "  \033[0;33m[WARN]\033[0m Skills SSOT is empty"
    warnings=$((warnings + 1))
fi

echo ""
echo "4. Desktop & Browser Automation:"
if command -v google-chrome &>/dev/null; then
    echo -e "  \033[0;32m[PASS]\033[0m Google Chrome installed"
else
    echo -e "  \033[0;33m[WARN]\033[0m Google Chrome not installed"
    warnings=$((warnings + 1))
fi

if command -v browser-use &>/dev/null; then
    echo -e "  \033[0;32m[PASS]\033[0m browser-use CLI installed"
else
    echo -e "  \033[0;33m[WARN]\033[0m browser-use CLI not found"
    warnings=$((warnings + 1))
fi

echo ""
echo "5. Docker Service:"
if systemctl is-active --quiet docker 2>/dev/null; then
    echo -e "  \033[0;32m[PASS]\033[0m Docker daemon running"
else
    echo -e "  \033[0;33m[WARN]\033[0m Docker daemon not running or not accessible"
    warnings=$((warnings + 1))
fi

echo "========================================================"
echo "Summary: $errors Errors, $warnings Warnings."
if [ "$errors" -eq 0 ]; then
    echo -e "\033[0;32mAll critical components verified successfully!\033[0m"
else
    echo -e "\033[0;31mVerification encountered errors. Please check the log above.\033[0m"
fi
