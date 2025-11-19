#!/usr/bin/env bash

# Stop if error
set -e

CLANG_VERSION=21

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

# Install base packages
install_package lldb-${CLANG_VERSION} gdb valgrind gperf

update-alternatives --install /usr/bin/lldb lldb /usr/bin/lldb-${CLANG_VERSION} ${CLANG_VERSION}

# Clear the caches
clear_cache
