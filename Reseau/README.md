# Reseau

Scripts d'administration et d'automatisation liés au **réseau** : diagnostic de connectivité, analyse de trafic, configuration d'interfaces, supervision, gestion DNS/DHCP, tests de latence, scans de ports, etc.

## Organisation

Les scripts sont rangés par langage d'implémentation :

- [`bash/`](./bash/) — scripts shell POSIX (Linux, macOS, WSL)
- [`powershell/`](./powershell/) — scripts PowerShell (Windows, ou pwsh multiplateforme)
- [`python/`](./python/) — scripts Python (multiplateforme)

Chaque script doit respecter la convention de nommage `verbe-objet[-precision].extension` (voir [CONTRIBUTING.md](../CONTRIBUTING.md)).

## Catalogue des scripts

| Nom du script         | Langage     | Description                                  | Usage                                  |
|-----------------------|-------------|----------------------------------------------|----------------------------------------|
| `check-connectivity.sh` | Bash      | Vérifie la connectivité vers une liste d'hôtes | `./check-connectivity.sh hosts.txt`    |
|                       |             |                                              |                                        |
