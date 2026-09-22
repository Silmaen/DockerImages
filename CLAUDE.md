# CLAUDE.md — guide interne pour Claude Code

Ce fichier est lu à chaque conversation Claude Code dans ce repo. Il documente les
règles, l'architecture et les pièges propres à ce projet. Avant d'écrire du code ici,
relis-le.

---

## 1. Mission du repo

Produire un ensemble d'**images Docker pour CI, déploiement et développement
C++/Python**, multi-arch (`linux/amd64` + `linux/arm64`), publiées sur
**`registry.argawaen.net/builder/`**.

Trois **couches sémantiquement distinctes**, chaîne **linéaire**, **une seule
image par couche et par distro** :

1. **base** — environnement de **run**. Python, poetry, libs runtime (**aucun
   `-dev`**), utilitaires shell. Aucun compilateur, aucun outil de build.
   Contient **toute la suite X11/XCB runtime** + le runtime Wayland,
   `xkb-data` et `libdecor-0-0`, en miroir de la liste `-dev` du builder.
2. **builder** — **L'**environnement de build (CI). Contient **les deux**
   toolchains (gcc stock + clang) + `cmake`, `ninja`, `make`, `ccache`, `mold`,
   `patchelf`, `doxygen`, `graphviz`, `pkg-config`, **toutes** les libs `-dev`
   (X11/XCB complet, `libwayland-dev`, `libdecor-0-dev`), repo Kitware. Un job CI choisit son compilateur via `CC`/`CXX`, pas via
   l'image.
3. **devel** — environnement **dev local**. Le builder **plus** la suite de
   debug/analyse (`gdb`, `lldb-N`, `valgrind`, `strace`, `ltrace`, `gperf`,
   `lcov`, `cppcheck`, `bear`, `perf`, `tmux`, `less`, `vim`, `htop`,
   `git-lfs`). **Rien de nécessaire à la compilation n'est ici** — c'est dans le
   builder.

Chaîne :

```
ubuntu:NN.04 ──▶ base-ubuntuNNNN ──▶ builder-ubuntuNNNN ──▶ devel-ubuntuNNNN
                 (runtime seul)      (gcc + clang + -dev)    (+ debuggers)
```

**Règle de sélection des compilateurs** : pour chaque Ubuntu, **un** gcc (la
version stock de la distro) + **un** clang, les deux dans le builder. Le clang
vient :
- du **paquet distro** quand elle ship la version voulue (Ubuntu 26.04 →
  clang-22 dans universe) ;
- d'**apt.llvm.org** sinon (Ubuntu 22.04 et 24.04 → clang-22).

Jeu actuel (9 presets) :

| Distro       | base               | builder (gcc + clang)                        | devel               |
|--------------|--------------------|----------------------------------------------|---------------------|
| Ubuntu 22.04 | `base-ubuntu2204`  | `builder-ubuntu2204` — gcc-12 + clang-22 LLVM| `devel-ubuntu2204`  |
| Ubuntu 24.04 | `base-ubuntu2404`  | `builder-ubuntu2404` — gcc-14 + clang-22 LLVM| `devel-ubuntu2404`  |
| Ubuntu 26.04 | `base-ubuntu2604`  | `builder-ubuntu2604` — gcc-15 + clang-22 distro | `devel-ubuntu2604` |

### Contrainte de portabilité — règle dure du projet

Les binaires produits doivent être exécutables sur **un Ubuntu stock (main +
universe Canonical, sans PPA)** de la même révision. Conséquences :

- **gcc = version native stock uniquement** (pas de PPA `toolchain-r/test`),
  sinon le binaire lie une libstdc++ plus récente que celle shipped :
  - 22.04 → gcc-12 max (libstdc++6 stock = 12.3.0)
  - 24.04 → gcc-14 max (libstdc++6 stock = 14.2.0)
  - 26.04 → gcc-15 (le `gcc`/`g++` par défaut de main)
- **clang peut venir d'`apt.llvm.org`** (tool de build, pas d'incidence
  runtime) **à condition** d'être lié à la libstdc++ stock.
  `_common/clang.sh` prend `STDCPP_VER=${GCC_VERSION}` — donc exactement la
  libstdc++ du gcc stock choisi — avec fallback sur la version de `libstdc++6`
  installée si le script est utilisé seul.
  ⚠️ 26.04 ship un `libstdc++6` construit depuis un **snapshot gcc-16** : la
  détection par `dpkg -s libstdc++6` donnerait `16`, donc des en-têtes de gcc
  non-stock. D'où le choix de s'aligner sur `GCC_VERSION`.
- `cmake` récent via Kitware OK (tool de build uniquement).

**arm64 émulé** : corrigé sur hôte Ubuntu 26.04 LTS (QEMU 10.2.1 packagé
Debian). Sur 24.04 host avec QEMU 8.2.2, bash crashe sur les images glibc
< 2.39. Détails dans `BENCHMARK_arm64_emulation.md` §2.

---

## 2. Structure du repo

```
.
├── generator.py              # wrapper docker buildx
├── all_ci.sh                 # build + push la totalité des presets
├── ci_images/
│   ├── Dockerfile            # UN SEUL Dockerfile, ARG BASE_IMAGE + ARG SETUP
│   └── install/
│       ├── _common/          # scripts partagés
│       │   ├── helpers.sh    # fonctions bash communes
│       │   ├── builder.sh    # tools + -dev libs + appelle gcc.sh ET clang.sh
│       │   ├── gcc.sh        # installeur gcc paramétrique (GCC_VERSION)
│       │   ├── clang.sh      # installeur clang paramétrique (CLANG_VERSION, CLANG_SOURCE)
│       │   └── devel.sh      # outillage debug/analyse pour TOUS les devel/*.sh
│       ├── base/             # couche runtime (ubuntu2204/2404/2604.sh)
│       ├── builder/          # ubuntu2204/2404/2604.sh — 3 export + builder.sh
│       └── devel/            # ubuntu2204/2404/2604.sh — appellent devel.sh
├── README.md                 # doc utilisateur (Mermaid + guides)
├── BUGS.md                   # audit statique (OUVERT / RÉSOLU)
├── CLAUDE.md                 # ce fichier
└── BENCHMARK_arm64_emulation.md  # rapport de bench arm64 émulé vs amd64 natif
```

---

## 3. Contrat du `Dockerfile`

Deux `ARG` paramètrent le build :

- `BASE_IMAGE` — image parente.
- `SETUP` — chemin relatif (sans `.sh`) sous `ci_images/install/`
  (ex: `builder/ubuntu2404`).

Le `Dockerfile` copie **tout** le répertoire `install/` sous `/tmp/install/`, exécute
`bash /tmp/install/${SETUP}.sh`, puis **supprime** `/tmp/install`. C'est ce qui permet
à chaque script de sourcer ses communs (`/tmp/install/_common/*.sh`).

Le `Dockerfile` termine par `USER user`. **Toute image doit garantir l'existence de
l'utilisateur `user` et d'un `$HOME` valide pour lui** — c'est la responsabilité du
script `base/*.sh`.

---

## 4. Conventions des scripts d'install

### 4.1 Squelette d'un `base/<distro>.sh`

```bash
#!/usr/bin/env bash
set -e
. /tmp/install/_common/helpers.sh

# Timezone, user creation/renaming
# apt install (runtime only, pas de -dev, pas d'outils de build)
# poetry install
# locale
# clear_cache
```

### 4.2 Squelette d'un `builder/<distro>.sh`

Trois `export` et un appel, rien d'autre — toute la logique est dans
`_common/builder.sh`, qui enchaîne `gcc.sh` puis `clang.sh` :

```bash
#!/usr/bin/env bash
set -e

export GCC_VERSION=14
export CLANG_VERSION=22
export CLANG_SOURCE=llvm     # 'distro' si la distro ship la bonne version

bash /tmp/install/_common/builder.sh
```

### 4.3 Squelette d'un `devel/<distro>.sh`

```bash
#!/usr/bin/env bash
set -e

bash /tmp/install/_common/devel.sh
```

Rien à déclarer : `_common/builder.sh` écrit les versions choisies dans
`/etc/ci-toolchain.env` (`GCC_VERSION`, `CLANG_VERSION`, `CLANG_SOURCE`) et
`_common/devel.sh` les relit depuis l'image parente. Un devel ne peut donc pas
dériver de son builder. Exporter `GCC_VERSION` / `CLANG_VERSION` avant l'appel
reste possible et prend le dessus.

### 4.4 Invariants transverses

- `set -e` en tête de chaque script.
- `--no-install-recommends` dans `install_package` (imposé via `_common/helpers.sh`).
- **Pas de hardcode d'architecture**. Pour trouver un chemin arch-spécifique, utiliser
  `$(clang -print-multiarch)` ou `$(dpkg-architecture -qDEB_HOST_MULTIARCH)`.
- Les scripts `_common/*.sh` sont **exécutés** (`bash /tmp/install/_common/X.sh`), pas
  sourcés, sauf `helpers.sh` qui ne contient que des définitions de fonctions.
  Les variables de paramétrage doivent donc être **exportées**.
- Ne **pas** dupliquer la logique Kitware / apt.llvm.org / install des outils dans
  chaque builder — c'est dans `_common/`.
- Un script `base/*.sh` appelle `setup_default_user` (helpers) — il gère à la
  fois les images qui ship un `ubuntu` uid 1000 (≥ 24.04) et celles qui n'en ont
  pas (22.04).
- Les alternatives gcc/g++/cc/c++/gcov passent **toujours** par
  `register_gcc_alternatives` (helpers), jamais par des `update-alternatives`
  à la main : le helper utilise `--force`, indispensable car `lcov` tire le
  méta-paquet `gcc` non versionné qui écrase `/usr/bin/gcc` (cf fix B-17).

---

## 5. `generator.py` — règles d'usage

### 5.1 Presets

Chaque image = une entrée dans le dict `presets`, créée via le helper `_preset` :

```python
"builder-ubuntu2404":
    _preset("builder-ubuntu2404", "base-ubuntu2404", "builder/ubuntu2404"),
```

Le helper `_preset` préfixe le registry + namespace si `base` est un nom court
(sans `:` ni `/`). `ubuntu:24.04` (tag présent) est laissé tel quel.

### 5.2 Nommage

- `base-<distro><version>` (ex: `base-ubuntu2404`)
- `builder-<distro><version>` (ex: `builder-ubuntu2404`)
- `devel-<distro><version>` (ex: `devel-ubuntu2404`)

Plus de segment toolchain dans le nom : le builder contient gcc **et** clang, le
nom de l'image n'a donc plus à les distinguer. Les versions sont visibles dans
`install/builder/<distro>.sh` et dans le README §4.1.

### 5.3 Checklist quand tu ajoutes un preset

1. Créer/modifier le script `ci_images/install/<layer>/<distro>.sh`.
2. Ajouter l'entrée `_preset(...)` dans `generator.py`.
3. `./generator.py --preset <nom> --dry-run` pour vérifier la commande buildx.
4. Tester un vrai build sur l'archi native.
5. Si multi-arch, tester aussi l'archi émulée.
6. Ajouter l'appel dans `all_ci.sh` (ordre : base → builder → devel).

---

## 6. Multi-arch — piège principal

- Pas de triplet arch hardcodé (`x86_64-linux-gnu`, `aarch64-linux-gnu`).
- `UBUNTU_CODENAME` (variable issue de `/etc/os-release`) n'existe que sur Ubuntu. Sur
  Debian, utiliser `VERSION_CODENAME`. Le helper `distro_codename` de
  `_common/helpers.sh` fait déjà le fallback — l'utiliser plutôt que de sourcer
  `/etc/os-release` à la main.
- Sous QEMU user-mode pour arm64 émulé, glibc 2.35 (Ubuntu 22.04) peut crasher à cause
  de MTE. Préférer une base Debian bookworm pour les arm64 émulés (cf TODO).

---

## 7. Règles comportementales

- **Langue** : l'utilisateur écrit en français, réponds en français.
- **Ne pas corriger un bug sans validation**. Liste-le dans `BUGS.md` d'abord.
- **Pas de `docker push` / `git push`** sans demande explicite.
- **Pas de `git reset --hard`, `prune -a`, force-push** sans demande explicite.
- Les commits respectent le style terse observé dans le log (`ef9c927 improved images`).
- **Pas de CI dans ce repo — c'est volontaire.** Ne propose pas de workflow
  GitHub Actions / TeamCity, ni de job `--dry-run` sur les PR. Le workflow
  `lint.yml` qui existait a été supprimé pour cette raison. Les vérifications
  (`bash -n`, `--dry-run`, cohérence presets ↔ scripts) se font à la main avant
  commit. Les templates issue / PR de `.github/` restent, eux.
- **Pas d'outil de bench dans ce repo.** `run_docker_bench.py` et
  `run_docker_build.sh` ont été supprimés ; `BENCHMARK_arm64_emulation.md` reste
  comme rapport historique, son protocole n'est plus outillé ici.
- **`CHANGELOG.md` à jour** : dès qu'un changement est observable côté image
  (ajout/suppression de preset, modif d'un script d'install, modif de
  `generator.py` ou `all_ci.sh`, bugfix), ajoute une entrée sous `## [Unreleased]`
  dans la sous-section adaptée (`Added`, `Changed`, `Fixed`, `Removed`,
  `Deprecated`, `Security`). Les modifs purement internes (doc, CI, refactor
  sans impact sur l'image produite) peuvent s'en dispenser.

---

## 8. Contexte transverse

`BENCHMARK_arm64_emulation.md` vient d'une session de diagnostic sur
`OwlDependencies` (repo sœur). Les recommandations de base (`debian:bookworm-slim` pour
builder arm64 sous QEMU) sont à implémenter **dans ce repo-ci** quand le feu vert est
donné, en ajoutant :
- `install/base/debian-bookworm.sh` (runtime-only, à l'image de `ubuntu2404.sh`)
- presets `base-debian-bookworm`, `builder-clang18-debian-bookworm`, éventuellement
  `devel-clang18-debian-bookworm`.
