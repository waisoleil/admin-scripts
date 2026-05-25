[🇫🇷 Français](./README_fr.md) | 🇬🇧 **English**

---

# Securite

Administration and automation scripts related to **security**: configuration audit, hardening, permission management, anomaly detection, encryption, certificate management, vulnerability scans, log analysis, integrity checks, etc.

> **Important note:** these scripts must only be used in authorized contexts (systems you administer, or with explicit consent). See [LICENSE](../LICENSE) and [CONTRIBUTING.md](../CONTRIBUTING.md).

## Organization

Scripts are organized by implementation language:

- [`bash/`](./bash/) — POSIX shell scripts (Linux, macOS, WSL)
- [`powershell/`](./powershell/) — PowerShell scripts (Windows, or pwsh cross-platform)
- [`python/`](./python/) — Python scripts (cross-platform)

Every script must follow the naming convention `verb-object[-detail].extension` (see [CONTRIBUTING.md](../CONTRIBUTING.md)).

## Script catalog

| Script name             | Language     | Description                                | Usage                                   |
|-------------------------|--------------|--------------------------------------------|-----------------------------------------|
| `audit-permissions.ps1` | PowerShell   | Audits NTFS permissions of a directory     | `.\audit-permissions.ps1 -Path C:\Data` |
|                         |              |                                            |                                         |
