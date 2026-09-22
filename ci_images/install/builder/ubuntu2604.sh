#!/usr/bin/env bash
#
# Builder image for Ubuntu 26.04 — THE build environment: both toolchains plus
# every build tool and -dev library, on top of base-ubuntu2604.
#
#   gcc-15    : the stock compiler of 26.04 main (`gcc`/`g++` default).
#   clang-22  : straight from 26.04 universe — no apt.llvm.org needed, the
#               distro already ships clang 22.1. Linked against libstdc++-15.
#
# Note: 26.04 ships libstdc++6 built from a gcc-16 snapshot. Linking against
# libstdc++-15-dev (STDCPP_VER=GCC_VERSION) stays correct — the runtime is an
# ABI superset — and keeps the toolchain on the stock gcc.

set -e

export GCC_VERSION=15
export CLANG_VERSION=22
export CLANG_SOURCE=distro

bash /tmp/install/_common/builder.sh
