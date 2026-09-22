# Path Conversion (Windows <-> WSL)

## Windows to WSL (PowerShell)

```powershell
function Convert-ToWslPath {
    param([string]$WindowsPath)
    $path = $WindowsPath -replace '\\', '/'
    $path = $path -replace '^([A-Za-z]):', '/mnt/$1'.ToLower()
    $path
}

# Usage
Convert-ToWslPath "D:\projects\myapp"
# Returns: /mnt/d/projects/myapp
```

## WSL to Windows (Bash)

```bash
# WSL to Windows path
wslpath -w /home/username/file.txt
# Returns: \\wsl$\Ubuntu-24.04\home\username\file.txt

# Windows to WSL path
wslpath -u 'C:\Users\Owner\Documents'
# Returns: /mnt/c/Users/Owner/Documents
```

## Path Mapping Table

| Windows Path | WSL Path |
|--------------|----------|
| `C:\Users\Owner` | `/mnt/c/Users/Owner` |
| `D:\projects` | `/mnt/d/projects` |
| `N:\Dropbox` | `/mnt/n/Dropbox` |
| `\\wsl$\Ubuntu\home\user` | `/home/user` |
