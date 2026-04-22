#!/usr/bin/env bash
#
# Devel image for Ubuntu 22.04 — merges BOTH toolchains on top of the gcc
# builder so developers can build with either gcc or clang.
#
# Parent image: registry.argawaen.net/builder/builder-gcc15-ubuntu2204
#   (already provides: gcc-15, cmake, ninja, -dev libs, depmanager, ...)
# This script adds:
#   - clang-22 via apt.llvm.org (latest stable release)
#   - the full devel tooling (gdb, lldb, valgrind, profilers, ...)

set -e

# Install clang toolchain from apt.llvm.org
export CLANG_VERSION=22
bash /tmp/install/_common/clang-llvm.sh

# Install the common devel tooling (gdb, valgrind, strace, lcov, ...)
bash /tmp/install/_common/devel.sh

# lldb matching the clang version
. /tmp/install/_common/helpers.sh
update_package_list
install_package lldb-22
update-alternatives --install /usr/bin/lldb lldb /usr/bin/lldb-22 22
clear_cache
