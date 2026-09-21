#!/usr/bin/env bash
# ==============================================================================
# cachyOSandAIagentSetup - Master Installer
# Target: CachyOS / Arch Linux / Debian / Ubuntu (x86_64)
# Architecture: Single Source of Truth (SSOT) at ~/.agents/skills/
# Designed for Human & Autonomous Agents
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/cachyos-agent-setup-$(date +%Y%m%d_%H%M%S).log"

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "[$timestamp] [$level] $msg" | tee -a "$LOG_FILE"
}

log_info()  { log "\033[0;32mINFO\033[0m" "$@"; }
log_warn()  { log "\033[0;33mWARN\033[0m" "$@"; }
log_error() { log "\033[0;31mERROR\033[0m" "$@"; }

print_banner() {
    cat << "EOF"
  ____           _            ___  ____       _                    _   ____       _               
 / ___|__ _  ___| |__  _   _ / _ \/ ___|     / \   __ _  ___ _ __ | |_/ ___|  ___| |_ _   _ _ __  
| |   / _` |/ __| '_ \| | | | | | \___ \    / _ \ / _` |/ _ \ '_ \| __\___ \ / _ \ __| | | | '_ \ 
| |__| (_| | (__| | | | |_| | |_| |___) |  / ___ \ (_| |  __/ | | | |_ ___) |  __/ |_| |_| | |_) |
 \____\__,_|\___|_| |_|\__, |\___/|____/  /_/   \_\__, |\___|_| |_|\__|____/ \___|\__|\__,_| .__/ 
                       |___/                      |___/                                     |_|    
EOF
    echo -e "\033[1;34m>>> CachyOS & Multi-Agent Automated Provisioning Toolkit <<<\033[0m"
    echo -e "Logging to: $LOG_FILE\n"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    if [ "$EUID" -eq 0 ]; then
        log_error "Please run this installer as a regular user with sudo privileges, NOT root."
        exit 1
    fi

    if ! sudo -v &>/dev/null; then
        log_error "Sudo privileges required. Please configure sudoers for user $USER."
        exit 1
    fi
}

run_phase() {
    local phase_num="$1"
    local phase_name="$2"
    local script_path="$SCRIPT_DIR/scripts/$3"

    log_info "========================================================"
    log_info "Executing Phase $phase_num: $phase_name"
    log_info "Script: $script_path"
    log_info "========================================================"

    if [ -f "$script_path" ]; then
        chmod +x "$script_path"
        bash "$script_path" 2>&1 | tee -a "$LOG_FILE"
    else
        log_warn "Script $script_path not found, skipping."
    fi
}

main() {
    print_banner
    check_prerequisites

    run_phase 0 "Base System, Proxy & Chinese Environment" "00_base_system.sh"
    run_phase 1 "Runtimes & CLI Tools (Node, Bun, uv, gh)"  "01_runtimes_cli.sh"
    run_phase 2 "Sandbox Layer (Docker & Bubblewrap)"       "02_sandbox_docker.sh"
    run_phase 3 "Core AI Coding Agents (Pi, omp, OpenCode)" "03_install_agents.sh"
    run_phase 4 "Browser-Use & Computer-Use Layer"          "04_browser_computer_use.sh"
    run_phase 5 "Global Skills SSOT (agent-reach, vibeshell, loopx, herdr-skills)" "05_skills_ssot.sh"
    run_phase 6 "AI Agent Configuration Packages & Rules"   "06_packages_config.sh"
    run_phase 7 "Herdr Multi-Agent Terminal Orchestrator"   "07_herdr_setup.sh"
    run_phase 8 "Model Routing & Environment Configuration" "08_models_config.sh"
    run_phase 9 "Skill Symlinks Sync & Deduplication"       "09_sync_skills.sh"

    log_info "All phases completed successfully!"
    log_info "Running end-to-end self-test verification..."
    bash "$SCRIPT_DIR/verify.sh"
}

main "$@"
