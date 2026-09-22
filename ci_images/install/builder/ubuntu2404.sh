#!/usr/bin/env bash
#
# Builder image for Ubuntu 24.04 — THE build environment: both toolchains plus
# every build tool and -dev library, on top of base-ubuntu2404.
#
#   gcc-14    : max stock version of 24.04 → binaries link libstdc++6 14.2.0,
#               the version shipped by a stock 24.04.
#   clang-22  : via apt.llvm.org (24.04 stops at clang-18), linked against the
#               stock libstdc++-14 so the produced binaries stay runnable on a
#               stock 24.04 without any PPA.

set -e

export GCC_VERSION=14
export CLANG_VERSION=22
export CLANG_SOURCE=llvm

bash /tmp/install/_common/builder.sh
