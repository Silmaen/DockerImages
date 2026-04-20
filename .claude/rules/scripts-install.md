# Règle — scripts `install/**/*.sh`

## Organisation

```
install/
├── _common/        # scripts partagés, exécutés ou sourcés par les autres
│   ├── helpers.sh      # fonctions bash — SOURCÉ (`. helpers.sh`)
│   ├── builder.sh      # commun à tous les builder/*.sh — EXÉCUTÉ (`bash builder.sh`)
│   ├── devel.sh        # commun à tous les devel/*.sh — EXÉCUTÉ
│   └── clang-llvm.sh   # template apt.llvm.org — EXÉCUTÉ avec CLANG_VERSION exporté
├── base/           # scripts runtime (pas de compilateur, pas de -dev)
├── builder/        # scripts toolchain
└── devel/          # scripts debuggers / outils de dev
```

**Règle** : `helpers.sh` est sourcé ; tous les autres `_common/*.sh` sont exécutés
(leur `set -e` et leur `clear_cache` leur sont propres).

## Squelette d'un script `base/<distro>.sh`

```bash
#!/usr/bin/env bash
set -e
. /tmp/install/_common/helpers.sh

# 1. Timezone, locale
# 2. Créer / renommer l'utilisateur `user` (Dockerfile termine USER user)
# 3. apt install : RUNTIME libs (sans -dev) + python + poetry + archive tools
# 4. clear_cache
```

## Squelette d'un script `builder/<toolchain>.sh`

```bash
#!/usr/bin/env bash
set -e
bash /tmp/install/_common/builder.sh          # tools + -dev + depmanager
. /tmp/install/_common/helpers.sh             # accès aux fonctions

update_package_list
install_package <compilateur>
# update-alternatives ...
clear_cache
```

Pour une variante `apt.llvm.org`, remplacer par :

```bash
#!/usr/bin/env bash
set -e
bash /tmp/install/_common/builder.sh
export CLANG_VERSION=NN
bash /tmp/install/_common/clang-llvm.sh
```

## Squelette d'un script `devel/<distro>.sh`

Convention du repo : **une seule image `devel-<distro>` par Ubuntu**, construite
au-dessus du `builder-gcc-<distro>` et qui **ajoute le toolchain clang** + la
suite de debuggers. Le développeur peut ainsi compiler en gcc ou en clang depuis
le même conteneur.

Pour une distro qui a clang dans ses paquets (ex: Ubuntu 24.04) :

```bash
#!/usr/bin/env bash
set -e
. /tmp/install/_common/helpers.sh

update_package_list
install_package clang-NN lld-NN llvm-NN clang-tidy-NN libclang-rt-NN-dev lldb-NN
# update-alternatives pour clang, clang++, lld, clang-tidy, llvm-cov, lldb
bash /tmp/install/_common/devel.sh
clear_cache
```

Pour une distro qui a besoin de `apt.llvm.org` (ex: Ubuntu 22.04) :

```bash
#!/usr/bin/env bash
set -e
export CLANG_VERSION=NN
bash /tmp/install/_common/clang-llvm.sh     # installe clang + alt + symlink libstdc++
bash /tmp/install/_common/devel.sh
. /tmp/install/_common/helpers.sh
update_package_list
install_package lldb-NN
update-alternatives --install /usr/bin/lldb lldb /usr/bin/lldb-NN NN
clear_cache
```

## Invariants

- `set -e` en tête.
- `--no-install-recommends` (fourni par `install_package`).
- **Pas de chemin arch-spécifique hardcodé**. Options par ordre de robustesse :
  - Glob filesystem : `ls /usr/lib/gcc/*-linux-gnu/${N}/libstdc++.so` (marche
    partout, toutes versions clang) ← **préféré** quand on a un point d'ancrage
    connu (fichier installé).
  - `$(dpkg-architecture -qDEB_HOST_MULTIARCH)` si `dpkg-dev` est installé.
  - `$(clang -print-multiarch)` ← **à éviter** : l'option n'existe que depuis
    LLVM 19, cf B-02 dans `BUGS.md`.
- Codename distro : `${UBUNTU_CODENAME:-${VERSION_CODENAME}}` (le fallback gère Debian).
- Ne pas réinstaller les outils déjà posés par `_common/builder.sh`. Ne pas réajouter
  `apt.llvm.org` ou Kitware dans un script qui le reçoit déjà via son parent.

## Quand tu ajoutes un script

- Si c'est un nouveau compilateur → calque sur le même type existant.
- Si c'est une nouvelle distro de base → tu es responsable de :
  - création de l'utilisateur `user` avec `$HOME` valide,
  - installation de poetry,
  - installation des runtime libs (pas des `-dev` — c'est le builder qui s'en
    occupera),
  - génération de la locale `C.UTF-8`.
