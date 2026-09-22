#!/usr/bin/env bash
#
# Devel image for Ubuntu 26.04 — debug and analysis tooling on top of
# builder-ubuntu2604, which already provides both toolchains (gcc + clang),
# cmake, ninja and every -dev library.
#
# Adds: gdb, lldb, valgrind, strace, ltrace, gperf, lcov, cppcheck, bear, perf
# and the interactive shell utilities. The gcc / clang versions are inherited
# from the parent builder through /etc/ci-toolchain.env — nothing to declare.

set -e

bash /tmp/install/_common/devel.sh
