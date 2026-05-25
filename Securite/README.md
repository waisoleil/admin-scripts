# Securite

Scripts d'administration et d'automatisation liés à la **sécurité** : audit de configuration, hardening, gestion des permissions, détection d'anomalies, chiffrement, gestion de certificats, scans de vulnérabilités, analyse de logs, contrôle d'intégrité, etc.

> **Note importante :** ces scripts doivent uniquement être utilisés dans un cadre autorisé (systèmes que vous administrez, ou avec consentement explicite). Voir [LICENSE](../LICENSE) et [CONTRIBUTING.md](../CONTRIBUTING.md).

## Organisation

Les scripts sont rangés par langage d'implémentation :

- [`bash/`](./bash/) — scripts shell POSIX (Linux, macOS, WSL)
- [`powershell/`](./powershell/) — scripts PowerShell (Windows, ou pwsh multiplateforme)
- [`python/`](./python/) — scripts Python (multiplateforme)

Chaque script doit respecter la convention de nommage `verbe-objet[-precision].extension` (voir [CONTRIBUTING.md](../CONTRIBUTING.md)).

## Catalogue des scripts

| Nom du script         | Langage     | Description                                  | Usage                                  |
|-----------------------|-------------|----------------------------------------------|----------------------------------------|
| `audit-permissions.ps1` | PowerShell | Audite les permissions NTFS d'un répertoire | `.\audit-permissions.ps1 -Path C:\Data` |
|                       |             |                                              |                                        |
