🇫🇷 **Français** | [🇬🇧 English](./README_en.md)

---

# Systemes

Scripts d'administration et d'automatisation liés aux **systèmes d'exploitation** : gestion des services, sauvegardes, nettoyage, déploiement, maintenance des paquets, gestion des utilisateurs, monitoring de ressources (CPU/RAM/disque), planification de tâches, etc.

## Organisation

Les scripts sont rangés par langage d'implémentation :

- [`bash/`](./bash/) — scripts shell POSIX (Linux, macOS, WSL)
- [`batch/`](./batch/) — scripts Batch (`.bat` / `.cmd`) pour Windows
- [`powershell/`](./powershell/) — scripts PowerShell (Windows, ou pwsh multiplateforme)
- [`python/`](./python/) — scripts Python (multiplateforme)

Chaque script doit respecter la convention de nommage `verbe-objet[-precision].extension` (voir [CONTRIBUTING.md](../CONTRIBUTING.md)).

## Catalogue des scripts

| Nom du script         | Langage     | Description                                  | Usage                                  |
|-----------------------|-------------|----------------------------------------------|----------------------------------------|
| `backup-home.sh`      | Bash        | Sauvegarde compressée du dossier home utilisateur | `./backup-home.sh /chemin/destination` |
|                       |             |                                              |                                        |
