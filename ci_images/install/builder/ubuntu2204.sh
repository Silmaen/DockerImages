#!/usr/bin/env bash
#
# Builder image for Ubuntu 22.04 — THE build environment: both toolchains plus
# every build tool and -dev library, on top of base-ubuntu2204.
#
#   gcc-12    : max stock version of 22.04 main → binaries link libstdc++6
#               12.3.0, the version shipped by a stock 22.04.
#   clang-22  : via apt.llvm.org (22.04 stops at clang-15), linked against the
#               stock libstdc++-12 so the produced binaries stay runnable on a
#               stock 22.04 without any PPA.

set -e

export GCC_VERSION=12
export CLANG_VERSION=22
export CLANG_SOURCE=llvm

bash /tmp/install/_common/builder.sh
