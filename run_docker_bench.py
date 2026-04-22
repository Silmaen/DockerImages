#!/usr/bin/env python3
"""
Benchmark harness — stabilité + performance des images *base* en amd64 natif
vs arm64 émulé (QEMU user-mode).

Conventions de ratio :
  - amd64 Docker : ratio = t_image_amd64 / t_host_natif   → overhead Docker.
  - arm64 Docker : ratio = t_image_arm64 / t_image_amd64  → overhead QEMU pur.

Usage :
  ./run_docker_bench.py                                   # images par défaut
  ./run_docker_bench.py ubuntu:24.04 debian:bookworm-slim # images custom
  ./run_docker_bench.py --platforms linux/amd64,linux/arm64
  ./run_docker_bench.py --stability-only
  ./run_docker_bench.py --perf-only
  ./run_docker_bench.py --timeout 30
  ./run_docker_bench.py --pull
  ./run_docker_bench.py --json results.json               # export machine-readable

Variables d'env équivalentes (pour compat avec l'ancien .sh) :
  BENCH_PLATFORMS, BENCH_TIMEOUT, BENCH_STABILITY_ONLY, BENCH_PERF_ONLY, BENCH_PULL
"""
from __future__ import annotations

import argparse
import json
import os
import shlex
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, field, asdict
from typing import Iterable


DEFAULT_IMAGES = [
    "ubuntu:22.04",
    "ubuntu:24.04",
    "debian:bookworm-slim",
    "registry.argawaen.net/builder/base-ubuntu2204:latest",
    "registry.argawaen.net/builder/base-ubuntu2404:latest",
    "registry.argawaen.net/builder/base-debian-bookworm:latest",
]

DEFAULT_PLATFORMS = ["linux/amd64", "linux/arm64"]

# Ordre d'affichage des métriques + labels humains
METRICS = [
    ("sh_loop", "sh loop 2000"),
    ("fork_true20", "20× /bin/true"),
    ("py_pass", "python3 -c pass"),
    ("py_imports", "python3 imports"),
    ("cc_hello", "cc -O2 hello.c"),
]

# Payload embarqué — dash-compatible, émet des lignes "key=value"
BENCH_PAYLOAD = r"""
set +e
_ms() { echo $(( ($(date +%s%N) - $1) / 1000000 )); }

t=$(date +%s%N); x=0; i=1
while [ $i -le 2000 ]; do x=$((x + i)); i=$((i + 1)); done
echo "sh_loop=$(_ms $t)"

t=$(date +%s%N); i=1
while [ $i -le 20 ]; do /bin/true; i=$((i + 1)); done
echo "fork_true20=$(_ms $t)"

if command -v python3 >/dev/null 2>&1; then
    t=$(date +%s%N)
    if python3 -c "pass" 2>/dev/null; then
        echo "py_pass=$(_ms $t)"
        t=$(date +%s%N)
        if python3 -c "import os, sys, json, hashlib, subprocess, urllib.request" 2>/dev/null; then
            echo "py_imports=$(_ms $t)"
        else
            echo "py_imports=crash"
        fi
    else
        echo "py_pass=crash"
        echo "py_imports=crash"
    fi
else
    echo "py_pass=absent"
    echo "py_imports=absent"
fi

CC=""
command -v cc  >/dev/null 2>&1 && CC=cc
[ -z "$CC" ] && command -v gcc >/dev/null 2>&1 && CC=gcc
if [ -n "$CC" ]; then
    printf '#include <stdio.h>\nint main(void){printf("ok\\n");return 0;}\n' > /tmp/hello.c
    t=$(date +%s%N)
    $CC -O2 /tmp/hello.c -o /tmp/hello 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "cc_hello=$(_ms $t)"
    else
        echo "cc_hello=crash"
    fi
    rm -f /tmp/hello /tmp/hello.c
else
    echo "cc_hello=absent"
fi
"""


# -----------------------------------------------------------------------------
# Data classes
# -----------------------------------------------------------------------------


@dataclass
class MetricResult:
    """Une mesure ou un statut non-numérique (crash/absent/skip)."""
    status: str           # "ok" | "crash" | "absent" | "skip" | "error"
    ms: int | None = None

    def is_numeric(self) -> bool:
        return self.status == "ok" and self.ms is not None


@dataclass
class StabilityResult:
    interp: str           # sh | bash | python3
    exit_code: int | None
    ms: int | None
    label: str            # "OK", "SIGSEGV", "n/a (absent)", ...


@dataclass
class ImageReport:
    image: str
    platform: str
    glibc: str | None = None
    stability: list[StabilityResult] = field(default_factory=list)
    perf: dict[str, MetricResult] = field(default_factory=dict)
    unavailable: bool = False


# -----------------------------------------------------------------------------
# Shell & Docker helpers
# -----------------------------------------------------------------------------


class Bench:
    def __init__(self, timeout: int, pull: bool):
        self.timeout = timeout
        self.pull = pull
        self._image_seen: set[tuple[str, str]] = set()

    # -- helpers subprocess -------------------------------------------------

    @staticmethod
    def _run(argv: list[str], *, timeout: int, capture: bool = True) -> subprocess.CompletedProcess:
        """Exécute une commande, capture stdout+stderr, tolère le timeout."""
        try:
            return subprocess.run(
                argv,
                stdout=subprocess.PIPE if capture else None,
                stderr=subprocess.STDOUT if capture else None,
                timeout=timeout,
                check=False,
            )
        except subprocess.TimeoutExpired as exc:
            out = exc.stdout or b""
            return subprocess.CompletedProcess(argv, returncode=124, stdout=out, stderr=b"")

    def ensure_image(self, platform: str, image: str) -> bool:
        """Tire l'image si nécessaire. Retourne True si utilisable après coup."""
        key = (platform, image)
        if key in self._image_seen:
            return True

        need_pull = self.pull
        if not need_pull:
            # L'inspect est par digest local tous archis confondus : on est
            # obligé de pull pour garantir la bonne variante arch.
            need_pull = True

        if need_pull:
            self._run(
                ["docker", "pull", f"--platform={platform}", "-q", image],
                timeout=max(self.timeout, 60),
            )

        ok = self._run(
            ["docker", "image", "inspect", image],
            timeout=5,
        ).returncode == 0
        if ok:
            self._image_seen.add(key)
        return ok

    def docker_run(
        self,
        platform: str,
        image: str,
        *cmd: str,
        timeout: int | None = None,
    ) -> subprocess.CompletedProcess:
        return self._run(
            [
                "docker", "run", "--rm", "--init",
                f"--platform={platform}",
                image,
                *cmd,
            ],
            timeout=timeout or self.timeout,
        )

    # -- collecte ----------------------------------------------------------

    def glibc_version(self, platform: str, image: str) -> str | None:
        script = (
            'for lib in /lib/*-linux-gnu/libc.so.6 /lib/libc.so.6 '
            '/usr/lib/*-linux-gnu/libc.so.6; do '
            '  if [ -x "$lib" ]; then "$lib" 2>/dev/null | head -1 | '
            '    grep -oE "[0-9]+\\.[0-9]+" | head -1; return; '
            '  fi; '
            'done'
        )
        cp = self.docker_run(platform, image, "/bin/sh", "-c", script, timeout=self.timeout)
        if cp.returncode != 0:
            return None
        out = cp.stdout.decode(errors="replace").strip().splitlines()
        return out[0] if out else None

    def stability(self, platform: str, image: str) -> list[StabilityResult]:
        """Teste sh/bash/python3 sur `echo OK`."""
        interps = [
            ("sh",      "/bin/sh",     "echo OK"),
            ("bash",    "/bin/bash",   "echo OK"),
            ("python3", "/usr/bin/python3", 'print("OK")'),
        ]
        results: list[StabilityResult] = []
        for name, binary, arg in interps:
            # Vérifie la présence du binaire d'abord
            probe = self.docker_run(
                platform, image,
                "/bin/sh", "-c", f"test -x {shlex.quote(binary)}",
                timeout=self.timeout,
            )
            if probe.returncode != 0:
                results.append(StabilityResult(name, None, None, "n/a (absent)"))
                continue

            t0 = time.monotonic_ns()
            cp = self.docker_run(platform, image, binary, "-c", arg, timeout=self.timeout)
            dt_ms = (time.monotonic_ns() - t0) // 1_000_000

            results.append(StabilityResult(
                interp=name,
                exit_code=cp.returncode,
                ms=dt_ms,
                label=_label_exit(cp.returncode),
            ))
        return results

    def perf(self, platform: str, image: str) -> dict[str, MetricResult]:
        """Lance le payload de bench et parse les lignes `key=value`."""
        cp = self.docker_run(
            platform, image,
            "/bin/sh", "-c", BENCH_PAYLOAD,
            timeout=max(self.timeout, 60),
        )
        return self._parse_metrics(cp.stdout.decode(errors="replace"))

    def perf_native(self) -> dict[str, MetricResult]:
        """Bench sur le host (dash si dispo, sinon /bin/sh)."""
        sh = shutil.which("dash") or "/bin/sh"
        cp = self._run([sh, "-c", BENCH_PAYLOAD], timeout=60)
        return self._parse_metrics(cp.stdout.decode(errors="replace"))

    @staticmethod
    def _parse_metrics(text: str) -> dict[str, MetricResult]:
        out: dict[str, MetricResult] = {}
        for line in text.splitlines():
            if "=" not in line:
                continue
            key, _, val = line.partition("=")
            key = key.strip()
            val = val.strip()
            if val in ("crash", "absent", "skip"):
                out[key] = MetricResult(status=val)
            else:
                try:
                    out[key] = MetricResult(status="ok", ms=int(val))
                except ValueError:
                    out[key] = MetricResult(status="error")
        return out


# -----------------------------------------------------------------------------
# Formatting
# -----------------------------------------------------------------------------


_EXIT_LABELS = {
    0:   "OK",
    124: "TIMEOUT",
    125: "docker-err",
    139: "SIGSEGV",
    143: "SIGTERM",
}


def _label_exit(rc: int | None) -> str:
    if rc is None:
        return "?"
    return _EXIT_LABELS.get(rc, f"rc={rc}")


def _ratio(metric_value: MetricResult, ref_value: MetricResult | None) -> str:
    if not metric_value.is_numeric() or ref_value is None or not ref_value.is_numeric():
        return "—"
    if ref_value.ms == 0:
        return "∞"
    return f"{metric_value.ms / ref_value.ms:.1f}×"


def _fmt_perf_cell(m: MetricResult, ref: MetricResult | None) -> str:
    if m.status == "ok":
        return f"{m.ms:>5} ms ({_ratio(m, ref):>6})"
    if m.status in ("crash", "absent", "skip"):
        return m.status
    return "—"


def _print_sep(title: str | None = None) -> None:
    bar = "=" * 78
    print(bar)
    if title:
        print(f"# {title}")
        print(bar)


def print_stability_section(reports: list[ImageReport]) -> None:
    _print_sep("STABILITÉ — sh / bash / python3  (attendu : OK)")

    by_platform: dict[str, list[ImageReport]] = {}
    for r in reports:
        by_platform.setdefault(r.platform, []).append(r)

    for platform, rows in by_platform.items():
        print(f"\n## Plateforme : {platform}")
        for r in rows:
            if r.unavailable:
                print(f"  {r.image:<60}  [image unavailable]")
                continue
            cells = {s.interp: s for s in r.stability}
            print(
                f"  {r.image:<60} "
                f" glibc={r.glibc or '?':<6} "
                f" sh=[{_fmt_stab_cell(cells.get('sh'))}] "
                f" bash=[{_fmt_stab_cell(cells.get('bash'))}] "
                f" py3=[{_fmt_stab_cell(cells.get('python3'))}]"
            )


def _fmt_stab_cell(s: StabilityResult | None) -> str:
    if s is None:
        return "—"
    if s.ms is None:
        return f"{s.label:<15}"
    return f"{s.label:<8} {s.ms:>5}ms"


def print_perf_section(
    reports_by_platform: dict[str, list[ImageReport]],
    native: dict[str, MetricResult],
) -> None:
    _print_sep("PERFORMANCE — microbench (dash, sans bash pour éviter crash glibc<2.39)")
    print("# Ratios :")
    print("#   amd64 Docker : rapport au host natif (overhead Docker)")
    print("#   arm64 Docker : rapport à la même image en amd64 (overhead QEMU pur)")
    print("=" * 78)

    # Baseline host
    print("\n## Référence host natif (pas de Docker)")
    for key, label in METRICS:
        m = native.get(key, MetricResult(status="skip"))
        if m.is_numeric():
            print(f"  {label:<22} : {m.ms:>6} ms")
        else:
            print(f"  {label:<22} : {m.status}")

    # amd64
    if "linux/amd64" in reports_by_platform:
        print("\n## linux/amd64  (ratio vs natif host)")
        _print_perf_header()
        for r in reports_by_platform["linux/amd64"]:
            if r.unavailable:
                print(f"  {r.image:<60}  [image unavailable]")
                continue
            _print_perf_row(r, ref=native)

    # arm64 — ratio vs amd64 de la même image
    if "linux/arm64" in reports_by_platform:
        print("\n## linux/arm64  (ratio vs la même image en amd64)")
        _print_perf_header()
        amd_by_image = {
            r.image: r.perf
            for r in reports_by_platform.get("linux/amd64", [])
            if not r.unavailable
        }
        for r in reports_by_platform["linux/arm64"]:
            if r.unavailable:
                print(f"  {r.image:<60}  [image unavailable]")
                continue
            _print_perf_row(r, ref=amd_by_image.get(r.image, {}))


def _print_perf_header() -> None:
    print(f"  {'image':<60}", end="")
    for _, label in METRICS:
        print(f"  {label:<16}", end="")
    print()


def _print_perf_row(r: ImageReport, ref: dict[str, MetricResult]) -> None:
    print(f"  {r.image:<60}", end="")
    for key, _ in METRICS:
        m = r.perf.get(key, MetricResult(status="skip"))
        print(f"  {_fmt_perf_cell(m, ref.get(key)):<16}", end="")
    print()


# -----------------------------------------------------------------------------
# JSON export
# -----------------------------------------------------------------------------


def to_jsonable(
    reports: list[ImageReport],
    native: dict[str, MetricResult],
) -> dict:
    return {
        "native": {k: asdict(v) for k, v in native.items()},
        "images": [
            {
                "image": r.image,
                "platform": r.platform,
                "glibc": r.glibc,
                "unavailable": r.unavailable,
                "stability": [asdict(s) for s in r.stability],
                "perf": {k: asdict(v) for k, v in r.perf.items()},
            }
            for r in reports
        ],
    }


# -----------------------------------------------------------------------------
# CLI
# -----------------------------------------------------------------------------


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument(
        "images", nargs="*",
        help="Images à bencher (défaut : jeu standard).",
    )
    p.add_argument(
        "--platforms",
        default=os.environ.get("BENCH_PLATFORMS", ",".join(DEFAULT_PLATFORMS)),
        help='Plateformes séparées par virgule (défaut "linux/amd64,linux/arm64").',
    )
    p.add_argument(
        "--timeout", type=int,
        default=int(os.environ.get("BENCH_TIMEOUT", "15")),
        help="Timeout (secondes) par commande Docker (défaut 15).",
    )
    p.add_argument(
        "--stability-only", action="store_true",
        default=bool(os.environ.get("BENCH_STABILITY_ONLY")),
    )
    p.add_argument(
        "--perf-only", action="store_true",
        default=bool(os.environ.get("BENCH_PERF_ONLY")),
    )
    p.add_argument(
        "--pull", action="store_true",
        default=bool(os.environ.get("BENCH_PULL")),
        help="Force docker pull avant chaque test.",
    )
    p.add_argument(
        "--json", metavar="PATH",
        help="Exporte le rapport complet au format JSON.",
    )
    return p.parse_args()


def main() -> int:
    args = parse_args()
    images: list[str] = args.images or DEFAULT_IMAGES
    platforms = [p.strip() for p in args.platforms.split(",") if p.strip()]

    if args.stability_only and args.perf_only:
        print("error: --stability-only et --perf-only sont mutuellement exclusifs", file=sys.stderr)
        return 2

    bench = Bench(timeout=args.timeout, pull=args.pull)

    # 1. Mesure native host (utile pour la perf amd64)
    native: dict[str, MetricResult] = {}
    if not args.stability_only:
        native = bench.perf_native()

    # 2. Collecte par image × plateforme
    reports: list[ImageReport] = []
    for platform in platforms:
        for image in images:
            ok = bench.ensure_image(platform, image)
            r = ImageReport(image=image, platform=platform, unavailable=not ok)
            if ok:
                r.glibc = bench.glibc_version(platform, image)
                if not args.perf_only:
                    r.stability = bench.stability(platform, image)
                if not args.stability_only:
                    r.perf = bench.perf(platform, image)
            reports.append(r)

    # 3. Affichage
    if not args.perf_only:
        print_stability_section(reports)

    if not args.stability_only:
        by_platform: dict[str, list[ImageReport]] = {}
        for r in reports:
            by_platform.setdefault(r.platform, []).append(r)
        print_perf_section(by_platform, native)

    print("=" * 78)
    print("Rapport détaillé : BENCHMARK_arm64_emulation.md")
    print("=" * 78)

    # 4. Export JSON optionnel
    if args.json:
        payload = to_jsonable(reports, native)
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2, ensure_ascii=False)
        print(f"\n→ JSON : {args.json}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
