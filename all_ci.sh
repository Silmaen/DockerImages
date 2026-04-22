#!/bin/bash
#
# Build and push every image declared in generator.py presets, respecting the
# dependency order base -> builder -> devel so that each preset's parent is
# available when the child runs.

set -e

# ============================================================
# Ubuntu 22.04 family
# Toolchains : gcc-12 (natif main) + clang-22 (apt.llvm.org)
# Binaires linkés contre libstdc++6 stock 12.3.0 → compat 22.04 stock.
# ============================================================

./generator.py --preset base-ubuntu2204 --push --alias-latest
./generator.py --preset builder-gcc12-ubuntu2204 --push --alias-latest
./generator.py --preset builder-clang-llvm22-ubuntu2204 --push --alias-latest
./generator.py --preset devel-ubuntu2204 --push --alias-latest

# ============================================================
# Ubuntu 24.04 family
# Toolchains : gcc-14 (natif universe) + clang-22 (apt.llvm.org)
# Binaires linkés contre libstdc++6 stock 14.2.0 → compat 24.04 stock.
# ============================================================

./generator.py --preset base-ubuntu2404 --push --alias-latest
./generator.py --preset builder-gcc14-ubuntu2404 --push --alias-latest
./generator.py --preset builder-clang-llvm22-ubuntu2404 --push --alias-latest
./generator.py --preset devel-ubuntu2404 --push --alias-latest
