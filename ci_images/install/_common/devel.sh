#!/usr/bin/env bash
#
# Shared setup for every devel image — debug and analysis tooling ONLY.
# The build environment itself (compilers, cmake, -dev libs) comes from the
# parent builder image; nothing here is needed to merely build a project.
#
# The toolchain versions are read from /etc/ci-toolchain.env, written by
# _common/builder.sh in the parent image, so a devel script never repeats them
# and cannot drift from its builder. Exporting GCC_VERSION / CLANG_VERSION
# before running this script overrides the recorded values.

set -e

. /tmp/install/_common/helpers.sh

# Explicit values win over the ones recorded by the parent builder image.
_gcc_override="${GCC_VERSION:-}"
_clang_override="${CLANG_VERSION:-}"
if [[ -r /etc/ci-toolchain.env ]]; then
  . /etc/ci-toolchain.env
fi
GCC_VERSION="${_gcc_override:-${GCC_VERSION:-}}"
CLANG_VERSION="${_clang_override:-${CLANG_VERSION:-}}"

: "${GCC_VERSION:?GCC_VERSION not set and /etc/ci-toolchain.env unusable — is the parent a builder image?}"
: "${CLANG_VERSION:?CLANG_VERSION not set and /etc/ci-toolchain.env unusable — is the parent a builder image?}"

update_package_list

# Debuggers, profilers, tracing, coverage
install_package gdb valgrind gperf strace ltrace lcov

# lldb versioned like the clang of the parent builder image. The apt.llvm.org /
# distro repo it comes from is already configured there.
install_package lldb-${CLANG_VERSION}
update-alternatives --install /usr/bin/lldb lldb /usr/bin/lldb-${CLANG_VERSION} ${CLANG_VERSION}

# Static analysis / code quality (clang-tidy and clang-format are versioned and
# already provided by the builder layer through _common/clang.sh).
install_package cppcheck bear

# Shell quality-of-life for interactive use
install_package tmux less vim htop git-lfs

# perf / linux-tools — best effort (the kernel-version-specific packages are
# often unavailable inside containers, so we tolerate failure).
install_package linux-tools-common || true

# `lcov` depends on the unversioned `gcc` meta-package, which installs the
# distro's DEFAULT gcc over /usr/bin/gcc and breaks the alternative group set up
# by the builder — leaving e.g. gcc/gcov at 13 while g++ stays at 14 on 24.04.
# Re-assert the pinned toolchain now that every apt install is done.
register_gcc_alternatives "${GCC_VERSION}"

clear_cache
