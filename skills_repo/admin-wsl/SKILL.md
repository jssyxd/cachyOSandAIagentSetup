---
name: admin-wsl
description: |
  WSL2 Ubuntu administration from Linux side. Profile-aware - reads preferences from
  Windows-side profile at /mnt/c/Users/{WIN_USER}/.admin/profiles/{hostname}.json

  Use when: Inside WSL for apt packages, Docker, Python/uv, shell configs, systemd.
  Coordinates with admin-windows via shared profile ON THE WINDOWS SIDE.
license: MIT
source: plugin
---

# WSL Administration

## CRITICAL MUST: Secrets and .env

- NEVER store live `.env` files or credentials inside any skill folder.
- `.env.template` files belong only in `templates/` within a skill.
- Store live secrets in `~/.admin/.env` (or another non-skill location you control) and reference them from there.


**Requires**: WSL2 context, Ubuntu 24.04

---

## ⚠️ Profile Gate (MANDATORY - DO THIS FIRST)

**STOP. Before ANY operation, you MUST check for the profile. This is not optional.**

### Step 1: Check Profile Exists

```bash
# Use the helper script - it handles WSL path detection correctly
~/.claude/skills/admin/scripts/test-admin-profile.sh
```

Returns JSON: `{"exists":true,"path":"/mnt/c/Users/Owner/.admin/profiles/CASATEN.json",...}`

### Step 2: If Profile Missing → Run Setup

If `exists` is `false`:
```bash
~/.claude/skills/admin/scripts/setup-interview.sh
```

**DO NOT proceed with ANY task until profile exists.**

### Step 3: Load Profile

```bash
source ~/.claude/skills/admin/scripts/load-profile.sh
load_admin_profile
```

### Step 4: After ANY Operation → Log It

```bash
source ~/.claude/skills/admin/scripts/log-admin-event.sh
log_admin_event "Installed docker via apt" "OK"

# On failure, also create issue:
source ~/.claude/skills/admin/scripts/new-admin-issue.sh
new_admin_issue "Docker installation failed" "install" "docker,apt"
```

## ⚠️ Critical: Profile Location

**The profile lives on the WINDOWS side, not in WSL home.**

```bash
# WRONG - this doesn't exist in WSL
ls ~/.admin/profiles/  # Empty!

# RIGHT - profile is on Windows, accessed via /mnt/c
WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
ADMIN_ROOT="/mnt/c/Users/$WIN_USER/.admin"
PROFILE_PATH="$ADMIN_ROOT/profiles/$(hostname).json"
ls "$PROFILE_PATH"  # Found!
```

---

## Quick Start

The loader auto-detects WSL and uses the correct path:

```bash
source /path/to/admin/scripts/load-profile.sh
show_environment  # Verify detection
load_admin_profile
show_admin_summary
```

Output should show:
```
Type:        WSL (Windows Subsystem for Linux)
Win User:    {your-windows-username}
ADMIN_ROOT:  /mnt/c/Users/{username}/.admin
Profile:     /mnt/c/Users/{username}/.admin/profiles/{hostname}.json
Exists:      YES
```

---

## Critical Rules

### Always Do

- Keep profiles on the Windows side and access via `/mnt/c/Users/{WIN_USER}/.admin`
- Use Linux tools inside WSL (`apt`, `systemd`, `chmod`, `chown`)
- Convert Windows paths before use in WSL scripts
- Hand off `.wslconfig` changes to `admin-windows`
- Restart WSL after `.wslconfig` changes (`wsl --shutdown` on Windows)

### Never Do

- Run `apt` from PowerShell
- Edit `.wslconfig` from inside WSL
- Use raw Windows paths in Linux scripts
- Edit Linux files with Windows tools that break line endings
- Assume PATH is shared between Windows and WSL

---

## Check WSL Config from Profile

```bash
# Profile has WSL section
jq '.wsl' "$PROFILE_PATH"

# Resource limits
jq '.wsl.resourceLimits' "$PROFILE_PATH"
# Returns: {"memory": "16GB", "processors": 8, "swap": "4GB"}

# WSL tools
jq '.wsl.distributions["Ubuntu-24.04"].tools' "$PROFILE_PATH"
```

---

## Package Installation (Profile-Aware)

### Python - Check Preference

```bash
PY_MGR=$(jq -r '.preferences.python.manager' "$PROFILE_PATH")
# Returns: "uv" or "pip" or "conda"

case "$PY_MGR" in
    uv)     uv pip install "$package" ;;
    pip)    pip install "$package" ;;
    conda)  conda install "$package" ;;
esac
```

### Node - Check Preference

```bash
NODE_MGR=$(jq -r '.preferences.node.manager' "$PROFILE_PATH")

case "$NODE_MGR" in
    npm)    npm install "$package" ;;
    pnpm)   pnpm add "$package" ;;
    yarn)   yarn add "$package" ;;
    bun)    bun add "$package" ;;
esac
```

### System Packages (apt)

```bash
sudo apt update
sudo apt install -y $package
```

---

## Docker Operations

### Check Docker from Profile

```bash
DOCKER_PRESENT=$(jq -r '.docker.present' "$PROFILE_PATH")
DOCKER_BACKEND=$(jq -r '.docker.backend' "$PROFILE_PATH")

if [[ "$DOCKER_PRESENT" == "true" && "$DOCKER_BACKEND" == "WSL2" ]]; then
    # Docker Desktop with WSL2 integration
    docker ps
fi
```

### Common Commands

```bash
docker ps                    # List running
docker images               # List images
docker logs <container>     # View logs
docker exec -it <c> bash    # Shell into container
docker-compose up -d        # Start compose stack
```

---

## Path Conversions

Windows paths in profile need conversion:

```bash
# Profile path: "C:/Users/Owner/.ssh"
# WSL path:     "/mnt/c/Users/Owner/.ssh"

win_to_wsl() {
    local win_path="$1"
    local drive=$(echo "$win_path" | cut -c1 | tr '[:upper:]' '[:lower:]')
    local rest=$(echo "$win_path" | cut -c3- | sed 's|\\|/|g')
    echo "/mnt/$drive$rest"
}

# Usage
SSH_PATH=$(jq -r '.paths.sshKeys' "$PROFILE_PATH")
WSL_SSH_PATH=$(win_to_wsl "$SSH_PATH")
```

---

## SSH to Servers

Use profile server data:

```bash
# Get server info
SERVER=$(jq '.servers[] | select(.id == "cool-two")' "$PROFILE_PATH")
HOST=$(echo "$SERVER" | jq -r '.host')
USER=$(echo "$SERVER" | jq -r '.username')
KEY=$(echo "$SERVER" | jq -r '.keyPath')

# Convert Windows key path
WSL_KEY=$(win_to_wsl "$KEY")

# Connect
ssh -i "$WSL_KEY" "$USER@$HOST"
```

Or use the loader helper:

```bash
source load-profile.sh
load_admin_profile
ssh_to_server "cool-two"  # Auto-converts paths
```

---

## Update Profile from WSL

After installing a tool in WSL:

```bash
# Read profile
PROFILE=$(cat "$PROFILE_PATH")

# Update WSL tools section
PROFILE=$(echo "$PROFILE" | jq --arg ver "$(node --version)" \
    '.wsl.distributions["Ubuntu-24.04"].tools.node.version = $ver')

# Save
echo "$PROFILE" | jq . > "$PROFILE_PATH"
```

---

## Resource Limits

Controlled by `.wslconfig` (Windows side). Profile tracks current settings:

```bash
jq '.wsl.resourceLimits' "$PROFILE_PATH"
```

To change, hand off to `admin-windows`:

```bash
# Log handoff
echo "[$(date -Iseconds)] HANDOFF: Need .wslconfig change - increase memory to 24GB" \
    >> "$ADMIN_ROOT/logs/handoffs.log"
```

---

## Capabilities Check

```bash
# From profile
HAS_DOCKER=$(jq -r '.capabilities.hasDocker' "$PROFILE_PATH")
HAS_GIT=$(jq -r '.capabilities.hasGit' "$PROFILE_PATH")

if [[ "$HAS_DOCKER" == "true" ]]; then
    docker info
fi
```

---

## Issues Tracking

Check known issues before troubleshooting:

```bash
jq '.issues.current[]' "$PROFILE_PATH"
```

Add new issue:

```bash
PROFILE=$(cat "$PROFILE_PATH")
PROFILE=$(echo "$PROFILE" | jq '.issues.current += [{
    "id": "wsl-docker-'"$(date +%s)"'",
    "tool": "docker",
    "issue": "Docker socket not found",
    "priority": "high",
    "status": "pending",
    "created": "'"$(date -Iseconds)"'"
}]')
echo "$PROFILE" | jq . > "$PROFILE_PATH"
```

---

## Common Tasks

### Update System

```bash
sudo apt update && sudo apt upgrade -y
```

### Install Python Package (Profile-Aware)

```bash
PY_MGR=$(get_preferred_manager python)
case "$PY_MGR" in
    uv)  uv pip install requests ;;
    *)   pip install requests ;;
esac
```

### Create Python Venv

```bash
PY_MGR=$(get_preferred_manager python)
if [[ "$PY_MGR" == "uv" ]]; then
    uv venv .venv
    source .venv/bin/activate
    uv pip install -r requirements.txt
else
    python -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
fi
```

---

## Scope Boundaries

| Task | Handle Here | Hand Off To |
|------|-------------|-------------|
| apt packages | ✅ | - |
| Docker containers | ✅ | - |
| Python/Node in WSL | ✅ | - |
| .bashrc/.zshrc | ✅ | - |
| systemd services | ✅ | - |
| .wslconfig | ❌ | admin-windows |
| Windows packages | ❌ | admin-windows |
| MCP servers | ❌ | admin-mcp |
| Native Linux (non-WSL) | ❌ | admin-unix |

---

## References

- `references/wslconfig-reference.md` - Full .wslconfig template
- `references/resource-recommendations.md` - Memory/CPU/swap sizing table
- `references/wsl-commands.md` - Distribution management commands
- `references/path-conversion.md` - Windows↔WSL path mapping
- `references/line-endings.md` - CRLF/LF handling
- `references/known-issues.md` - Common pitfalls and prevention
- `references/OPERATIONS.md` - Troubleshooting and diagnostics
