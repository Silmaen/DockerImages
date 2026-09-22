#!/usr/bin/env bash
#
# Parametric Clang/LLVM installer, shared by every builder image.
# The caller must export CLANG_VERSION, and may pick where the packages come
# from through CLANG_SOURCE:
#     distro  — the distro's own repositories (no third-party repo added)
#     llvm    — apt.llvm.org (default; needed when the distro is too old)
#
#     export CLANG_VERSION=22
#     export CLANG_SOURCE=llvm
#     bash /tmp/install/_common/clang.sh
#
# clang itself is only a build tool, so taking it from apt.llvm.org has no
# runtime consequence — *provided* it is linked against the libstdc++ shipped
# by the distro. That version is STDCPP_VER: it defaults to GCC_VERSION (the
# stock gcc installed by _common/gcc.sh) and falls back to the version of the
# installed libstdc++6 when this script is used standalone.

set -e

: "${CLANG_VERSION:?CLANG_VERSION must be set by the caller}"
CLANG_SOURCE="${CLANG_SOURCE:-llvm}"

. /tmp/install/_common/helpers.sh

case "${CLANG_SOURCE}" in
  distro)
    ;;
  llvm)
    CODENAME="$(distro_codename)"
    curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key \
      | gpg --dearmor > /usr/share/keyrings/llvm-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/llvm-archive-keyring.gpg] https://apt.llvm.org/${CODENAME}/ llvm-toolchain-${CODENAME}-${CLANG_VERSION} main" \
      > /etc/apt/sources.list.d/llvm.list
    ;;
  *)
    echo "ERROR: CLANG_SOURCE must be 'distro' or 'llvm', got '${CLANG_SOURCE}'" >&2
    exit 1
    ;;
esac

update_package_list

STDCPP_VER="${STDCPP_VER:-${GCC_VERSION:-}}"
if [[ -z "$STDCPP_VER" ]]; then
  STDCPP_VER=$(dpkg -s libstdc++6 2>/dev/null | awk '/^Version:/ {print $2}' | grep -oE '^[0-9]+' | head -1)
fi
if [[ -z "$STDCPP_VER" ]]; then
  echo "ERROR: neither GCC_VERSION nor an installed libstdc++6 — cannot determine STDCPP_VER" >&2
  exit 1
fi

install_package {clang,lld,llvm,clang-tidy,clang-format}-${CLANG_VERSION} \
                libclang-${CLANG_VERSION}-dev \
                libclang-common-${CLANG_VERSION}-dev \
                libclang-rt-${CLANG_VERSION}-dev \
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
# ld.lld is what a driver actually execs for -fuse-ld=lld. clang finds it in its
# own /usr/lib/llvm-N/bin, but gcc only looks in PATH — without this alternative
# `gcc -fuse-ld=lld` fails with "collect2: fatal error: cannot find 'ld'".
# /usr/bin/ld.lld-N is shipped by lld-N from both apt.llvm.org and the distro.
update-alternatives --install /usr/bin/ld.lld ld.lld /usr/bin/ld.lld-${CLANG_VERSION} ${CLANG_VERSION}
update-alternatives --install /usr/bin/clang clang /usr/bin/clang-${CLANG_VERSION} ${CLANG_VERSION}
update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-${CLANG_VERSION} ${CLANG_VERSION}
update-alternatives --install /usr/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-${CLANG_VERSION} ${CLANG_VERSION}
update-alternatives --install /usr/bin/clang-format clang-format /usr/bin/clang-format-${CLANG_VERSION} ${CLANG_VERSION}
update-alternatives --install /usr/bin/llvm-cov llvm-cov /usr/bin/llvm-cov-${CLANG_VERSION} ${CLANG_VERSION}

clear_cache
