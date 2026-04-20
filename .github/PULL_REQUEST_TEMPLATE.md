## Résumé

<!-- 1-2 phrases : quoi et pourquoi. -->

## Type

- [ ] Nouveau preset / compilateur
- [ ] Modification d'un preset existant
- [ ] Bugfix
- [ ] Doc / tooling / CI
- [ ] Autre :

## Changements

<!-- Liste des fichiers touchés + pourquoi. -->

## Validation

- [ ] `python3 -m py_compile generator.py` passe
- [ ] `bash -n` passe sur tous les scripts modifiés
- [ ] Dry-run : `./generator.py --preset <nom> --dry-run`
- [ ] Build natif réussi : `./generator.py --preset <nom>`
- [ ] Build arm64 émulé testé (si multi-arch) : `--platform linux/arm64`
- [ ] `all_ci.sh` mis à jour si nouveau preset
- [ ] `CHANGELOG.md` mis à jour sous `## [Unreleased]` (sauf doc / CI / refactor
      interne sans impact observable)

## Impact

<!-- Rupture de compat ? Rebuild de toute une chaîne nécessaire ?
     Consumer(s) du registry impactés ? -->

## Ticket lié

<!-- Référence à un B-XX du BUGS.md ou une issue GitHub. -->
