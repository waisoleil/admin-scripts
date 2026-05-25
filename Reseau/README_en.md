[🇫🇷 Français](./README_fr.md) | 🇬🇧 **English**

---

# Reseau

Administration and automation scripts related to **networking**: connectivity diagnostics, traffic analysis, interface configuration, monitoring, DNS/DHCP management, latency tests, port scans, etc.

## Organization

Scripts are organized by implementation language:

- [`bash/`](./bash/) — POSIX shell scripts (Linux, macOS, WSL)
- [`powershell/`](./powershell/) — PowerShell scripts (Windows, or pwsh cross-platform)
- [`python/`](./python/) — Python scripts (cross-platform)

Every script must follow the naming convention `verb-object[-detail].extension` (see [CONTRIBUTING.md](../CONTRIBUTING.md)).

## Script catalog

| Script name             | Language   | Description                                  | Usage                                  |
|-------------------------|------------|----------------------------------------------|----------------------------------------|
| `check-connectivity.sh` | Bash       | Checks connectivity against a list of hosts  | `./check-connectivity.sh hosts.txt`    |
|                         |            |                                              |                                        |
