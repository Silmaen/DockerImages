#!/usr/bin/env bash
#
# Devel image for Ubuntu 24.04 — merges BOTH toolchains on top of the gcc
# builder so developers can build with either gcc or clang.
#
# Parent image: registry.argawaen.net/builder/builder-gcc14-ubuntu2404
#   (already provides: gcc-14, cmake, ninja, -dev libs, depmanager, ...)
# This script adds:
#   - clang-18 from the distro repos (Ubuntu 24.04 ships clang-18 natively)
#   - the full devel tooling (gdb, lldb, valgrind, profilers, ...)

set -e

. /tmp/install/_common/helpers.sh

update_package_list
install_package clang-18 lld-18 llvm-18 clang-tidy-18 libclang-rt-18-dev lldb-18

update-alternatives --install /usr/bin/lld lld /usr/bin/lld-18 18
update-alternatives --install /usr/bin/clang clang /usr/bin/clang-18 18
update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-18 18
update-alternatives --install /usr/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-18 18
update-alternatives --install /usr/bin/llvm-cov llvm-cov /usr/bin/llvm-cov-18 18
update-alternatives --install /usr/bin/lldb lldb /usr/bin/lldb-18 18

# Common devel tooling
bash /tmp/install/_common/devel.sh

clear_cache
