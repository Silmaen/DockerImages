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
- Sinon (`ubuntu:24.04`, `debian:bookworm-slim`), la valeur est utilisée telle
  quelle.

## Déclaration

```python
"<layer>-<toolchain>-<distro><version>":
    _preset("<layer>-<toolchain>-<distro><version>",
            "<base short name | upstream:tag>",
            "<layer>/<setup script sans .sh>"),
```

## Nommage

- `<layer>` ∈ `{base, builder, devel}`.
- `<toolchain>` : `gcc14`, `clang18`, `clang-llvm-18`, etc.
  - `clang-llvm-N` (avec tirets) = build via `apt.llvm.org`.
  - `clang-N` (sans `llvm`) = paquet natif de la distro.
- `<distro><version>` : `ubuntu2204`, `ubuntu2404`, futur `debian-bookworm`.

## Checklist pour ajouter un preset

- [ ] Le script d'install `ci_images/install/<setup>.sh` existe.
- [ ] La clé du dict `presets` = le 1ᵉʳ argument de `_preset`.
- [ ] `base` pointe vers une image qui existe (ou est construite avant dans
      `all_ci.sh`).
- [ ] Le script est multi-arch-safe si `platform` inclut `linux/arm64`.
- [ ] Entrée ajoutée à `all_ci.sh` **dans le bon ordre** (base → builder → devel).

## Ordre dans `all_ci.sh`

La chaîne doit être respectée :

```
base-<distro>
  ├── builder-<T1>-<distro>
  │     └── devel-<T1>-<distro>
  └── builder-<T2>-<distro>
        └── devel-<T2>-<distro>
```

Sinon `docker pull` sur la base échouera (certes maintenant toléré via
`try_run=True`, mais le build lui-même plantera ensuite faute de parent).
