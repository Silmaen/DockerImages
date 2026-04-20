#!/bin/bash
#
# Build and push every image declared in generator.py presets, respecting the
# dependency order base -> builder -> devel so that each preset's parent is
# available when the child runs.

set -e

# ============================================================
# Ubuntu 22.04 family
# ============================================================

# Runtime base
./generator.py --preset base-ubuntu2204 --push --alias-latest

# GCC builders
./generator.py --preset builder-gcc13-ubuntu2204 --push --alias-latest

# Clang builder (apt.llvm.org — minimum version 18 is not in 22.04 repos)
./generator.py --preset builder-clang-llvm18-ubuntu2204 --push --alias-latest

# Devel (merges gcc + clang on top of the gcc builder)
./generator.py --preset devel-ubuntu2204 --push --alias-latest

# ============================================================
# Ubuntu 24.04 family
# ============================================================

# Runtime base
./generator.py --preset base-ubuntu2404 --push --alias-latest

# Builders
./generator.py --preset builder-gcc14-ubuntu2404 --push --alias-latest
./generator.py --preset builder-clang18-ubuntu2404 --push --alias-latest

# Devel (merges gcc + clang on top of the gcc builder)
./generator.py --preset devel-ubuntu2404 --push --alias-latest
