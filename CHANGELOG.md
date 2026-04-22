# Changelog

Format basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Les versions correspondent aux tags de release (si / quand des tags sont posés).

## [Unreleased]

### Added (2026-04-20, soir)
- **`run_docker_bench.py`** : portage Python du script bash. Typage via
  dataclasses, export JSON via `--json`, CLI propre (`argparse`), compat env
  vars conservée. `run_docker_bench.sh` supprimé.
- Famille **Debian bookworm** : `base-debian-bookworm`,
  `builder-gcc12-debian-bookworm`, `builder-clang-llvm21-debian-bookworm`,
  `devel-debian-bookworm`. Produit des binaires compat Ubuntu 24.04 runtime
  (glibc 2.36 ≤ 2.39, libstdc++-12). Compilateurs les plus récents dispo sur
  la plateforme : gcc-12 natif + clang-21 via apt.llvm.org.
- Script commun `install/builder/clang-llvm-21.sh` (template paramétrique pour
  toute famille apt.llvm.org).

### Changed
- Doc (`README.md`, `CLAUDE.md`) : tableau des distros avec compat arm64
  émulé — note explicite sur le SIGSEGV bash pour glibc < 2.39.
- `BENCHMARK_arm64_emulation.md` §5 : validation empirique avec QEMU 10.2.1
  (via `tonistiigi/binfmt:qemu-v10.2.1`). Le fix upstream (commit
  `4b7b20a3`) ne couvre que ldconfig, pas bash/python → Ubuntu 26.04 ne
  débloquera **pas** arm64 émulé pour 22.04/bookworm. En revanche QEMU
  10.2.1 booste **×4-5** les perfs arm64 émulé 24.04 (émulation PAC/BTI
  plus rapide). Procédure d'install QEMU 10.2.1 documentée §5.3.
- `BENCHMARK_arm64_emulation.md` §2.2 / §5 (révision) : mesures sur un
  hôte **Ubuntu 25.10 + QEMU 10.1.0 packagé Debian** — `bash` et `python3`
  **fonctionnent** sur 22.04/bookworm arm64 émulé. Conclusion : les patches
  du packaging Debian/Ubuntu contiennent un fix complémentaire au commit
  upstream `4b7b20a3` ; tonistiigi (upstream pur) ne l'a pas.
- `BENCHMARK_arm64_emulation.md` §2.2 / §3.5 / §5.2 (validation définitive,
  2026-04-22) : mesures sur **Ubuntu 26.04 LTS + QEMU 10.2.1 packagé
  Debian** (machine ceos upgradée de 25.10). Confirme le fix stabilité et
  ajoute les ratios arm64/amd64 intra-machine + projection vers 24.04 dev.
  §3.6 normalise les temps inter-machines via les facteurs natifs.
- Retrait de `script_qemu/install-qemu-user-10.sh` et
  `qemu-binfmt-tonistiigi.service` : l'utilisateur force les upgrades
  quand nécessaire, le workaround tonistiigi n'apporte plus que la perf
  24.04 (qui devient caduc avec 26.04 LTS).
- `BENCHMARK_arm64_emulation.md` §6.4 : upgrade 26.04 LTS est la seule
  option durable listée (tonistiigi retiré).
- **Révision des toolchains sous contrainte "runtime sans PPA"
  (2026-04-22)** : les binaires produits doivent s'exécuter sur un Ubuntu
  stock Canonical (main+universe, sans PPA). gcc ne peut plus utiliser le
  PPA `ubuntu-toolchain-r/test` (les binaires linkent une libstdc++ plus
  récente que la stock). Retour à **gcc-12 sur 22.04** et **gcc-14 sur
  24.04** (max versions natives distro). Clang reste sur **clang-22 via
  apt.llvm.org** (tool uniquement, lié à libstdc++ stock grâce à la
  détection dynamique de `STDCPP_VER` dans `_common/clang-llvm.sh`).
  Presets :
    - `builder-gcc15-*` → `builder-gcc12-ubuntu2204` / `builder-gcc14-ubuntu2404`.
    - `builder-clang-llvm22-*` inchangé.
  Parents des `devel-*` mis à jour. `_common/clang-llvm.sh` corrigé :
  `STDCPP_VER` lu depuis `dpkg -s libstdc++6` au lieu de la version max
  dispo en apt.
- **Retrait de la famille Debian bookworm** (presets, scripts, doc) : non
  utilisée côté projet final. Les 4 presets correspondants et les scripts
  `install/base/debian-bookworm.sh`, `install/builder/gcc-12-bookworm.sh`,
  `install/builder/clang-llvm-21.sh` (ex-bookworm), `install/devel/debian-bookworm.sh`
  sont supprimés.
- **Renommé** `TODO_docker_images_optimization.md` →
  `BENCHMARK_arm64_emulation.md`. Réécrit en **rapport de résultats** (plus
  qu'un TODO) : méthodologie, tableaux de stabilité et perf, workarounds
  échoués, analyse cause racine, recommandations d'usage, maintenance.
- `run_docker_bench.sh` : réécrit pour tester les images **base** en amd64
  natif vs arm64 émulé. Sections stabilité (sh/bash/python3) et perf
  (sh loop, fork/exec, python startup, compile C). Variables d'env :
  `BENCH_PLATFORMS`, `BENCH_TIMEOUT`, `BENCH_STABILITY_ONLY`, `BENCH_PERF_ONLY`.

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
