[🇫🇷 Français](./README_fr.md) | 🇬🇧 **English**

---

# Systemes

Administration and automation scripts related to **operating systems**: service management, backups, cleanup, deployment, package maintenance, user management, resource monitoring (CPU/RAM/disk), task scheduling, etc.

## Organization

Scripts are organized by implementation language:

- [`bash/`](./bash/) — POSIX shell scripts (Linux, macOS, WSL)
- [`batch/`](./batch/) — Batch scripts (`.bat` / `.cmd`) for Windows
- [`powershell/`](./powershell/) — PowerShell scripts (Windows, or pwsh cross-platform)
- [`python/`](./python/) — Python scripts (cross-platform)

Every script must follow the naming convention `verb-object[-detail].extension` (see [CONTRIBUTING.md](../CONTRIBUTING.md)).

## Script catalog

| Script name           | Language   | Description                                  | Usage                                  |
|-----------------------|------------|----------------------------------------------|----------------------------------------|
| `backup-home.sh`      | Bash       | Compressed backup of the user's home folder  | `./backup-home.sh /path/destination`   |
|                       |            |                                              |                                        |
