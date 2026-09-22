# Known Issues Prevention (WSL)

## Issue 1: Editing .wslconfig from WSL
- Error: Changes don't take effect
- Prevention: Edit from Windows, then run `wsl --shutdown`

## Issue 2: Running apt from PowerShell
- Error: Command not found
- Prevention: Run inside WSL or use `wsl -e apt install ...`

## Issue 3: Windows paths in Linux scripts
- Error: Path not found
- Prevention: Convert paths with `wslpath`

## Issue 4: Line ending corruption
- Error: Scripts show `^M`
- Prevention: Use `dos2unix` or set Git `core.autocrlf` to input

## Issue 5: Memory not reclaimed
- Error: WSL VM keeps growing
- Prevention: Enable `autoMemoryReclaim=gradual` in `.wslconfig`
