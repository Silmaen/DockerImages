#!/usr/bin/env bash
#
# Parametric GCC installer, shared by every builder image.
# The caller must export GCC_VERSION before running this script:
#     export GCC_VERSION=14
#     bash /tmp/install/_common/gcc.sh
#
# Only the *stock* gcc of the distro must ever be requested here: a newer gcc
# (PPA toolchain-r/test) would link the produced binaries against a libstdc++
# more recent than the one shipped by the target distro. See CLAUDE.md §1.

set -e

: "${GCC_VERSION:?GCC_VERSION must be set by the caller}"

. /tmp/install/_common/helpers.sh

update_package_list

# g++-N pulls gcc-N and libstdc++-N-dev, which clang.sh then links against.
install_package gcc-${GCC_VERSION} g++-${GCC_VERSION}

register_gcc_alternatives "${GCC_VERSION}"

clear_cache
