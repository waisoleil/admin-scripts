# Contribuer

Ce document décrit les conventions à suivre pour ajouter ou modifier un script dans ce dépôt.

## Où ranger un script

Le chemin d'un script est toujours :

```
{Thematique}/{langage}/{nom-du-script}.{extension}
```

| Thématique  | Quand l'utiliser                                                        |
|-------------|-------------------------------------------------------------------------|
| `Reseau`    | Tout ce qui touche au réseau (connectivité, DNS, scans, supervision…)    |
| `Systemes`  | Tout ce qui touche à l'OS (services, backup, ressources, utilisateurs…)  |
| `Securite`  | Tout ce qui touche à la sécurité (audit, hardening, chiffrement…)        |

Si un script peut raisonnablement appartenir à deux catégories, choisis celle qui correspond à son **but principal**, pas à la techno qu'il utilise. Exemple : un script qui scanne des ports ouverts pour détecter une intrusion → `Securite`, pas `Reseau`.

| Langage      | Extension(s)         | Dossier        |
|--------------|----------------------|----------------|
| Bash         | `.sh`                | `bash/`        |
| Batch        | `.bat`, `.cmd`       | `batch/` (uniquement sous `Systemes/`) |
| PowerShell   | `.ps1`, `.psm1`      | `powershell/`  |
| Python       | `.py`                | `python/`      |

## Convention de nommage

Format : **`verbe-objet[-precision].extension`**

- **kebab-case** (mots séparés par des tirets, tout en minuscules)
- **sans accents** ni caractères spéciaux
- commence par un **verbe d'action** clair
- suivi de l'**objet** sur lequel le script agit
- optionnellement, une **précision** pour désambiguïser

### Verbes recommandés

| Verbe        | Sens                                              |
|--------------|---------------------------------------------------|
| `audit-`     | Inspecte sans modifier (lecture seule)            |
| `backup-`    | Sauvegarde des données                            |
| `check-`     | Vérifie un état, retourne un statut               |
| `clean-`     | Nettoie / supprime des éléments obsolètes         |
| `get-`       | Récupère et affiche une information               |
| `install-`   | Installe quelque chose                            |
| `monitor-`   | Surveille en continu                              |
| `restore-`   | Restaure depuis une sauvegarde                    |
| `scan-`      | Parcourt / explore pour découvrir des éléments    |
| `set-`       | Modifie une configuration                         |
| `sync-`      | Synchronise deux sources                          |
| `update-`    | Met à jour                                        |

### Exemples valides

- `backup-database.sh`
- `check-disk-space.ps1`
- `scan-open-ports.py`
- `clean-temp-files.bat`
- `audit-permissions-ntfs.ps1`
- `monitor-service-status.py`

### Exemples à éviter

| Mauvais                  | Pourquoi                              | À la place           |
|--------------------------|---------------------------------------|----------------------|
| `Backup_Database.sh`     | majuscules + underscore               | `backup-database.sh` |
| `script1.py`             | pas descriptif                        | `scan-open-ports.py` |
| `nettoyage-temp.sh`      | verbe en français, mélange de langues | `clean-temp-files.sh`|
| `ports.py`               | pas de verbe d'action                 | `scan-open-ports.py` |

## Ce qu'un script doit contenir

Au minimum, en tête de chaque script :

1. Un **commentaire de description** : à quoi sert le script en 1-2 lignes.
2. La **syntaxe d'usage** : comment l'appeler, quels arguments.
3. Les **prérequis** éventuels (paquets, droits admin, version minimale).

Exemple en Bash :

```bash
#!/usr/bin/env bash
# Sauvegarde compressée d'un dossier vers une destination.
# Usage : ./backup-folder.sh <source> <destination>
# Prérequis : tar, gzip

set -euo pipefail
# ...
```

## Mettre à jour le catalogue

Après avoir ajouté un script, **ajoute une ligne dans le tableau du README** de la thématique correspondante (`Reseau/README.md`, `Systemes/README.md` ou `Securite/README.md`) avec : nom, langage, description courte, exemple d'usage.

## Commits

Messages de commit courts et clairs, en français ou en anglais, mais cohérent dans le repo. Exemple : `add scan-open-ports.py` ou `fix: gestion erreur dans backup-home.sh`.
