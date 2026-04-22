#!/usr/bin/env bash
#
# Shared installer for any clang toolchain coming from apt.llvm.org.
# The calling script must define CLANG_VERSION *before* sourcing this file
# (or exporting it before `bash`-ing it).

set -e

: "${CLANG_VERSION:?CLANG_VERSION must be set by the caller}"

. /tmp/install/_common/helpers.sh

# apt.llvm.org repo (keyring + sources list)
. /etc/os-release
CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME}}"
curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key \
  | gpg --dearmor > /usr/share/keyrings/llvm-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/llvm-archive-keyring.gpg] https://apt.llvm.org/${CODENAME}/ llvm-toolchain-${CODENAME}-${CLANG_VERSION} main" \
  > /etc/apt/sources.list.d/llvm.list

update_package_list

# Lie le clang à la libstdc++ **déjà installée par l'image parente** (version
# stock de la distro) — pas à la plus récente dispo dans apt. Cette règle
# garantit que les binaires produits restent exécutables sur une target
# stock Canonical sans ajouter de PPA :
#   - Ubuntu 22.04 : libstdc++6 12.3.0 → STDCPP_VER=12
#   - Ubuntu 24.04 : libstdc++6 14.2.0 → STDCPP_VER=14
STDCPP_VER=$(dpkg -s libstdc++6 2>/dev/null | awk '/^Version:/ {print $2}' | grep -oE '^[0-9]+' | head -1)
if [[ -z "$STDCPP_VER" ]]; then
  echo "ERROR: libstdc++6 n'est pas installé — impossible de déterminer STDCPP_VER" >&2
  exit 1
fi

install_package  {clang,lld,llvm,clang-tidy}-${CLANG_VERSION} \
                 libclang*-${CLANG_VERSION}-dev \
                 lib{c++,c++abi,unwind}-${CLANG_VERSION}-dev

install_package libstdc++-${STDCPP_VER}-dev

# Resolve the libstdc++.so shipped by libstdc++-${STDCPP_VER}-dev via a glob on
# the filesystem — works on any arch (x86_64-linux-gnu, aarch64-linux-gnu, ...)
# and on any clang version (note: `clang -print-multiarch` only exists since
# LLVM 19, so it cannot be used here).
LIBSTDCPP_SO=$(ls /usr/lib/gcc/*-linux-gnu/${STDCPP_VER}/libstdc++.so 2>/dev/null | head -n1)
if [[ -z "$LIBSTDCPP_SO" ]]; then
  echo "ERROR: libstdc++-${STDCPP_VER}-dev did not provide the expected libstdc++.so" >&2
  exit 1
fi

ln -sf /usr/include/c++/${STDCPP_VER} /usr/include/c++/default
ln -sf "$LIBSTDCPP_SO" /usr/lib/libstdc++.so

update-alternatives --install /usr/bin/lld lld /usr/bin/lld-${CLANG_VERSION} ${CLANG_VERSION}
update-alternatives --install /usr/bin/clang clang /usr/bin/clang-${CLANG_VERSION} ${CLANG_VERSION}
update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-${CLANG_VERSION} ${CLANG_VERSION}
update-alternatives --install /usr/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-${CLANG_VERSION} ${CLANG_VERSION}
update-alternatives --install /usr/bin/llvm-cov llvm-cov /usr/bin/llvm-cov-${CLANG_VERSION} ${CLANG_VERSION}

clear_cache
