# Benchmark — émulation arm64 sous QEMU sur hôte amd64

Ce document consigne les résultats de tests de **stabilité et performance** des
images Docker de ce repo lorsqu'elles sont exécutées en `linux/arm64` émulé via
QEMU user-mode sur un hôte amd64 (cas TeamCity DinD + poste dev amd64),
comparées à la même image en `linux/amd64` natif.

Le protocole est reproductible via `./run_docker_bench.py` (à la racine du
repo). Les mesures ci-dessous doivent être retesstées après chaque upgrade
majeur d'hôte (kernel, `qemu-user-static`).

---

## Sommaire

1. [Méthodologie](#1-méthodologie)
2. [Résultats de stabilité (sh / bash / python)](#2-résultats-de-stabilité)
3. [Résultats de performance (microbench)](#3-résultats-de-performance)
4. [Workarounds testés — tous échoués](#4-workarounds-testés)
5. [Analyse et cause racine](#5-analyse-et-cause-racine)
6. [Recommandations d'usage](#6-recommandations-dusage)
7. [Maintenance des images à jour](#7-maintenance-des-images-à-jour)
8. [Annexe — pré-requis hôte](#8-annexe--pré-requis-hôte)
9. [Sources](#9-sources)

---

## 1. Méthodologie

### 1.1 Hôte de mesure (2026-04-20)

- Ubuntu 24.04.3 LTS, kernel 6.8.
- Docker 29.1.3, buildx 0.30.1.
- `qemu-user-static` **1:8.2.2+ds-0ubuntu1.16** (release Ubuntu 24.04).
- Handler `binfmt_misc` actif : `/usr/libexec/qemu-binfmt/aarch64-binfmt-P`,
  flags `POF`.
- `kernel.apparmor_restrict_unprivileged_userns=0`.

### 1.2 Commande unitaire

```bash
timeout --kill-after=3 15 docker run --rm --init \
  --platform=<linux/amd64|linux/arm64> <image> <shell> -c '<payload>'
```

### 1.3 Images testées

Upstream (référence) : `ubuntu:22.04`, `ubuntu:24.04`, `ubuntu:25.04`,
`debian:bullseye`, `debian:bookworm-slim`, `debian:trixie-slim`.

Publiées par ce repo : `base-ubuntu2204`, `base-ubuntu2404`,
`base-debian-bookworm`.

### 1.4 Payloads

- **Stabilité** : `echo OK` (un fork + exec, expose l'init glibc).
- **Perf** : boucle bash arithmétique 2000 itérations, 20× `/bin/true`, Python
  startup + import stdlib, compile C simple `-O2`.

---

## 2. Résultats de stabilité

Test : `echo OK` via le shell indiqué. **`sh`** sur Ubuntu/Debian = `dash`.

### 2.1 Hôte Ubuntu 24.04 + QEMU 8.2.2 distro (mesures 2026-04-20)

| Image                  | glibc | `sh` (dash) | `bash`                | `python3`         |
|------------------------|-------|-------------|-----------------------|-------------------|
| `ubuntu:22.04`         | 2.35  | ✅ 539 ms    | 💥 **SIGSEGV** 606 ms | —                 |
| `base-ubuntu2204`      | 2.35  | ✅ 556 ms    | 💥 **SIGSEGV** 607 ms | 💥 SIGSEGV 782 ms |
| `debian:bullseye`      | 2.31  | ✅           | 💥 **SIGSEGV**        | —                 |
| `debian:bookworm-slim` | 2.36  | ✅           | 💥 **SIGSEGV**        | —                 |
| `base-debian-bookworm` | 2.36  | ✅           | 💥 **SIGSEGV**        | 💥 SIGSEGV        |
| `ubuntu:24.04`         | 2.39  | ✅ 522 ms    | ✅ 557 ms              | —                 |
| `base-ubuntu2404`      | 2.39  | ✅ 559 ms    | ✅ 550 ms              | ✅ 1425 ms         |
| `ubuntu:25.04`         | 2.41  | ✅           | ✅                     | —                 |
| `debian:trixie-slim`   | 2.41  | ✅           | ✅                     | —                 |

### 2.2 Hôte Ubuntu 26.04 LTS + QEMU 10.2.1 (paquet debian `1:10.2.1+ds-1ubuntu3`)

Mesures du 2026-04-22 sur la machine ceos, après `do-release-upgrade` vers
26.04 LTS (codename resolute). Kernel 7.0.0-14-generic.

| Image                  | glibc | `sh` (dash) | `bash`        | `python3`      |
|------------------------|-------|-------------|---------------|----------------|
| `ubuntu:22.04`         | 2.35  | ✅ 263 ms    | ✅ **241 ms**  | —              |
| `debian:bookworm-slim` | 2.36  | ✅ 218 ms    | ✅ **238 ms**  | —              |
| `base-ubuntu2204`      | 2.35  | ✅ 217 ms    | ✅ **246 ms**  | ✅ **489 ms**   |
| `ubuntu:24.04`         | 2.39  | ✅ 243 ms    | ✅ 249 ms     | —              |
| `base-ubuntu2404`      | 2.39  | ✅ 212 ms    | ✅ 251 ms     | ✅ 528 ms       |

Confirmation empirique :

- **Le crash bash/python arm64 sur glibc < 2.39 disparaît complètement** dès
  que l'hôte dispose de QEMU 10.x **packagé Debian/Ubuntu**. Le cutoff
  identifié en §2.1 n'était pas dû à la glibc du conteneur, mais à la
  version QEMU de l'hôte.
- Observé aussi sur Ubuntu 25.10 + QEMU 10.1.0 debian — même comportement.

### 2.3 Hôte Ubuntu 24.04 + tonistiigi/binfmt 10.2.1 — ne suffit PAS

Le handler upstream `tonistiigi/binfmt:qemu-v10.2.1` (compilé depuis le
master QEMU, sans patches Debian) **ne corrige pas** le crash bash sur
22.04/bookworm arm64 (cf §5.1). Il apporte uniquement le gain de perf sur
24.04 arm64 émulé.

---

## 3. Résultats de performance

Microbench reproductible via `./run_docker_bench.py` (dash utilisé partout pour
éviter le crash bash en glibc < 2.39).

### 3.1 Conventions de ratio

- **amd64 Docker** : ratio par rapport au **host natif** (sans Docker). Mesure
  l'overhead de conteneurisation Docker pour une image donnée.
- **arm64 Docker (émulé)** : ratio par rapport à **la même image en amd64**.
  Isole l'overhead **QEMU user-mode pur**, à image identique.

### 3.2 Référence host natif (mesures 2026-04-20)

| Métrique              | Temps  |
|-----------------------|--------|
| `sh loop 2000`        | 3 ms   |
| `20× /bin/true`       | 13 ms  |
| `python3 -c pass`     | 10 ms  |
| `python3 imports`     | 49 ms  |
| `cc -O2 hello.c`      | 37 ms  |

### 3.3 Overhead Docker amd64 (ratio vs host natif)

| Image                    | sh loop     | 20× true     | py pass      | py imports   |
|--------------------------|-------------|--------------|--------------|--------------|
| `ubuntu:22.04`           | 6 ms (2.0×) | 11 ms (0.8×) | n/a          | n/a          |
| `ubuntu:24.04`           | 3 ms (1.0×) | 14 ms (1.1×) | n/a          | n/a          |
| `debian:bookworm-slim`   | 6 ms (2.0×) | 10 ms (0.8×) | n/a          | n/a          |
| `base-ubuntu2404`        | 4 ms (1.3×) | 10 ms (0.8×) | 21 ms (2.1×) | 59 ms (1.2×) |

Overhead Docker sur amd64 reste ~1× — bruit de mesure sur des payloads si
courts, pas de pénalité réelle.

### 3.4 Overhead QEMU arm64 (ratio vs amd64 même image)

| Image                    | sh loop            | 20× true           | py pass            | py imports         |
|--------------------------|--------------------|--------------------|--------------------|--------------------|
| `ubuntu:22.04`           | 58 ms (**9.7×**)   | 431 ms (39.2×)     | (crash bash, n/a)  | —                  |
| `ubuntu:24.04`           | 351 ms (**117×**)  | 408 ms (29.1×)     | n/a                | n/a                |
| `debian:bookworm-slim`   | 57 ms (**9.5×**)   | 417 ms (41.7×)     | (crash bash, n/a)  | —                  |
| `base-ubuntu2404`        | 340 ms (**85×**)   | 411 ms (41.1×)     | 1696 ms (**81×**)  | 4245 ms (**72×**)  |

### 3.5 Mesures sur hôte Ubuntu 26.04 LTS + QEMU 10.2.1 debian (machine ceos)

Ratios arm64 vs amd64 même image (natif `sh loop = 6 ms`, `py imports = 49 ms`) :

| Image              | sh loop            | 20× true         | py pass          | py imports       |
|--------------------|--------------------|------------------|------------------|------------------|
| `ubuntu:22.04`     | 84 ms (**16.8×**)  | 395 ms (49.4×)   | n/a              | —                |
| `ubuntu:24.04`     | 84 ms (**28.0×**)  | 388 ms (43.1×)   | n/a              | —                |
| `debian:bookworm`  | 83 ms (**20.8×**)  | 410 ms (51.3×)   | n/a              | —                |
| `base-ubuntu2204`  | 86 ms (**10.8×**)  | 407 ms (50.9×)   | 440 ms (23.2×)   | 774 ms (15.5×)   |
| `base-ubuntu2404`  | 81 ms (**16.2×**)  | 402 ms (44.7×)   | 468 ms (18.7×)   | 823 ms (13.3×)   |

### 3.6 Normalisation inter-machines (ceos → équivalent 24.04 dev)

Les deux machines n'ont pas le même CPU :

| Métrique natif  | dev (24.04) | ceos (26.04) | facteur dev/ceos |
|-----------------|-------------|--------------|------------------|
| `sh loop`       | 3 ms        | 6 ms         | **×0.50** (ceos 2× plus lent sur burst single-thread) |
| `fork_true20`   | 11 ms       | 12 ms        | ×0.92            |
| `py pass`       | 14 ms       | 15 ms        | ×0.93            |
| `py imports`    | 47 ms       | 49 ms        | ×0.96            |
| `cc -O2`        | 37 ms       | 35 ms        | ×1.06            |

→ Machines quasi-équivalentes sur workloads large (python, compile), mais
ceos ~2× plus lent sur boucles arithmétiques pures. Pour comparer 26.04
ceos à 24.04 dev, on applique le facteur par métrique.

**Temps arm64 ceos projetés à l'échelle 24.04 dev** :

| Image / métrique            | ceos mesuré | projection dev | dev + tonistiigi 10.2.1 | dev + QEMU 8.2 |
|-----------------------------|------------:|---------------:|------------------------:|---------------:|
| `base-ubuntu2204` sh loop   | 86 ms       | **43 ms**      | 66 ms                   | 58 ms          |
| `base-ubuntu2404` sh loop   | 81 ms       | **41 ms**      | 83 ms                   | 340 ms (85×)   |
| `base-ubuntu2404` py pass   | 468 ms      | **437 ms**     | 437 ms (tonistiigi)     | 1696 ms (81×)  |
| `base-ubuntu2404` py imports| 823 ms      | **790 ms**     | 807 ms (tonistiigi)     | 4245 ms (72×)  |

### 3.7 Comparaison finale des 3 configurations testées

Ratio arm64/amd64 de la même image, intra-machine (valeur invariante du CPU host) :

| Image              | dev + QEMU 8.2 | dev + tonistiigi 10.2.1 | **ceos 26.04 + QEMU 10.2.1 debian** |
|--------------------|---------------:|------------------------:|------------------------------------:|
| `ubuntu:22.04`     | 9.7×           | 13.2×                   | 16.8×                               |
| `ubuntu:24.04`     | **117×**       | 19.8×                   | **28×**                             |
| `debian:bookworm`  | 9.5×           | 21.3×                   | 20.8×                               |
| `base-ubuntu2404`  | 85×            | 28×                     | 16×                                 |

### 3.8 Observations

- **Gain ×5-8 sur 24.04 arm64 dès qu'on passe de QEMU 8.2 à QEMU 10.x**.
  Les optimisations émulation PAC/BTI / LSE sont dans le core QEMU 10.
- **Les ratios `base-ubuntu2404` arm64 python sont à ~13-19× sur 26.04**,
  contre ~72-81× sur QEMU 8.2 : un `pytest` qui prenait 10 min en QEMU 8.2
  tombe à ~90 s sur 26.04.
- Le fork/exec (`20× /bin/true`) reste un overhead plancher ~30-50× sur
  tous les QEMU — inhérent à binfmt-P, pas de fix en vue.
- Sur 22.04/bookworm arm64, bash + python redeviennent utilisables sur
  26.04 — ce qui permet de ne plus retirer `linux/arm64` de ces presets.

---

## 4. Workarounds testés

Toutes les tentatives visant à masquer le crash bash sur glibc < 2.39 ont
échoué :

| Tentative                                                                                     | Résultat                                                                                     |
|-----------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------|
| `QEMU_CPU=cortex-a72` / `cortex-a76` / `neoverse-n1`                                          | SIGSEGV                                                                                      |
| `QEMU_CPU=max,-mte,-mte2,-mte3`                                                               | QEMU rejette les flags négatifs (rc=1)                                                       |
| `QEMU_CPU=max,-mte,...,-sve,-sve2,-sme,-lse128,-pauth`                                        | idem                                                                                         |
| `GLIBC_TUNABLES=glibc.cpu.hwcaps=-MTE`                                                        | SIGSEGV                                                                                      |
| `GLIBC_TUNABLES=glibc.cpu.hwcaps=-MTE,-SVE,-SVE2,-SVE2P1,-SME,-LSE128,-BTI,-PAC`              | SIGSEGV                                                                                      |
| `--security-opt seccomp=unconfined`                                                           | SIGSEGV                                                                                      |
| Combinaison de tout ce qui précède                                                            | SIGSEGV                                                                                      |
| `tonistiigi/binfmt:latest` (override non effectif — binfmt sticky)                            | SIGSEGV                                                                                      |
| **`tonistiigi/binfmt:qemu-v10.2.1`** (handler remplacé après `systemctl stop binfmt-support`) | **SIGSEGV** (testé 2026-04-20 : perf ×4 sur 24.04, mais crash bash 22.04/bookworm identique) |

---

## 5. Analyse et cause racine

- **glibc < 2.39** lit des hwcaps récents (`MTE`, `SVE2`, `SVE2P1`, `LSE128`,
  `BTI`, `PAC`) lors de son init (`__libc_start_main` → `cpu_features_init`)
  pour choisir les implémentations SIMD de ses fonctions (memcpy, strcmp, …).
  QEMU user-mode 8.2.2 expose ces hwcaps via `AT_HWCAP*` mais ne les émule
  pas correctement → déréférence invalide → SIGSEGV.
- **glibc ≥ 2.39** (Ubuntu 24.04, Debian trixie) filtre mieux les hwcaps
  exposés par l'OS et reste sur des variantes safe → pas de crash.
- **dash** n'initialise quasi rien au startup (pas de readline, pas de
  détection locale) → ne déclenche jamais le chemin glibc problématique.
  **bash** initialise readline + locale + signal handlers → touche aux
  `cpu_features` via des strings ops optimisées → crash.
- Les **tunables `GLIBC_TUNABLES`** sont lus après l'init hwcaps : trop tard
  pour désactiver MTE. Même les `QEMU_CPU=max,-mte` ne sont pas acceptés par
  QEMU 8.2.2 (seules les options positives sont permises sur `-cpu max`).

### 5.1 Fix — tonistiigi upstream vs paquet Debian/Ubuntu

Le comportement diffère radicalement selon la source du binaire QEMU :

| Source QEMU                                       |  bash 22.04 arm64 |  bash bookworm arm64 |
|---------------------------------------------------|:-----------------:|:--------------------:|
| Ubuntu 24.04 package (QEMU 8.2.2)                 | 💥 SIGSEGV        | 💥 SIGSEGV           |
| `tonistiigi/binfmt:qemu-v10.2.1` (upstream)       | 💥 **SIGSEGV**    | 💥 **SIGSEGV**       |
| Ubuntu 25.10 package (QEMU 10.1.0 debian)         | ✅ OK             | ✅ OK                |
| **Ubuntu 26.04 LTS package** (QEMU 10.2.1 debian) | ✅ **OK**         | ✅ **OK**            |

**Explication** : le paquet Debian/Ubuntu de QEMU applique un jeu de
patches (`debian/patches/`) qui cherry-pick des fixes avant ou à côté de
l'upstream. Le build tonistiigi compile depuis le master QEMU sans ces
patches, d'où le crash persistant à version numérique pourtant plus
récente (10.2.1 upstream > 10.1.0 debian).

[Launchpad bug 2072564](https://bugs.launchpad.net/ubuntu/+source/qemu/+bug/2072564)
trace le cas ldconfig (commit upstream `4b7b20a3`) ; le patch qui corrige
bash/python est distinct et réside dans les patches Debian — accessible
via `apt source qemu` sur un hôte 25.10 ou 26.04.

### 5.2 Conclusion validée empiriquement sur 26.04 LTS (ceos, 2026-04-22)

L'hôte ceos a été upgradé de 25.10 → 26.04 LTS et teste QEMU 10.2.1
packagé Debian. Résultat : **tous les crashes bash/python arm64
disparaissent** (cf §2.2), et les ratios de perf arm64 tombent à ~15-20×
(cf §3.7) contre 117× sur QEMU 8.2.

**L'upgrade vers Ubuntu 26.04 LTS est la seule solution durable et
complète.** Elle apporte simultanément :

- Le fix stabilité bash/python arm64 sur toutes les glibc ≤ 2.39.
- Le gain de perf QEMU 10 (×5-8 vs QEMU 8.2 sur workloads 24.04 arm64).
- Le support LTS jusqu'en 2031.

---

## 6. Recommandations d'usage

### 6.1 Pour un build arm64 émulé sous QEMU 8.2.x (aujourd'hui)

- **Stable, seul choix raisonnable** : famille `*-ubuntu2404`. Lent (~40× vs
  amd64 natif) mais fonctionne.
- **À éviter arm64 émulé** : familles `*-ubuntu2204` et `*-debian-bookworm` →
  SIGSEGV dès le premier bash/python. Leur manifest multi-arch reste publié
  pour les hôtes arm64 **natifs**.

### 6.2 Pour un build arm64 natif

Tout fonctionne sur n'importe quelle image. Pas de pénalité QEMU. C'est la
voie royale (Hetzner CAX, Raspberry Pi 5 + SSD, Mac M-series, runner GitHub
arm64).

### 6.3 Pour un build amd64 natif

Toutes les familles sont utilisables. `base-debian-bookworm` est plus légère
(~90 MB vs ~160 MB pour Ubuntu 24.04) et produit des binaires compatibles
Ubuntu 24.04 (glibc 2.36 < 2.39).

### 6.4 À moyen terme

1. **Upgrade hôte CI + dev → Ubuntu 26.04 LTS** (validé empiriquement sur
   ceos 2026-04-22, cf §2.2 / §5.2). Livre QEMU 10.2.1 packagé Debian →
   corrige bash arm64 22.04/bookworm **et** apporte le gain de perf ×5-8
   sur 24.04 arm64. **Seule option durable.**
2. **Cross-compilation** sur runner amd64 natif avec
   `aarch64-linux-gnu-gcc` + sysroot Ubuntu 24.04 arm64. 0 % overhead QEMU.
   Complication : les libs qui font `try_run` CMake exécutent des binaires
   pendant le build → fallback QEMU requis pour ces étapes.
3. **Runner arm64 natif dédié**. Résout tout. Coût infra.

### 6.5 Optimisations runtime déjà en place

Dans `run_docker_build.sh` :

- `--tmpfs /build:size=8g` + `--tmpfs /tmp` → I/O en RAM (gain ×2-3).
- `--security-opt seccomp=unconfined` → réduit l'overhead syscall QEMU.
- `-e GLIBC_TUNABLES=glibc.pthread.rseq=0` → désactive rseq instable.
- `-e QEMU_CPU=max`.
- Volume persistant pour cache depmanager.
- `-u uid:gid` → pas de fichiers root-owned.

---

## 7. Maintenance des images à jour

Indépendant du benchmark arm64, mais lié au cycle de vie des images produites.

### 7.1 Problème

Les images `:latest` vieillissent : CVE qui s'accumulent, bump runtime Python,
etc. Aujourd'hui le rebuild est manuel via `./all_ci.sh`.

### 7.2 Leviers

- **Rebuild planifié GitHub Actions (cron)** — workflow hebdomadaire sur
  runner self-hosted avec docker + login registry. Cadence `0 3 * * 1`
  (lundi matin).
- **Watch upstream via Renovate** — ouvre une PR quand `ubuntu:24.04`,
  `debian:bookworm-slim`, etc. publient un nouveau digest.
- **Tagging discipliné** — déjà en place (`YYYYMMDD-HHMM-<gitshort>` +
  `:latest`). Consumers peuvent pinner un tag daté pour stabilité.
- **Scan Trivy** après chaque build pour lister les CVE, publication du
  rapport en artifact.

---

## 8. Annexe — pré-requis hôte

### 8.1 Poste dev Ubuntu 24.04 amd64 (déjà configuré)

- `kernel.apparmor_restrict_unprivileged_userns=0` dans
  `/etc/sysctl.d/60-apparmor-userns.conf`.
- `qemu-user-static` + `binfmt-support` installés et actifs.
- Handler `/proc/sys/fs/binfmt_misc/qemu-aarch64` : interpreter
  `/usr/libexec/qemu-binfmt/aarch64-binfmt-P`, flags `POF`.

### 8.2 Hôte CI TeamCity (Ubuntu 24.04, DinD)

Mêmes prérequis, à appliquer **sur la VM hôte** (pas dans le conteneur
TeamCity ni dans son DinD interne).

### 8.3 Post-upgrade Ubuntu 26.04

```bash
dpkg -l | grep qemu-user-static    # attendu 1:10.2.1-*
./run_docker_bench.py              # relance la suite complète
# Comparer aux mesures du §2/§3 — si bash arm64 rc=0 en 22.04 / bookworm,
# le fix upstream est effectif.
```

---

## 9. Sources

- [Launchpad bug 2072564 — qemu-aarch64-static segfaults on ldconfig](https://bugs.launchpad.net/ubuntu/+source/qemu/+bug/2072564)
- [QEMU GitLab issue 2122 — related segfault](https://gitlab.com/qemu-project/qemu/-/issues/2122)
- [QEMU 10.0 release notes](https://www.qemu.org/2025/04/23/qemu-10-0-0/)
- [QEMU 10.2 release notes](https://www.qemu.org/2025/12/24/qemu-10-2-0/)
- [Ubuntu 26.04 LTS release notes](https://documentation.ubuntu.com/release-notes/26.04/)
