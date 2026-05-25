🇫🇷 **Français** | [🇬🇧 English](./README_en.md)

---

# admin-scripts

Collection personnelle de scripts d'administration système, classés par thématique et par langage. L'objectif est de centraliser des outils réutilisables pour gérer un parc, un homelab, ou des serveurs au quotidien.

## Structure du dépôt

```
admin-scripts/
├── README.md          ← redirige vers la version FR ou EN
├── README_fr.md       ← ce fichier
├── README_en.md       ← version anglaise
├── LICENSE            ← licence MIT
├── CONTRIBUTING.md    ← conventions de nommage et d'organisation
├── .gitignore
│
├── Reseau/            ← scripts liés au réseau (connectivité, DNS, scans, etc.)
│   ├── README.md / README_fr.md / README_en.md
│   ├── bash/
│   ├── powershell/
│   └── python/
│
├── Systemes/          ← scripts liés à l'OS (backup, services, ressources, etc.)
│   ├── README.md / README_fr.md / README_en.md
│   ├── bash/
│   ├── batch/
│   ├── powershell/
│   └── python/
│
└── Securite/          ← scripts liés à la sécurité (audit, hardening, etc.)
    ├── README.md / README_fr.md / README_en.md
    ├── bash/
    ├── powershell/
    └── python/
```

> Les noms de dossiers et de fichiers sont **sans accents** pour assurer la compatibilité multiplateforme (Windows / Linux / macOS).

## Navigation rapide

| Thématique  | À utiliser pour…                                          | Lien                          |
|-------------|------------------------------------------------------------|-------------------------------|
| Réseau      | Diagnostic, supervision, configuration réseau              | [Reseau/](./Reseau/)          |
| Systèmes    | Maintenance OS, sauvegardes, gestion de services           | [Systemes/](./Systemes/)      |
| Sécurité    | Audit, hardening, contrôle d'accès, détection              | [Securite/](./Securite/)      |

Chaque dossier thématique contient son propre `README_fr.md` / `README_en.md` avec le catalogue des scripts disponibles (nom, langage, description, usage).

## Conventions

- **Nommage des scripts** : `verbe-objet[-precision].extension` en kebab-case (ex : `backup-database.sh`, `scan-open-ports.py`).
- **Rangement** : un script va dans le dossier `{Thematique}/{langage}/`.
- Détails complets dans [CONTRIBUTING.md](./CONTRIBUTING.md).

## Licence

Distribué sous licence MIT — voir [LICENSE](./LICENSE).
