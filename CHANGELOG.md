# Changelog

Format basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Les versions correspondent aux tags de release (si / quand des tags sont posés).

## [Unreleased]

### Changed (2026-09-22) — refactor des trois couches

- **`builder` devient *l'*environnement de build complet** : une **seule**
  image par distro, contenant **les deux** toolchains (gcc stock + clang-22)
  en plus des outils de build et de toutes les libs `-dev`. Les deux images
  builder mono-toolchain disparaissent :
    - `builder-gcc12-ubuntu2204` + `builder-clang-llvm22-ubuntu2204`
      → `builder-ubuntu2204`
    - `builder-gcc14-ubuntu2404` + `builder-clang-llvm22-ubuntu2404`
      → `builder-ubuntu2404`
  Le nom ne porte plus de segment toolchain : un job CI choisit gcc ou clang
  via `CC`/`CXX`, pas en changeant d'image.
- **`devel` ne contient plus que du debug / de l'analyse** et se base sur le
  `builder-<distro>` correspondant : clang n'y est plus réinstallé (il vient
  du builder), seul `lldb-${CLANG_VERSION}` s'y ajoute.
- **`base` reste strictement runtime** : ajout de `setup_default_user` dans
  `_common/helpers.sh` pour unifier la création (22.04) / le renommage
  (≥ 24.04) de l'utilisateur `user`.
- **Scripts d'install paramétriques** : les scripts de couche ne déclarent plus
  que des versions.
    - nouveau `_common/gcc.sh` (`GCC_VERSION`) ;
    - `_common/clang-llvm.sh` → `_common/clang.sh`, avec
      `CLANG_SOURCE=distro|llvm` pour choisir entre paquets de la distro et
      `apt.llvm.org` ;
    - `_common/builder.sh` enchaîne désormais `gcc.sh` puis `clang.sh` et exige
      `GCC_VERSION` / `CLANG_VERSION` ;
    - `_common/devel.sh` n'installe plus le `clang-format` non versionné
      (fourni versionné par `clang.sh`) et n'a plus besoin qu'on lui répète les
      versions : `_common/builder.sh` les écrit dans `/etc/ci-toolchain.env`
      (`GCC_VERSION`, `CLANG_VERSION`, `CLANG_SOURCE`) et `devel.sh` les relit
      depuis l'image parente. Un `devel/<distro>.sh` se réduit donc à un appel,
      et ne peut plus dériver de son builder.
    - `builder/gcc-12.sh`, `builder/gcc-14.sh`, `builder/clang-llvm-22.sh`
      supprimés au profit de `builder/ubuntu2204.sh`, `ubuntu2404.sh`,
      `ubuntu2604.sh`.
- **`_common/clang.sh` : `STDCPP_VER` vaut désormais `GCC_VERSION`** (fallback
  sur `dpkg -s libstdc++6` si le script est utilisé seul). L'ancienne détection
  par `libstdc++6` donnait `16` sur Ubuntu 26.04 — ce paquet y est construit
  depuis un snapshot gcc-16 alors que le gcc stock est 15.
- `_common/clang.sh` : les paquets `libclang*` sont listés explicitement
  (`libclang-N-dev`, `libclang-common-N-dev`, `libclang-rt-N-dev`) au lieu du
  glob apt `libclang*-N-dev`.
- Nouveau helper `register_gcc_alternatives` : centralise les alternatives
  `gcc`/`g++`/`gcov` et ajoute `cc` / `c++`. Les méta-paquets `gcc` / `g++` non
  versionnés ne sont plus installés (ils tiraient le gcc *par défaut* de la
  distro en plus de celui qu'on épingle), or ce sont eux qui fournissaient
  habituellement `/usr/bin/cc` et `/usr/bin/c++`, attendus par les `configure`
  autotools.
- Codename distro centralisé dans le helper `distro_codename`.
- Doc alignée : `README.md` (§1, §3.1, §3.2, §4, §5.1, §6, §10), `CLAUDE.md`,
  `.claude/rules/presets.md`, `.claude/rules/scripts-install.md`.

### Fixed (2026-09-22)

- **fix B-17** — la couche `devel` cassait le gcc épinglé par le `builder`.
  `lcov` a un `Depends: gcc` (le méta **non versionné**) : son installation
  tirait le gcc par défaut de la distro et écrasait `/usr/bin/gcc` par un
  fichier dpkg, cassant le groupe d'alternatives. Mesuré sur `devel-ubuntu2404`
  avant fix : `gcc`/`cc`/`gcov` en 13.3.0 alors que `g++`/`c++` étaient en
  14.2.0 — coverage `gcov` inutilisable. Idem 22.04 (gcc 11.4.0 vs g++ 12.3.0).
  26.04 n'était pas touché (gcc épinglé = défaut distro).
  `register_gcc_alternatives` utilise `--force` et est rappelé en fin de
  `_common/devel.sh`, après tous les `install_package`.
- **fix B-16** — alternative `ld.lld` manquante : `gcc -fuse-ld=lld` échouait
  avec `collect2: fatal error: cannot find 'ld'` (clang s'en sortait en
  trouvant `ld.lld` dans son propre `/usr/lib/llvm-N/bin`). `/usr/bin/ld.lld-N`
  est fourni par `lld-N` côté apt.llvm.org **et** côté distro, donc une seule
  alternative suffit dans `_common/clang.sh`.
- **fix B-15** — `generator.py` : `run_command` tuait l'interpréteur via
  `exit(-666)` (module non importable) et `process()` avalait l'exception, donc
  `main()` renvoyait 0 sur un build en échec et `all_ci.sh` (`set -e`)
  continuait la chaîne avec un parent cassé. Remplacé par une exception
  `CommandError` (avec `cmd` / `returncode`), `process()` laisse remonter, et
  l'entrée CLI traduit en code retour non nul. Vérifié : un build en échec
  renvoie désormais 255. `try_run=True` continue de n'émettre qu'un warning.
- **`7z` absent des images 22.04 / 24.04** : `p7zip` ne fournit que
  `/usr/bin/7zr`. Passage à **`p7zip-full`** sur 22.04 et 24.04. 26.04 reste sur
  `7zip` : la distro a retiré tous les paquets `p7zip*`, `7zip` y est le seul
  fournisseur de `/usr/bin/7z`.

### Removed (2026-09-22)

- **`run_docker_bench.py`** supprimé. Références retirées de `README.md` (la
  section « Outils auxiliaires » disparaît, §9/§10 renumérotées en §8/§9),
  `CLAUDE.md` (arbre du repo) et `BUGS.md`.
  `BENCHMARK_arm64_emulation.md` est conservé comme rapport historique, avec
  une note explicite : son protocole n'est plus outillé et doit être rejoué à
  la main. Les mentions de `run_docker_build.sh` (déjà absent du repo) sont
  nettoyées au passage.
- **`.github/workflows/lint.yml` supprimé** : pas de CI dans ce repo, c'est un
  choix assumé. Les templates issue / PR de `.github/` sont conservés (ce n'est
  pas de la CI). L'observation « pas de CI automatique » est retirée de
  `BUGS.md` et le choix est consigné dans `CLAUDE.md` §7 pour ne plus être
  reproposé.

### Added (2026-09-22)

- **Suite X11/XCB complète côté runtime dans `base/*.sh`** (les trois distros),
  en miroir exact de la liste `-dev` de `_common/builder.sh` : `libx11-xcb1`,
  `libxcb1`, `libfontenc1`, `libice6`, `libsm6`, `libxau6`, `libxaw7`,
  `libxcomposite1`, `libxcursor1`, `libxdamage1`, `libxdmcp6`, `libxext6`,
  `libxfixes3`, `libxi6`, `libxinerama1`, `libxkbfile1`, `libxmu6`, `libxmuu1`,
  `libxpm4`, `libxrandr2`, `libxrender1`, `libxres1`, `libxss1`, `libxt6`
  (`libxt6t64` sur 24.04 / 26.04), `libxtst6`, `libxv1`, `libxxf86vm1`,
  `libuuid1`, et les 20 `libxcb-*` correspondants.
- **Runtime Wayland + `xkb-data` + `libdecor-0-0` dans `base/*.sh`** :
  `libwayland-client0`, `libwayland-cursor0`, `libwayland-egl1`,
  `libwayland-server0`. `xkb-data` quitte le builder (c'est de la donnée
  runtime) et `libdecor-0-0` est désormais présent sur **22.04** aussi (il n'y
  était pas).
- **`libdecor-0-dev` ajouté à `_common/builder.sh`**, à côté de
  `libwayland-dev`. Retrait du `libx11-dev` en double.

- **Famille Ubuntu 26.04** (`resolute`) : `base-ubuntu2604`,
  `builder-ubuntu2604`, `devel-ubuntu2604`. Toolchains : **gcc-15** (stock
  main) + **clang-22 pris dans universe** — 26.04 ship clang 22.1, donc
  `CLANG_SOURCE=distro`, aucun repo apt.llvm.org ajouté. Kitware publie bien le
  codename `resolute`.
  Adaptations paquets vs 24.04 : `p7zip` → `7zip`, `python3-future` retiré de
  l'archive (remplacé par `python3-venv` pour poetry),
  `libpipewire-0.3-0` → `libpipewire-0.3-0t64`.

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
