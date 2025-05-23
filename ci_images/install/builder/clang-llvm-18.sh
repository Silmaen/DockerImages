#!/usr/bin/env bash

# Stop if error
set -e

CLANG_VERSION=18

function update_package_list() {
  DEBIAN_FRONTEND=noninteractive apt update
}
function install_package() {
  DEBIAN_FRONTEND=noninteractive apt install --no-install-recommends -y $@
}
function clear_cache() {
  DEBIAN_FRONTEND=noninteractive apt autoremove
  rm -rf /var/cache/apt/archive/* /var/lib/apt/lists/*
}

. /etc/os-release && curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor > /usr/share/keyrings/llvm-archive-keyring.gpg && \
echo "deb [signed-by=/usr/share/keyrings/llvm-archive-keyring.gpg] https://apt.llvm.org/${UBUNTU_CODENAME}/ llvm-toolchain-${UBUNTU_CODENAME}-${CLANG_VERSION} main" > /etc/apt/sources.list.d/llvm.list

# update package list
update_package_list

# Install compiler packages
STDCPP_VER=$(apt-cache search --names-only '^libstdc\+\+-[0-9]+-dev$' | \
  grep -o 'libstdc++-[0-9]\+-dev' | sort -V | tail -n1 | grep -o '[0-9]\+')

install_package  {clang,lld,llvm,clang-tidy}-${CLANG_VERSION} libclang*-${CLANG_VERSION}-dev lib{c++,c++abi,unwind}-${CLANG_VERSION}-dev

install_package libstdc++-${STDCPP_VER}-dev
ln -sf /usr/include/c++/${STDCPP_VER} /usr/include/c++/default
ln -sf /usr/lib/gcc/x86_64-linux-gnu/${STDCPP_VER}/libstdc++.so /usr/lib/libstdc++.so

update-alternatives --install /usr/bin/lld lld /usr/bin/lld-${CLANG_VERSION} ${CLANG_VERSION}
update-alternatives --install /usr/bin/clang clang /usr/bin/clang-${CLANG_VERSION} ${CLANG_VERSION}
update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-${CLANG_VERSION} ${CLANG_VERSION}
update-alternatives --install /usr/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-${CLANG_VERSION} ${CLANG_VERSION}
update-alternatives --install /usr/bin/llvm-cov llvm-cov /usr/bin/llvm-cov-${CLANG_VERSION} ${CLANG_VERSION}

# Clear the caches
clear_cache
