# Règle — scripts `install/**/*.sh`

## Organisation

```
install/
├── _common/        # scripts partagés, exécutés ou sourcés par les autres
│   ├── helpers.sh      # fonctions bash — SOURCÉ (`. helpers.sh`)
│   ├── builder.sh      # commun à tous les builder/*.sh — EXÉCUTÉ (`bash builder.sh`)
│   ├── gcc.sh          # installeur gcc paramétrique — EXÉCUTÉ (GCC_VERSION)
│   ├── clang.sh        # installeur clang paramétrique — EXÉCUTÉ (CLANG_VERSION, CLANG_SOURCE)
│   └── devel.sh        # commun à tous les devel/*.sh — EXÉCUTÉ (lit /etc/ci-toolchain.env)
├── base/           # scripts runtime (pas de compilateur, pas de -dev)
├── builder/        # un script par distro — déclare les versions de toolchain
└── devel/          # un script par distro — outillage debug / analyse
```

**Règle** : `helpers.sh` est sourcé ; tous les autres `_common/*.sh` sont exécutés
(leur `set -e` et leur `clear_cache` leur sont propres). Comme ils sont exécutés,
leurs paramètres doivent être **exportés** par l'appelant.

`_common/builder.sh` appelle lui-même `gcc.sh` puis `clang.sh` : c'est ce qui fait
qu'un builder embarque **les deux** toolchains. L'ordre compte — `clang.sh` a
besoin du `libstdc++-${GCC_VERSION}-dev` posé par `gcc.sh`.

## Squelette d'un script `base/<distro>.sh`

```bash
#!/usr/bin/env bash
set -e
. /tmp/install/_common/helpers.sh

# 1. Timezone
# 2. setup_default_user   (crée ou renomme `user`, le Dockerfile finit USER user)
# 3. apt install : RUNTIME libs (sans -dev) + python + poetry + archive tools
# 4. locale-gen
# 5. clear_cache
```

## Squelette d'un script `builder/<distro>.sh`

Trois `export` et un appel. **Aucun `install_package` ici** : si un paquet manque
pour tout le monde il va dans `_common/builder.sh`, s'il est propre à un
compilateur il va dans `gcc.sh` / `clang.sh`.

```bash
#!/usr/bin/env bash
set -e

export GCC_VERSION=14        # version STOCK de la distro, jamais un PPA
export CLANG_VERSION=22
export CLANG_SOURCE=llvm     # 'distro' si la distro ship déjà cette version

bash /tmp/install/_common/builder.sh
```

`CLANG_SOURCE` :
- `distro` — paquets de la distro, aucun repo tiers ajouté (ex: Ubuntu 26.04
  ship clang-22 dans universe) ;
- `llvm` — `apt.llvm.org` (défaut), pour les distros trop vieilles (22.04, 24.04).

## Squelette d'un script `devel/<distro>.sh`

Convention du repo : **une seule image `devel-<distro>` par Ubuntu**, construite
au-dessus de `builder-<distro>` qui fournit déjà gcc **et** clang. Le devel
n'ajoute **que** du debug / de l'analyse — rien qui serve à compiler.

```bash
#!/usr/bin/env bash
set -e

bash /tmp/install/_common/devel.sh
```

Aucune version à répéter : `_common/builder.sh` écrit `GCC_VERSION`,
`CLANG_VERSION` et `CLANG_SOURCE` dans `/etc/ci-toolchain.env`, que
`_common/devel.sh` relit depuis l'image parente (un `export` explicite avant
l'appel prend le dessus). C'est ce qui garantit que `lldb-N` et le gcc
réaffirmé correspondent bien au builder.

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
- Codename distro : `$(distro_codename)` (helper, gère le fallback Debian
  `VERSION_CODENAME`). Ne pas sourcer `/etc/os-release` à la main.
- La libstdc++ contre laquelle clang link est `STDCPP_VER`, qui vaut par défaut
  `GCC_VERSION`. **Ne pas** la déduire de `dpkg -s libstdc++6` : sur 26.04 ce
  paquet vient d'un snapshot gcc-16 alors que le gcc stock est 15.
- Ne pas réinstaller les outils déjà posés par `_common/builder.sh`. Ne pas réajouter
  `apt.llvm.org` ou Kitware dans un script qui le reçoit déjà via son parent —
  c'est notamment le cas de `devel/*` pour `lldb-N`.
- Les alternatives gcc passent par `register_gcc_alternatives` (helpers), qui
  utilise `--force`. Sans ça, tout paquet dépendant du méta `gcc` non versionné
  (`lcov`) écrase `/usr/bin/gcc` par le gcc **par défaut** de la distro et
  désaligne `gcc`/`gcov` de `g++` (fix B-17).
- Toute installation de paquets faite **après** `register_gcc_alternatives` doit
  la rappeler en fin de script.

## Quand tu ajoutes un script

- Nouvelle version de toolchain sur une distro existante → changer les `export`
  de `builder/<distro>.sh` (et `devel/<distro>.sh` si `CLANG_VERSION` bouge).
- Nouvelle distro de base → tu es responsable de :
  - `setup_default_user`,
  - installation de poetry,
  - installation des runtime libs (pas des `-dev` — c'est le builder qui s'en
    occupera), en vérifiant les renommages de paquets (transition `t64`,
    `p7zip` → `7zip`, paquets retirés de l'archive comme `python3-future`),
  - génération de la locale `C.UTF-8`,
  - vérification que Kitware — et `apt.llvm.org` si `CLANG_SOURCE=llvm` —
    publient bien le codename.
