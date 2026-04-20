# Bugs et pistes d'amélioration

Liste des tickets **ouverts** connus. L'historique des bugs résolus est dans
`git log` (cherche les commits "fix B-XX").

Statuts :
- **OUVERT** — connu, pas corrigé (volontairement ou pour plus tard).

---

## B-15 — `run_command` : `exit(-666)` rend le code non-testable — **OUVERT**

**Fichier** : `generator.py`, fonction `run_command`.

La fonction met le process à mort via `exit(-666)` dès qu'une commande échoue
hors `try_run=True`. Pas d'exception propagée. Conséquences :

- Impossible d'importer `generator.py` depuis un autre script sans risquer de
  tuer le caller sur la moindre erreur docker.
- `try`/`except` englobants inefficaces.

**Piste de fix** : lever une exception dédiée (`CommandError`) depuis
`run_command`, laisser `main()` appeler `sys.exit` au plus haut niveau.

---

## Observations (non-bugs)

- Pas de CI automatique (GitHub Actions / TeamCity) visible dans le repo. Un job
  `./generator.py --preset X --dry-run` sur chaque PR détecterait les presets
  cassés avant merge.
- `run_docker_build.sh` et `run_docker_bench.sh` à la racine viennent du repo
  sœur `OwlDependencies`. Leur place ici est à clarifier : outils de test
  d'image, ou artefacts destinés aux consumers ?
