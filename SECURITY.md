# Politique de sécurité

## Versions supportées

Seule l'image `:latest` de chaque preset est maintenue. Les tags datés
(`YYYYMMDD-HHMM-<gitshort>`) sont immuables — pas de rétro-fix.

| Image                              | Support |
|------------------------------------|---------|
| `registry.argawaen.net/builder/*:latest` | ✅ |
| Tags datés antérieurs              | ❌ reconstruire depuis `main` |

## Signaler une vulnérabilité

Si tu découvres une vulnérabilité dans une image ou dans le code de build :

1. **Ne pas ouvrir d'issue publique.**
2. Utiliser la fonctionnalité GitHub **"Report a vulnerability"** sur
   https://github.com/Silmaen/DockerImages/security/advisories/new.

Inclure :
- L'image et son tag (ex: `builder-clang18-ubuntu2404:latest`).
- L'architecture si pertinente (`linux/amd64` / `linux/arm64`).
- Les étapes de reproduction.
- La version de l'outil / paquet vulnérable (sortie de `dpkg -l <paquet>`).

## Ce qui est **dans** le scope

- CVE sur les paquets installés (rebuild de l'image, bump de version distro).
- Fuite de secret dans une image (à signaler d'urgence).
- Escalade de privilèges liée à la configuration `USER` / permissions des
  fichiers embarqués.

## Ce qui est **hors** scope

- CVE présent dans l'image mais sans vecteur exploitable (ex: lib installée
  mais jamais chargée). Signalable mais non prioritaire.
- Comportements liés au runtime hôte (binfmt, seccomp, kernel).
- Vulnérabilités dans des projets tiers qu'on buildrait avec ces images.
