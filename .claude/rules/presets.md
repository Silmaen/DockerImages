# Règle — `presets` dans `generator.py`

## Helper `_preset`

```python
def _preset(image_name, base, setup, platforms=("linux/amd64", "linux/arm64")):
    if "/" not in base and ":" not in base:
        base = f"{registry}/{namespace}/{base}"
    return {...}
```

- Si `base` est un nom court (pas de `:` ni `/`), le registry + namespace sont
  préfixés.
- Sinon (`ubuntu:26.04`, `debian:bookworm-slim`), la valeur est utilisée telle
  quelle.

## Déclaration

Trois presets par distro, un par couche :

```python
"base-<distro><version>":
    _preset("base-<distro><version>",    "<upstream:tag>",             "base/<distro><version>"),
"builder-<distro><version>":
    _preset("builder-<distro><version>", "base-<distro><version>",     "builder/<distro><version>"),
"devel-<distro><version>":
    _preset("devel-<distro><version>",   "builder-<distro><version>",  "devel/<distro><version>"),
```

## Nommage

- `<layer>` ∈ `{base, builder, devel}`.
- `<distro><version>` : `ubuntu2204`, `ubuntu2404`, `ubuntu2604`, futur
  `debian-bookworm`.
- **Pas de segment toolchain dans le nom** : depuis le refactor « builder =
  environnement de build complet », chaque builder contient gcc **et** clang.
  Les versions se lisent dans `install/builder/<distro>.sh`, pas dans le nom de
  l'image.

## Checklist pour ajouter un preset

- [ ] Le script d'install `ci_images/install/<setup>.sh` existe.
- [ ] La clé du dict `presets` = le 1ᵉʳ argument de `_preset`.
- [ ] `base` pointe vers une image qui existe (ou est construite avant dans
      `all_ci.sh`).
- [ ] Le script est multi-arch-safe si `platform` inclut `linux/arm64`.
- [ ] Entrée ajoutée à `all_ci.sh` **dans le bon ordre** (base → builder → devel).

## Ordre dans `all_ci.sh`

La chaîne est linéaire, une image par couche :

```
base-<distro>
  └── builder-<distro>
        └── devel-<distro>
```

Sinon `docker pull` sur la base échouera (certes maintenant toléré via
`try_run=True`, mais le build lui-même plantera ensuite faute de parent).
