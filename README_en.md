[🇫🇷 Français](./README_fr.md) | 🇬🇧 **English**

---

# admin-scripts

Personal collection of system administration scripts, organized by topic and by language. The goal is to centralize reusable tools to manage a fleet, a homelab, or servers on a daily basis.

## Repository structure

```
admin-scripts/
├── README.md          ← redirects to the FR or EN version
├── README_fr.md       ← French version
├── README_en.md       ← this file
├── LICENSE            ← MIT license
├── CONTRIBUTING.md    ← naming and organization conventions
├── .gitignore
│
├── Reseau/            ← networking scripts (connectivity, DNS, scans, etc.)
│   ├── README.md / README_fr.md / README_en.md
│   ├── bash/
│   ├── powershell/
│   └── python/
│
├── Systemes/          ← OS-related scripts (backup, services, resources, etc.)
│   ├── README.md / README_fr.md / README_en.md
│   ├── bash/
│   ├── batch/
│   ├── powershell/
│   └── python/
│
└── Securite/          ← security scripts (audit, hardening, etc.)
    ├── README.md / README_fr.md / README_en.md
    ├── bash/
    ├── powershell/
    └── python/
```

> Folder and file names are **without accents** to ensure cross-platform compatibility (Windows / Linux / macOS). The topic folders keep their French names (`Reseau`, `Systemes`, `Securite`) as canonical identifiers.

## Quick navigation

| Topic       | Use it for…                                               | Link                          |
|-------------|------------------------------------------------------------|-------------------------------|
| Network     | Diagnostics, monitoring, network configuration             | [Reseau/](./Reseau/)          |
| Systems     | OS maintenance, backups, service management                | [Systemes/](./Systemes/)      |
| Security    | Audit, hardening, access control, detection                | [Securite/](./Securite/)      |

Each topic folder contains its own `README_fr.md` / `README_en.md` with the catalog of available scripts (name, language, description, usage).

## Conventions

- **Script naming**: `verb-object[-detail].extension` in kebab-case (e.g. `backup-database.sh`, `scan-open-ports.py`).
- **Location**: a script goes into the `{Topic}/{language}/` folder.
- Full details in [CONTRIBUTING.md](./CONTRIBUTING.md).

## License

Distributed under the MIT license — see [LICENSE](./LICENSE).
