# Contribuer

Merci pour l'intérêt. Ce repo produit des images Docker pour CI, run et dev — il
est à la fois petit et délicat (multi-arch, ordre de build, contrat avec les
consumers). Lis le `README.md` et le `CLAUDE.md` avant d'ouvrir une PR.

---

## Workflow

1. Fork / branche depuis `main`.
2. Modifier le code. Pour chaque changement d'image :
   - Si tu ajoutes un preset : `ci_images/install/<layer>/<nom>.sh` + entrée
     `_preset(...)` dans `generator.py` + entrée dans `all_ci.sh`.
   - Si tu modifies un `_common/*.sh` : vérifier **tous** les scripts qui
     l'utilisent (grep `_common/<nom>.sh`).
3. Valider en local (cf ci-dessous).
4. Ouvrir la PR en suivant le template.

## Valider en local

```bash
# Syntax sur tout
python3 -m py_compile generator.py
bash -n all_ci.sh
for f in ci_images/install/*/*.sh ci_images/install/_common/*.sh; do
    bash -n "$f" || echo "FAIL $f"
done

# Vérifier que chaque preset pointe vers un script existant
python3 -c "
import generator as g
from pathlib import Path
base = Path('ci_images/install')
for n, p in g.presets.items():
    assert (base / (p['setup'] + '.sh')).is_file(), n
print(f'{len(g.presets)} presets OK')
"

# Dry-run sur un preset
./generator.py --preset base-ubuntu2404 --dry-run

# Vrai build local (ne push pas)
./generator.py --preset base-ubuntu2404
```

Pour un vrai build multi-arch, cf `README.md` §9 (pré-requis hôte).

## Règles

- **Multi-arch** : tout script listé avec `linux/arm64` doit être arch-agnostique
  (pas de hardcode `x86_64-linux-gnu`). Préfère un glob filesystem à des options
  comme `clang -print-multiarch` (cf `BUGS.md` B-02).
- **Chaîne de dépendances** : respecte l'ordre `base → builder → devel` dans
  `all_ci.sh`.
- **Trois couches** :
  - `base` = **runtime seulement** (pas de compilateur, pas de `-dev`).
  - `builder` = un seul toolchain, pas les debuggers.
  - `devel` = fusion gcc + clang + debuggers.
- Les scripts d'install suivent le squelette de `.claude/rules/scripts-install.md`.
- `set -e` en tête de chaque script.
- `--no-install-recommends` pour `apt install` (fourni par `_common/helpers.sh`).
- Pas de `docker push` automatique depuis une PR. Le push se fait manuellement
  via `all_ci.sh` une fois mergé.
- **`CHANGELOG.md` à jour** : toute PR qui change le comportement d'une image,
  ajoute/supprime un preset, ou touche `generator.py` / `all_ci.sh` doit
  ajouter une entrée sous `## [Unreleased]` dans la sous-section appropriée
  (`Added`, `Changed`, `Fixed`, `Removed`, `Deprecated`, `Security`). Les PR
  purement doc / CI / refactor interne sans impact observable peuvent s'en
  dispenser.

## Commits

Style terse, une ligne, verbe à l'impératif. Exemples du log :

```
adding poetry
adding clang 21
improved images
better base image with updated pip
```

Référence un ticket / bug si pertinent : `fix B-02: glob-based libstdc++ resolution`.

## Ouvrir une issue

- **Bug dans une image** → `Bug report` (template GitHub, décris l'image, l'archi,
  la commande qui a échoué, les logs).
- **Proposer un nouveau preset / compilateur** → `Feature request`.
- **Question ouverte** → Discussions GitHub si activées, sinon issue.
