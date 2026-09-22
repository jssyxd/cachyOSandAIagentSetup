# .wslconfig Reference

## File Location

```
C:\Users\{USERNAME}\.wslconfig
```

PowerShell:
```powershell
$wslConfigPath = "$env:USERPROFILE\.wslconfig"
```

## Complete Template

```ini
# Settings apply to all WSL 2 distributions

[wsl2]
# Memory - How much memory to assign to the WSL 2 VM
# Default: 50% of total memory on Windows or 8GB, whichever is less
memory=16GB

# Processors - How many processors to assign to the WSL 2 VM
# Default: Same number as Windows
processors=8

# Swap - How much swap space to add to the WSL 2 VM
# Default: 25% of available memory
swap=4GB

# Swap file path - Custom swap VHD path
# swapFile=C:\\temp\\wsl-swap.vhdx

# Page reporting - Enable/disable page reporting (memory release)
# Default: true
pageReporting=true

# Localhost forwarding - Enable localhost access from Windows to WSL
# Default: true
localhostForwarding=true

# Nested virtualization - Enable nested virtualization
# Default: true
nestedVirtualization=true

# Debug console - Enable output console for debug messages
# debugConsole=false

# GUI applications - Enable WSLg GUI support
# Default: true
guiApplications=true

# GPU support - Enable GPU compute support
# Default: true
# gpuSupport=true

# Firewall - Apply Windows Firewall rules to WSL
# Default: true
# firewall=true

# DNS tunneling - Enable DNS tunneling
# Default: true
# dnsTunneling=true

# Auto proxy - Use Windows HTTP proxy settings
# Default: true
# autoProxy=true

[experimental]
# Sparse VHD - Enable automatic compaction of WSL virtual hard disk
sparseVhd=true

# Auto memory reclaim - Reclaim cached memory
# Options: disabled, dropcache, gradual
autoMemoryReclaim=gradual

# Network mode - mirrored mirrors Windows networking
# networkingMode=mirrored
```
