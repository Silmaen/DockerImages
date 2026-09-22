# Bugs et pistes d'amélioration

Liste des tickets **ouverts** connus. L'historique des bugs résolus est dans
`git log` (cherche les commits "fix B-XX").

Statuts :
- **OUVERT** — connu, pas corrigé (volontairement ou pour plus tard).

---

Aucun ticket ouvert.

Derniers résolus (cf `git log`) :

- **B-15** — `generator.py` : `run_command` tuait le process via `exit(-666)`,
  rendant le module non importable et `process()` avalait l'erreur (donc
  `all_ci.sh` continuait sur une chaîne cassée). Remplacé par une exception
  `CommandError`, traduite en code retour par l'entrée CLI.
- **B-16** — alternative `ld.lld` manquante : `gcc -fuse-ld=lld` échouait
  (`collect2: fatal error: cannot find 'ld'`).
- **B-17** — la couche `devel` cassait le gcc épinglé par le `builder` :
  `lcov` dépend du méta-paquet `gcc` non versionné, qui écrase `/usr/bin/gcc`.
  Les alternatives sont désormais réaffirmées (`--force`) en fin de
  `_common/devel.sh`.

---

## Observations (non-bugs)

- **Absence de CI : volontaire.** Pas de workflow GitHub Actions / TeamCity, pas
  de job `--dry-run` sur les PR. Ne pas le reproposer.
- Les paquets qui fournissent `7z` diffèrent par distro : `p7zip-full` sur
  22.04 et 24.04, `7zip` sur 26.04 (qui a retiré tous les paquets `p7zip*`).
  Géré dans les `base/*.sh`, à re-vérifier à chaque nouvelle distro.
