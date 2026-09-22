# WSL Commands Reference

## Distribution Management

```powershell
# List all distributions
wsl --list --verbose
wsl -l -v

# Set default distribution
wsl --set-default Ubuntu-24.04

# Run specific distribution
wsl -d Ubuntu-24.04

# Run as specific user
wsl -d Ubuntu-24.04 -u root

# Terminate specific distribution
wsl --terminate Ubuntu-24.04

# Shutdown all WSL
wsl --shutdown

# Unregister (delete) distribution
wsl --unregister Ubuntu-24.04
```

## Installation and Updates

```powershell
# Install WSL (first time)
wsl --install

# Install specific distribution
wsl --install -d Ubuntu-24.04

# Update WSL
wsl --update

# Check WSL version
wsl --version

# List available distributions
wsl --list --online
```

## Import/Export

```powershell
# Export distribution to tar
wsl --export Ubuntu-24.04 D:\backups\ubuntu-backup.tar

# Import distribution from tar
wsl --import Ubuntu-Custom D:\wsl\ubuntu-custom D:\backups\ubuntu-backup.tar

# Set imported distribution version to WSL2
wsl --set-version Ubuntu-Custom 2
```

## Run Commands

```powershell
# Run single command in WSL
wsl -d Ubuntu-24.04 -e bash -c "echo Hello from WSL"

# Run command and return to Windows
wsl -d Ubuntu-24.04 -- ls -la /home

# Run with specific working directory
wsl -d Ubuntu-24.04 --cd /home/user -- pwd
```
