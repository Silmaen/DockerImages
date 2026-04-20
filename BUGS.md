# Rapport d'erreurs — audit du 2026-04-20

Audit statique des scripts d'install, du `Dockerfile`, de `generator.py`, et de
`all_ci.sh`. Les numéros de ligne renvoient à l'état du repo au moment de l'audit
(HEAD = `7b649bb`). Toute correction postérieure est notée en tête de bug.

**Mise à jour post-refactor** : suite à la restructuration en trois couches
sémantiques (base = run, builder = build, devel = dev), plusieurs bugs sont
devenus caducs parce que le code concerné a été réécrit ou supprimé. Ces cas
sont notés **CADUC** ci-dessous.

Statuts :
- **RÉSOLU** — corrigé explicitement.
- **CADUC** — le fichier ou la structure d'origine n'existe plus (refactor).
- **OUVERT** — connu, pas corrigé (volontairement ou pour plus tard).

---

## BUGS CRITIQUES (cassent un build)

### B-01 — `clang-llvm-17.sh` : shebang corrompu — **RÉSOLU**

**Fichier** : `ci_images/install/builder/clang-llvm-17.sh:1`
**Ligne originale** :
```sh
clang-llvm-16.sh#!/usr/bin/env bash
```

Le nom d'un autre fichier était collé devant le shebang.

**Correctif appliqué** : suppression du préfixe `clang-llvm-16.sh`.

---

### B-02 — Chemin libstdc++ hardcodé `x86_64-linux-gnu` → casse arm64 — **RÉSOLU (2ᵉ passe)**

**Fichiers concernés** :

- `ci_images/install/builder/clang-llvm-16.sh:33`
- `ci_images/install/builder/clang-llvm-17.sh:33`
- `ci_images/install/builder/clang-llvm-18.sh:33`
- `ci_images/install/builder/clang-llvm-19.sh:33`
- `ci_images/install/builder/clang-llvm-20.sh:33`
- `ci_images/install/builder/clang-llvm-21.sh:33`

Le triplet était figé → `libstdc++.so` symlink cassé en `linux/arm64`.

**1ʳᵉ tentative (non retenue)** : `MULTIARCH=$(clang-${CLANG_VERSION} -print-multiarch)`.
Échoue à l'exécution pour clang-16/17/18 : l'option `-print-multiarch` n'existe que
depuis LLVM 19 (`clang: error: unsupported option '-print-multiarch'`).

**Correctif appliqué (retenu)** : résolution du chemin via glob filesystem,
indépendante de l'archi **et** de la version de clang :

```bash
LIBSTDCPP_SO=$(ls /usr/lib/gcc/*-linux-gnu/${STDCPP_VER}/libstdc++.so 2>/dev/null | head -n1)
```

Centralisé dans `install/_common/clang-llvm.sh` (après le refactor profond).

---

### B-03 — `generator.py` : condition dupliquée, `image_name` jamais pris en CLI — **RÉSOLU**

**Fichier** : `generator.py:397-402`

La 3ᵉ condition testait `args.base_image` au lieu de `args.image_name`, rendant
`--image-name` inopérant en CLI.

**Correctif appliqué** : `if args.image_name not in [None, ""]:`.

---

## BUGS IMPORTANTS (dégradation fonctionnelle)

### B-04 — `ubuntu2404.sh` : rename `ubuntu` → `user` incomplet — **RÉSOLU**

**Fichier** : `ci_images/install/base/ubuntu2404.sh:21-23`

Le home restait `/home/ubuntu` → `$HOME` cassé pour l'utilisateur `user`.

**Correctif appliqué** : `usermod -l user -d /home/user -m ubuntu` (renomme le login,
déplace le home, conserve les permissions) + `groupmod -n user ubuntu`.

---

### B-05 — `generator.py` : message de progression affiche `base_image` au lieu de `output` — **RÉSOLU**

**Fichier** : `generator.py:434-436`

**Correctif appliqué** : le log affiche désormais `output:tag` comme image cible et
conserve `base_image` entre parenthèses pour contexte.

---

### B-06 — `all_ci.sh` : presets définis dans `generator.py` non construits — **RÉSOLU**

**Correctif appliqué** : `all_ci.sh` construit désormais l'intégralité des presets
déclarés (`builder-gcc12-ubuntu2204`, `clang-llvm-16/17/19/20/21-ubuntu2204`,
`devel-clang-llvm20/21-ubuntu2204`). Ordre respecté : base → builder → devel.

---

### B-07 — `ubuntu2204.sh` vs `ubuntu2404.sh` : dépôt Kitware uniquement sur 22.04 — **RÉSOLU**

**Correctif appliqué** : ajout du repo `apt.kitware.com` dans `ubuntu2404.sh` pour
homogénéiser la version de `cmake` entre les deux bases.

---

### B-08 — `devel/debuggers.sh` : `lldb` sans version → mismatch avec clang — **RÉSOLU**

**Correctif appliqué** :
- Création de `ci_images/install/devel/clang-18.sh`, variante distro qui installe
  `lldb-${CLANG_VERSION}` avec `CLANG_VERSION=18`, aligné sur le style des autres devel.
- Preset `devel-clang18-ubuntu2404` mis à jour (`setup: devel/clang-18`).
- Suppression de `ci_images/install/devel/debuggers.sh` (désormais orphelin).

---

### B-09 — Scripts `devel/clang-llvm-*` : re-ajoutent le repo LLVM — **RÉSOLU**

**Correctif appliqué** : retrait du bloc `curl | gpg --dearmor + echo deb ...` dans
`devel/clang-llvm-{18,20,21}.sh`. Les scripts s'appuient désormais sur le repo déjà
configuré par le builder parent.

---

## BUGS MINEURS (incohérence / risque futur)

### B-10 — `Dockerfile` : `PATH` référence poetry même quand poetry n'est pas installé — **OUVERT (non-pertinent après B-11)**

Devient non-pertinent après B-11 : poetry est désormais installé sur les deux bases,
le chemin référencé existe toujours. Ticket laissé ouvert pour trace.

---

### B-11 — `ubuntu2204.sh` n'installe pas poetry, `ubuntu2404.sh` oui — **RÉSOLU**

**Correctif appliqué** : ajout de `curl -sSL https://install.python-poetry.org | POETRY_HOME=/usr/poetry python3 -`
(déjà présent) + installation de `gcovr` pour cohérence avec `ubuntu2404.sh`.

---

### B-12 — Preset `builder-clang15-ubuntu2204` pointe vers un script atypique — **RÉSOLU**

**Correctif appliqué** : commentaire d'entête ajouté à `clang-15.sh` et `clang-18.sh`
pour expliciter qu'il s'agit des variantes *distro* (pas `apt.llvm.org`).

---

### B-13 — `generator.py:269` : `docker pull` sur image privée non-encore-buildée — **RÉSOLU**

**Correctif appliqué** : `run_command(f"docker pull {base}", try_run=True)` — un
`pull` qui échoue se traduit maintenant en warning au lieu de tuer le process.

---

### B-14 — `get_possible_platforms()` : fragile si `Platforms:` sur plusieurs lignes — **RÉSOLU**

**Correctif appliqué** : la fonction agrège désormais **toutes** les lignes
`Platforms:` retournées par `docker buildx inspect --bootstrap` et déduplique les
résultats.

---

### B-15 — `run_command` : `exit(-666)` rend le code non-testable — **OUVERT (refactor)**

Correction plus large (faire lever une exception + `sys.exit` seulement dans `main()`).
Pas touché dans cette passe. À envisager si `generator.py` est amené à être importé
depuis un autre script.

---

### B-16 — `README.md` : deux lignes, aucune doc — **RÉSOLU**

**Correctif appliqué** : `README.md` entièrement réécrit avec diagrammes Mermaid,
table des matières, guides d'ajout d'images et section dépannage.

---

## Refactor profond (2026-04-20)

Refactor en trois couches sémantiquement distinctes :

- `base` redevient une vraie image runtime (Python + poetry + runtime libs, **sans
  `-dev` ni outils de build**).
- Les outils de build (cmake, ninja, make, ccache, mold, patchelf, doxygen,
  graphviz, pkg-config, depmanager, gcovr) + les libs `-dev` + le repo Kitware +
  le repo apt.llvm.org sont centralisés dans `install/_common/builder.sh` et
  `install/_common/clang-llvm.sh`, puis sourcés / exécutés par chaque `builder/*.sh`.
- Les outils dev communs (gdb, valgrind, strace, ltrace, lcov, cppcheck,
  clang-format, bear, tmux, less, vim, htop, git-lfs) sont dans
  `install/_common/devel.sh`, sourcés par chaque `devel/*.sh`.
- Les scripts `devel/*.sh` n'ajoutent que `lldb-N` (clang) ou rien (gcc).
- Nouveaux presets : `devel-gcc12/13/14-*`, `devel-clang15-ubuntu2204`,
  `devel-clang-llvm16/17/19-ubuntu2204`, `builder-clang-llvm21-ubuntu2204`.
- `Dockerfile` copie désormais le répertoire `install/` en entier sous
  `/tmp/install/` pour permettre les sourçages croisés.
- Helper `_preset()` dans `generator.py` pour dédupliquer les définitions.

## Observations post-refactor

- `run_command` en fin d'erreur fait toujours `exit(-666)` (cf B-15). À refactorer si
  `generator.py` doit être importé depuis un autre script.
- Pas de CI automatique (GitHub Actions / TeamCity) visible dans le repo. Un job
  `./generator.py --preset X --dry-run` sur chaque PR détecterait les presets cassés
  avant merge.
- `run_docker_build.sh` / `run_docker_bench.sh` à la racine viennent du repo sœur
  `OwlDependencies`. Leur place ici est à clarifier (test d'image vs artefact
  utilisateur).
