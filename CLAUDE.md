# CLAUDE.md — guide interne pour Claude Code

Ce fichier est lu à chaque conversation Claude Code dans ce repo. Il documente les
règles, l'architecture et les pièges propres à ce projet. Avant d'écrire du code ici,
relis-le.

---

## 1. Mission du repo

Produire un ensemble d'**images Docker pour CI, déploiement et développement
C++/Python**, multi-arch (`linux/amd64` + `linux/arm64`), publiées sur
**`registry.argawaen.net/builder/`**.

Trois **couches sémantiquement distinctes** :

1. **base** — environnement de **run**. Contient uniquement le runtime Python,
   poetry, les libs runtime (**sans `-dev`**), utilitaires shell. Aucun compilateur,
   aucun outil de build. Utilisé pour exécuter l'application + ses tests.
2. **builder** — environnement **CI / build**. Ajoute le toolchain (gcc/clang), les
   outils de build (`cmake`, `ninja`, `make`, `ccache`, `mold`, `patchelf`, `doxygen`,
   `graphviz`, `pkg-config`), les libs `-dev`, `depmanager`, `gcovr`, `bear` (dans
   devel), le repo Kitware pour cmake récent.
3. **devel** — environnement **dev local**. Ajoute `gdb`, `lldb-N`, `valgrind`,
   `strace`, `ltrace`, `lcov`, `cppcheck`, `clang-format`, `bear`, `tmux`, `less`,
   `vim`, `htop`, `git-lfs`, `perf` (best-effort).

Chaîne : `ubuntu:X` → `base-*` → `builder-*-ubuntu*` → `devel-*-ubuntu*`.

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
│       │   ├── builder.sh    # tools + -dev libs pour TOUS les builder/*.sh
│       │   ├── devel.sh      # tools dev communs pour TOUS les devel/*.sh
│       │   └── clang-llvm.sh # template paramétrique apt.llvm.org
│       ├── base/             # couche runtime (ubuntu2204.sh, ubuntu2404.sh)
│       ├── builder/          # toolchains (gcc-*, clang-*, clang-llvm-*)
│       └── devel/            # debuggers (gcc.sh générique, clang-*, clang-llvm-*)
├── run_docker_build.sh       # wrapper docker run optimisé
├── run_docker_bench.sh       # microbench inter-images
├── README.md                 # doc utilisateur (Mermaid + guides)
├── BUGS.md                   # audit statique (OUVERT / RÉSOLU)
├── CLAUDE.md                 # ce fichier
└── TODO_docker_images_optimization.md
```

---

## 3. Contrat du `Dockerfile`

Deux `ARG` paramètrent le build :

- `BASE_IMAGE` — image parente.
- `SETUP` — chemin relatif (sans `.sh`) sous `ci_images/install/`
  (ex: `builder/clang-llvm-18`).

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

### 4.2 Squelette d'un `builder/<toolchain>.sh`

```bash
#!/usr/bin/env bash
set -e

# 1. Installer tout le commun (tools, -dev libs, depmanager, Kitware cmake)
bash /tmp/install/_common/builder.sh

# 2. Disposer des helpers pour la suite
. /tmp/install/_common/helpers.sh

# 3. Installer le compilateur spécifique
update_package_list
install_package g++-NN
# update-alternatives ...
clear_cache
```

Pour les variantes `apt.llvm.org`, utiliser plutôt :

```bash
#!/usr/bin/env bash
set -e
bash /tmp/install/_common/builder.sh
export CLANG_VERSION=18
bash /tmp/install/_common/clang-llvm.sh
```

### 4.3 Squelette d'un `devel/<variant>.sh`

Pour gcc (aucun lldb nécessaire) :

```bash
#!/usr/bin/env bash
set -e
bash /tmp/install/_common/devel.sh
```

Pour clang (ajouter `lldb-N` versionné) :

```bash
#!/usr/bin/env bash
set -e
bash /tmp/install/_common/devel.sh
. /tmp/install/_common/helpers.sh
update_package_list
install_package lldb-N
update-alternatives --install /usr/bin/lldb lldb /usr/bin/lldb-N N
clear_cache
```

### 4.4 Invariants transverses

- `set -e` en tête de chaque script.
- `--no-install-recommends` dans `install_package` (imposé via `_common/helpers.sh`).
- **Pas de hardcode d'architecture**. Pour trouver un chemin arch-spécifique, utiliser
  `$(clang -print-multiarch)` ou `$(dpkg-architecture -qDEB_HOST_MULTIARCH)`.
- Les scripts `_common/*.sh` sont **exécutés** (`bash /tmp/install/_common/X.sh`), pas
  sourcés, sauf `helpers.sh` qui ne contient que des définitions de fonctions.
- Ne **pas** dupliquer la logique Kitware / apt.llvm.org / install des outils dans
  chaque builder — c'est dans `_common/`.

---

## 5. `generator.py` — règles d'usage

### 5.1 Presets

Chaque image = une entrée dans le dict `presets`, créée via le helper `_preset` :

```python
"builder-clang18-ubuntu2404":
    _preset("builder-clang18-ubuntu2404", "base-ubuntu2404", "builder/clang-18"),
```

Le helper `_preset` préfixe le registry + namespace si `base` est un nom court
(sans `:` ni `/`). `ubuntu:24.04` (tag présent) est laissé tel quel.

### 5.2 Nommage

- `base-<distro><version>` (ex: `base-ubuntu2404`)
- `builder-<toolchain>-<distro><version>` (ex: `builder-clang18-ubuntu2404`)
- `devel-<toolchain>-<distro><version>` (ex: `devel-clang-llvm20-ubuntu2204`)

Préfixe `clang-llvm-N` (avec tiret) = build via `apt.llvm.org`.
Préfixe `clang-N` (sans `llvm`) = paquet natif de la distro.

### 5.3 Checklist quand tu ajoutes un preset

1. Créer/modifier le script `ci_images/install/<layer>/<nom>.sh`.
2. Ajouter l'entrée `_preset(...)` dans `generator.py`.
3. `./generator.py --preset <nom> --dry-run` pour vérifier la commande buildx.
4. Tester un vrai build sur l'archi native.
5. Si multi-arch, tester aussi l'archi émulée.
6. Ajouter l'appel dans `all_ci.sh` (ordre : base → builder → devel).

---

## 6. Multi-arch — piège principal

- Pas de triplet arch hardcodé (`x86_64-linux-gnu`, `aarch64-linux-gnu`).
- `UBUNTU_CODENAME` (variable issue de `/etc/os-release`) n'existe que sur Ubuntu. Sur
  Debian, utiliser `VERSION_CODENAME`. Les scripts communs `_common/builder.sh` et
  `_common/clang-llvm.sh` font déjà le fallback.
- Sous QEMU user-mode pour arm64 émulé, glibc 2.35 (Ubuntu 22.04) peut crasher à cause
  de MTE. Préférer une base Debian bookworm pour les arm64 émulés (cf TODO).

---

## 7. Règles comportementales

- **Langue** : l'utilisateur écrit en français, réponds en français.
- **Ne pas corriger un bug sans validation**. Liste-le dans `BUGS.md` d'abord.
- **Pas de `docker push` / `git push`** sans demande explicite.
- **Pas de `git reset --hard`, `prune -a`, force-push** sans demande explicite.
- Les commits respectent le style terse observé dans le log (`ef9c927 improved images`).

---

## 8. Contexte transverse

`TODO_docker_images_optimization.md` vient d'une session de diagnostic sur
`OwlDependencies` (repo sœur). Les recommandations de base (`debian:bookworm-slim` pour
builder arm64 sous QEMU) sont à implémenter **dans ce repo-ci** quand le feu vert est
donné, en ajoutant :
- `install/base/debian-bookworm.sh` (runtime-only, à l'image de `ubuntu2404.sh`)
- presets `base-debian-bookworm`, `builder-clang18-debian-bookworm`, éventuellement
  `devel-clang18-debian-bookworm`.
