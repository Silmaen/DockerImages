#!/usr/bin/env bash
#
# Shared setup for every devel image — installs compiler-agnostic dev tooling
# (debuggers, profilers, static analysis, quality-of-life shell utilities).
# Called from each devel/<variant>.sh via `bash /tmp/install/_common/devel.sh`.

set -e

. /tmp/install/_common/helpers.sh

update_package_list

# Debuggers, profilers, tracing, coverage
install_package gdb valgrind gperf strace ltrace lcov

# Static analysis / code quality
install_package cppcheck clang-format bear

# Shell quality-of-life for interactive use
install_package tmux less vim htop git-lfs

# perf / linux-tools — best effort (the kernel-version-specific packages are
# often unavailable inside containers, so we tolerate failure).
install_package linux-tools-common || true

clear_cache
