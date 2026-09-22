#!/bin/bash
#
# Build and push every image declared in generator.py presets, respecting the
# dependency order base -> builder -> devel so that each preset's parent is
# available when the child runs.

set -e

# ============================================================
# Ubuntu 22.04 family
# builder/devel : gcc-12 (stock main) + clang-22 (apt.llvm.org)
# Binaires linkés contre libstdc++6 stock 12.3.0 → compat 22.04 stock.
# ============================================================

./generator.py --preset base-ubuntu2204 --push --alias-latest
./generator.py --preset builder-ubuntu2204 --push --alias-latest
./generator.py --preset devel-ubuntu2204 --push --alias-latest

# ============================================================
# Ubuntu 24.04 family
# builder/devel : gcc-14 (stock) + clang-22 (apt.llvm.org)
# Binaires linkés contre libstdc++6 stock 14.2.0 → compat 24.04 stock.
# ============================================================

./generator.py --preset base-ubuntu2404 --push --alias-latest
./generator.py --preset builder-ubuntu2404 --push --alias-latest
./generator.py --preset devel-ubuntu2404 --push --alias-latest

# ============================================================
# Ubuntu 26.04 family
# builder/devel : gcc-15 (stock main) + clang-22 (universe, pas d'apt.llvm.org)
# Binaires linkés contre libstdc++-15 ; le libstdc++6 stock (snapshot gcc-16)
# en est un sur-ensemble ABI → compat 26.04 stock.
# ============================================================

./generator.py --preset base-ubuntu2604 --push --alias-latest
./generator.py --preset builder-ubuntu2604 --push --alias-latest
./generator.py --preset devel-ubuntu2604 --push --alias-latest
