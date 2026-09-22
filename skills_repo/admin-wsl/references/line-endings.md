# Line Endings (CRLF/LF)

## Symptoms
- Scripts show `^M` characters
- Bash scripts fail with `bad interpreter` errors

## Prevention

### Configure Git

```bash
# Use LF in WSL
git config --global core.autocrlf input

# Optional: disable automatic conversion
git config --global core.autocrlf false
```

### Convert Existing Files

```bash
# Convert file to LF
dos2unix script.sh
```
