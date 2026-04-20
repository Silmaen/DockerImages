# Changelog

Format basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Les versions correspondent aux tags de release (si / quand des tags sont posés).

## [Unreleased]

### Added
- `_common/helpers.sh`, `_common/builder.sh`, `_common/devel.sh`,
  `_common/clang-llvm.sh` : scripts partagés entre toutes les images.
- Presets `devel-ubuntu2204` et `devel-ubuntu2404` : image unique par Ubuntu
  qui fusionne les toolchains gcc + clang et ajoute la suite de debuggers.
- Documentation : `README.md` avec diagrammes Mermaid, `CLAUDE.md` (guide
  interne), `CONTRIBUTING.md`, `SECURITY.md`.
- GitHub templates : PR, issues (bug report + feature request), workflow de
  lint.

### Changed
- **Refactor en trois couches sémantiques** :
  - `base` redevient du **runtime pur** (Python, poetry, libs runtime sans
    `-dev`).
  - `builder` concentre tout le build (cmake, ninja, `-dev` libs, Kitware,
    `depmanager`).
  - `devel` fusionne gcc + clang + debuggers.
- `Dockerfile` : copie `install/` entier sous `/tmp/install/` pour permettre
  les sourçages croisés entre scripts.
- `generator.py` : helper `_preset()` pour dédupliquer le dict.
- `all_ci.sh` : aligné sur l'ordre base → builder → devel.

### Fixed
- B-01 : shebang corrompu dans `clang-llvm-17.sh`.
- B-02 : chemin `libstdc++.so` hardcodé `x86_64-linux-gnu` (cassait arm64),
  résolu via glob filesystem.
- B-03 : `--image-name` jamais pris en compte en CLI (condition dupliquée).
- B-04 : home `/home/ubuntu` non déplacé lors du rename en `user`.
- B-05 : log de `generator.py` affichait `base_image` au lieu de l'image cible.
- B-06 : `all_ci.sh` ne construisait pas tous les presets déclarés.
- B-07 : Kitware absent de `ubuntu2404.sh`.
- B-08 : `lldb` non versionné dans `devel/debuggers.sh`.
- B-09 : `devel/clang-llvm-*` redéclaraient inutilement le repo LLVM.
- B-13 : `docker pull` qui tuait le process si la base privée n'existait pas.
- B-14 : `get_possible_platforms()` ne gérait qu'un seul node buildx.

### Removed
- Presets et scripts d'install des compilateurs secondaires (`gcc-12`,
  `clang-15`, `clang-llvm-16/17/19/20/21` et leurs devels) : on garde désormais
  **un gcc + un clang par Ubuntu**.
